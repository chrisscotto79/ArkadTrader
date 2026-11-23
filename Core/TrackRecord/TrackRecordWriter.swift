// File: Core/TrackRecord/TrackRecordWriter.swift
// Free mode (AppConfig.serverFunctionsEnabled == false): the author's app keeps its own
// callout record. See docs/backend-contracts.md, section 0 ("Track records are computed
// on the phone") and section 3 for the `traderStats` shape.
//
// Mirror docs, `users/{uid}/callouts/{messageId}`:
// - created right after the callout message, with the message's own values
//   (TradeCallout.mirrorData: communityId, channelId, messageId, ticker, assetType, direction,
//   entryPrice, status "open", priceCheck, stopPrice?, targetPrice?, postedAt?, quoteAtPost?);
// - while open, only `lastPrice` / `lastPriceAt` (each price check), `deletedAt` (the message
//   was deleted before it could be closed) and the close fields change;
// - closing writes `status`, `exitPrice`, `resultPercent`, `closedAt`, and optionally
//   `exitCheck` and `closedBy`; after that the doc never changes. The app never deletes one.
// After a post or a close, `recomputeStats()` rebuilds `traderStats/{uid}` and
// `communities/{cid}/traderStats/{uid}` from the author's mirror docs.
// Community members get `callout` and `callout_result` inbox notifications (capped fan-out).
//
// When the server functions are deployed, everything here does nothing.

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class TrackRecordWriter {
    static let shared = TrackRecordWriter()

    /// True while the app (not the server) keeps track records.
    static var isActive: Bool { !AppConfig.serverFunctionsEnabled }

    /// The most members one community notification is sent to, so a big community can't
    /// use up the day's free-plan writes on its own.
    static let maxFanOut = 200

    private var db: Firestore { FirebaseServices.shared.db }

    private var isRecomputing = false
    private var recomputeAgain = false

    /// Member ids per community, kept briefly so a run of closes reads each list once.
    private var memberCache: [String: (ids: [String], expires: Date)] = [:]
    private let memberCacheTimeout: TimeInterval = 5 * 60

    private init() {}

    /// Debug-only log line for writes that fail quietly.
    nonisolated static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("TrackRecord: \(message())")
        #endif
    }

    private func mirrors(of userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("callouts")
    }

    // MARK: - Posting

    /// After a callout message is written: mirror it, refresh the author's stats and tell
    /// the community's members. Failures are logged, never thrown: the callout is already posted.
    func calloutPosted(
        _ callout: TradeCallout,
        authorId: String,
        communityId: String,
        communityName: String,
        channelId: String,
        messageId: String
    ) async {
        guard Self.isActive else { return }

        do {
            try await mirrors(of: authorId).document(messageId)
                .setData(callout.mirrorData(communityId: communityId, channelId: channelId, messageId: messageId))
        } catch {
            Self.log("couldn't write callout mirror: \(error.localizedDescription)")
        }

        await recomputeStats()

        let recipients = await memberIds(communityId: communityId).filter { $0 != authorId }
        await FirebaseServices.shared.createNotifications(
            to: recipients,
            type: "callout",
            title: "New callout in \(communityName)",
            body: callout.summary,
            data: Self.channelRoute(communityId: communityId, channelId: channelId, messageId: messageId),
            communityId: communityId
        )
    }

    // MARK: - Prices

    /// A fresh quote for an open callout (stocks only), or nil when there's none right now.
    func freshQuote(for callout: TradeCallout, maxWait: TimeInterval = 10) async -> MarketQuote? {
        guard CalloutQuotes.canQuote(callout) else { return nil }
        return await QuoteClient.shared.quote(for: CalloutQuotes.symbol(for: callout), maxAge: 60, maxWait: maxWait).quote
    }

    /// Records a price check on an open callout's mirror (`lastPrice`, `lastPriceAt`).
    func mirrorPrice(authorId: String, messageId: String, price: Double) async {
        guard Self.isActive, price > 0, price.isFinite else { return }
        do {
            try await mirrors(of: authorId).document(messageId).updateData([
                "lastPrice": price,
                "lastPriceAt": FieldValue.serverTimestamp()
            ])
        } catch {
            Self.log("couldn't update mirror price: \(error.localizedDescription)")
        }
    }

    // MARK: - Closing

    /// Writes the close of a callout to its mirror doc. Only the close fields change; a callout
    /// posted before mirrors existed gets its mirror created, already closed.
    /// - Parameter closedNow: stamp `closedAt` with the server time (a close happening now)
    ///   rather than the callout's own `closedAt` (syncing a close made elsewhere).
    func mirrorClosed(
        _ callout: TradeCallout,
        authorId: String,
        communityId: String,
        channelId: String,
        messageId: String,
        closedNow: Bool = true,
        closedBy: String? = nil,
        exitCheck: TradeCallout.PriceCheck? = nil
    ) async throws {
        guard Self.isActive, !callout.isOpen else { return }
        var close = callout.mirrorCloseData()
        if let closedBy { close["closedBy"] = closedBy }
        if let exitCheck { close["exitCheck"] = exitCheck.rawValue }
        if closedNow || callout.closedAt == nil {
            close["closedAt"] = FieldValue.serverTimestamp()
        } else if let closedAt = callout.closedAt {
            close["closedAt"] = Timestamp(date: closedAt)
        }
        if let lastPrice = callout.lastPrice, lastPrice > 0 {
            close["lastPrice"] = lastPrice
        }

        let ref = mirrors(of: authorId).document(messageId)
        do {
            try await ref.updateData(close)
        } catch let error as NSError where error.domain == "FIRFirestoreErrorDomain" && error.code == 5 {
            // No mirror yet (posted before mirrors existed)
            var data = callout.mirrorData(communityId: communityId, channelId: channelId, messageId: messageId)
            data.merge(close) { _, closeValue in closeValue }
            try await ref.setData(data)
        }
    }

    /// The author deleted (or a moderator removed) a message with an open callout. It still
    /// counts: it closes in the mirror at a fresh price, with `closedBy: "deleted"`, so deleting
    /// a loser doesn't erase the loss. Without a fresh price it stays open with `deletedAt`, and
    /// CalloutAutoTracker closes it once it has one. Returns the callout as it now stands.
    /// - Parameter freshPrice: a quote the caller just fetched; when nil one is fetched here.
    @discardableResult
    func closeDeleted(
        _ callout: TradeCallout,
        freshPrice: Double? = nil,
        authorId: String,
        communityId: String,
        channelId: String,
        messageId: String
    ) async throws -> TradeCallout {
        guard Self.isActive, callout.isOpen else { return callout }
        var price = freshPrice.flatMap { $0 > 0 && $0.isFinite ? $0 : nil }
        if price == nil {
            price = await freshQuote(for: callout)?.current
        }
        guard let exit = price else {
            try await markDeleted(authorId: authorId, messageId: messageId)
            return callout
        }

        var closed = callout
        closed.status = .closed
        closed.exitPrice = exit
        closed.closedAt = Date()
        closed.lastPrice = exit
        closed.resultPercent = CalloutTrackingService.resultPercent(for: callout, exitPrice: exit)
        try await mirrorClosed(closed, authorId: authorId, communityId: communityId, channelId: channelId,
                               messageId: messageId, closedNow: true, closedBy: "deleted", exitCheck: .live)
        return closed
    }

    /// Marks an open mirror as belonging to a deleted message (`deletedAt`), once.
    func markDeleted(authorId: String, messageId: String) async throws {
        try await mirrors(of: authorId).document(messageId).updateData([
            "deletedAt": FieldValue.serverTimestamp()
        ])
    }

    /// `callout_result` for the community's members (not the author).
    func notifyResult(_ callout: TradeCallout, authorId: String, communityId: String, channelId: String, messageId: String) async {
        guard Self.isActive, !callout.isOpen else { return }

        let title: String
        switch callout.status {
        case .targetHit: title = "\(callout.ticker) hit its target"
        case .stoppedOut: title = "\(callout.ticker) was stopped out"
        default: title = "\(callout.ticker) callout closed"
        }

        var body = "\(callout.direction.displayName) from \(TradeCallout.formatPrice(callout.entryPrice))"
        if let exit = callout.exitPrice {
            body += ", closed at \(TradeCallout.formatPrice(exit))"
        }
        if let result = callout.finalPercent {
            body += ": \(TradeCallout.formatPercent(result))"
        }

        let recipients = await memberIds(communityId: communityId).filter { $0 != authorId }
        await FirebaseServices.shared.createNotifications(
            to: recipients,
            type: "callout_result",
            title: title,
            body: body,
            data: Self.channelRoute(communityId: communityId, channelId: channelId, messageId: messageId),
            communityId: communityId
        )
    }

    // MARK: - Stats

    /// Rebuilds the signed-in user's `traderStats` docs from their mirror docs.
    /// Calls that arrive while a rebuild is running are folded into one more pass.
    func recomputeStats() async {
        guard Self.isActive, let userId = Auth.auth().currentUser?.uid else { return }
        if isRecomputing {
            recomputeAgain = true
            return
        }
        isRecomputing = true
        defer { isRecomputing = false }
        repeat {
            recomputeAgain = false
            await writeStats(userId: userId)
        } while recomputeAgain
    }

    /// Whether a mirror doc counts toward the record: the entry was checked against a live
    /// price, a close by hand had its exit checked too (`exitCheck != "unchecked"`), and a
    /// closed callout's result matches its exit. Auto-closes and deleted callouts are
    /// `exitCheck: "live"`, so a deleted loser still counts.
    nonisolated static func counts(_ data: [String: Any]) -> TradeCallout? {
        guard (data["exitCheck"] as? String) != TradeCallout.PriceCheck.unchecked.rawValue,
              let callout = TradeCallout.fromFirestore(data), callout.isPriceChecked else { return nil }
        if !callout.isOpen && !callout.isConsistentResult { return nil }
        return callout
    }

    private func writeStats(userId: String) async {
        let snapshot: QuerySnapshot
        do {
            snapshot = try await mirrors(of: userId).getDocuments()
        } catch {
            Self.log("couldn't read callout mirrors: \(error.localizedDescription)")
            return
        }
        // The rules require the username on users/{uid}, so read it fresh.
        let profile: (username: String, imageUrl: String?)
        do {
            let data = try await db.collection("users").document(userId).getDocument().data()
            profile = (data?["username"] as? String ?? "", data?["profileImageUrl"] as? String)
        } catch {
            Self.log("couldn't read the profile for traderStats: \(error.localizedDescription)")
            return
        }

        // Every community the author has posted in gets a doc, even when none of its callouts
        // count any more, so a stale record never lingers.
        var byCommunity: [String: [TradeCallout]] = [:]
        var counted: [TradeCallout] = []
        for doc in snapshot.documents {
            let data = doc.data()
            let communityId = data["communityId"] as? String ?? ""
            if !communityId.isEmpty, byCommunity[communityId] == nil { byCommunity[communityId] = [] }
            guard let callout = Self.counts(data) else { continue }
            counted.append(callout)
            if !communityId.isEmpty { byCommunity[communityId]?.append(callout) }
        }

        do {
            try await db.collection("traderStats").document(userId).setData(
                TrackRecordMath.statsData(for: counted, username: profile.username, profileImageUrl: profile.imageUrl)
            )
        } catch {
            Self.log("couldn't write traderStats: \(error.localizedDescription)")
        }

        for (communityId, communityCallouts) in byCommunity {
            do {
                try await db.collection("communities").document(communityId)
                    .collection("traderStats").document(userId)
                    .setData(TrackRecordMath.statsData(for: communityCallouts, username: profile.username,
                                                       profileImageUrl: profile.imageUrl))
            } catch {
                // e.g. the author has since left or been removed from the community
                Self.log("couldn't write community traderStats (\(communityId)): \(error.localizedDescription)")
            }
            CommunityLeaderboardService.shared.invalidate(communityId: communityId)
        }
        CommunityLeaderboardService.shared.invalidate(communityId: "global")
    }

    // MARK: - Helpers

    /// Up to `maxFanOut` ids from `communities/{cid}/members`. Empty when the list can't be read.
    func memberIds(communityId: String) async -> [String] {
        if let hit = memberCache[communityId], hit.expires > Date() { return hit.ids }
        do {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("members").limit(to: Self.maxFanOut).getDocuments()
            let ids = snapshot.documents.map { $0.documentID }
            memberCache[communityId] = (ids, Date().addingTimeInterval(memberCacheTimeout))
            return ids
        } catch {
            Self.log("couldn't read members of \(communityId): \(error.localizedDescription)")
            return []
        }
    }

    /// Deep link to a message in a channel (docs/backend-contracts.md, section 2).
    static func channelRoute(communityId: String, channelId: String, messageId: String) -> [String: String] {
        ["route": "channel", "communityId": communityId, "channelId": channelId, "messageId": messageId]
    }
}

// MARK: - Stats math

/// Builds a `traderStats` doc (docs/backend-contracts.md, section 3) from a list of callouts.
/// Fields (fixed list): calloutsTotal, calloutsClosed, openCallouts, wins, losses (ints >= 0),
/// winRate (0–1), avgReturnPercent, totalReturnPercent (the sum of closed results, shown as
/// "Sum of results"), bestCalloutPercent?, worstCalloutPercent?, lastCalloutAt?, updatedAt,
/// username (= users/{uid}.username), profileImageUrl?.
enum TrackRecordMath {
    static func statsData(for callouts: [TradeCallout], username: String, profileImageUrl: String?) -> [String: Any] {
        // A closed callout with no recorded result counts as flat
        let results = callouts.filter { !$0.isOpen }.map { $0.finalPercent ?? 0 }
        let closed = results.count
        let wins = results.filter { $0 > 0 }.count
        let total = results.reduce(0, +)

        var data: [String: Any] = [
            "calloutsTotal": callouts.count,
            "calloutsClosed": closed,
            "openCallouts": callouts.count - closed,
            "wins": wins,
            "losses": closed - wins,
            "winRate": closed > 0 ? round(Double(wins) / Double(closed), places: 4) : 0.0,
            "avgReturnPercent": closed > 0 ? round(total / Double(closed), places: 2) : 0.0,
            "totalReturnPercent": round(total, places: 2),
            "updatedAt": FieldValue.serverTimestamp(),
            "username": username
        ]
        if let best = results.max() { data["bestCalloutPercent"] = round(best, places: 2) }
        if let worst = results.min() { data["worstCalloutPercent"] = round(worst, places: 2) }
        if let last = callouts.compactMap({ $0.postedAt }).max() { data["lastCalloutAt"] = Timestamp(date: last) }
        if let profileImageUrl, !profileImageUrl.isEmpty { data["profileImageUrl"] = profileImageUrl }
        return data
    }

    private static func round(_ value: Double, places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (value * factor).rounded() / factor
    }
}
