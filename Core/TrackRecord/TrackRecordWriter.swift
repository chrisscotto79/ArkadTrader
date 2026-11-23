// File: Core/TrackRecord/TrackRecordWriter.swift
// Free mode (AppConfig.serverFunctionsEnabled == false): the author's app keeps its own
// callout record. See docs/backend-contracts.md, section 0 ("Track records are computed
// on the phone") and section 3 for the `traderStats` shape.
//
// - Posting a callout writes the mirror doc `users/{uid}/callouts/{messageId}`.
// - Closing one (by hand or through CalloutAutoTracker) updates the mirror.
// - After either, `recomputeStats()` rebuilds `traderStats/{uid}` and
//   `communities/{cid}/traderStats/{uid}` from the author's own mirror docs.
// - Community members get `callout`, `callout_update` and `callout_result` inbox notifications.
// - The mirror also records `resultPosted: true` once the result message is in the channel
//   (CalloutFollowUps), and follows stop / target moves.
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

    private var db: Firestore { FirebaseServices.shared.db }

    private var isRecomputing = false
    private var recomputeAgain = false

    /// Member ids per community, kept briefly so a run of closes reads each list once.
    private var memberCache: [String: (ids: [String], expires: Date)] = [:]
    private let memberCacheTimeout: TimeInterval = 5 * 60

    private init() {}

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
            print("⚠️ TrackRecordWriter: couldn't write callout mirror: \(error.localizedDescription)")
        }

        await recomputeStats()

        let recipients = await memberIds(communityId: communityId).filter { $0 != authorId }
        await FirebaseServices.shared.createNotifications(
            to: recipients,
            type: "callout",
            title: "New callout in \(communityName)",
            body: callout.summary,
            data: Self.channelRoute(communityId: communityId, channelId: channelId, messageId: messageId)
        )
    }

    // MARK: - Closing

    /// Writes a closed callout to its mirror doc. Merges, so a callout posted before
    /// mirrors existed gains one when it closes.
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
        guard Self.isActive else { return }
        var data = callout.mirrorData(communityId: communityId, channelId: channelId, messageId: messageId)
        if let closedBy { data["closedBy"] = closedBy }
        if let exitCheck { data["exitCheck"] = exitCheck.rawValue }
        if closedNow || callout.closedAt == nil {
            data["closedAt"] = FieldValue.serverTimestamp()
        }
        try await mirrors(of: authorId).document(messageId).setData(data, merge: true)
    }

    /// The author deleted (or a moderator removed) a message with an open callout. The callout
    /// still counts: it closes in the mirror at its last price, or at entry (0%) if it was never
    /// priced, with `closedBy: "deleted"`. It has no `exitCheck`, so it counts (a deleted loser
    /// still shows). Returns the callout as closed.
    @discardableResult
    func closeDeleted(
        _ callout: TradeCallout,
        lastPrice: Double? = nil,
        authorId: String,
        communityId: String,
        channelId: String,
        messageId: String
    ) async throws -> TradeCallout {
        var closed = callout
        let exit = [lastPrice, callout.lastPrice].compactMap { $0 }.first { $0 > 0 && $0.isFinite } ?? callout.entryPrice
        closed.status = .closed
        closed.exitPrice = exit
        closed.closedAt = Date()
        closed.resultPercent = CalloutTrackingService.resultPercent(for: callout, exitPrice: exit)
        try await mirrorClosed(closed, authorId: authorId, communityId: communityId, channelId: channelId,
                               messageId: messageId, closedNow: true, closedBy: "deleted")
        return closed
    }

    /// The author moved a callout's stop or target: keep the mirror's levels in step, so a callout
    /// whose message is later deleted still closes against the new level. Updates only an
    /// existing mirror (a callout posted before mirrors existed gains one when it closes).
    func mirrorLevels(authorId: String, messageId: String, stopPrice: Double?, targetPrice: Double?) async {
        guard Self.isActive else { return }
        var fields: [String: Any] = [:]
        if let stopPrice { fields["stopPrice"] = stopPrice }
        if let targetPrice { fields["targetPrice"] = targetPrice }
        guard !fields.isEmpty else { return }
        do {
            try await mirrors(of: authorId).document(messageId).updateData(fields)
        } catch {
            print("⚠️ TrackRecordWriter: couldn't update callout mirror levels: \(error.localizedDescription)")
        }
    }

    /// Whether the mirror records that this callout's result message was posted.
    func isResultPosted(authorId: String, messageId: String) async -> Bool {
        guard Self.isActive else { return false }
        let data = try? await mirrors(of: authorId).document(messageId).getDocument().data()
        return data?["resultPosted"] as? Bool ?? false
    }

    /// Records on the mirror that the result message is posted, so it's never posted twice.
    func markResultPosted(authorId: String, messageId: String) async {
        guard Self.isActive else { return }
        try? await mirrors(of: authorId).document(messageId).updateData(["resultPosted": true])
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
            data: Self.channelRoute(communityId: communityId, channelId: channelId, messageId: messageId)
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

    private func writeStats(userId: String) async {
        let snapshot: QuerySnapshot
        do {
            snapshot = try await mirrors(of: userId).getDocuments()
        } catch {
            print("⚠️ TrackRecordWriter: couldn't read callout mirrors: \(error.localizedDescription)")
            return
        }

        // Anti-fake: only callouts whose entry was checked against a live price count, and a
        // close by hand counts only when its exit was too (`exitCheck != "unchecked"`).
        // Auto-closes are `exitCheck: "live"`; deleted callouts have none and count.
        let callouts = snapshot.documents
            .filter { ($0.data()["exitCheck"] as? String) != TradeCallout.PriceCheck.unchecked.rawValue }
            .compactMap { TradeCallout.fromFirestore($0.data()) }
            .filter { $0.isPriceChecked }
        let profile = await profile(userId: userId)

        do {
            try await db.collection("traderStats").document(userId).setData(
                TrackRecordMath.statsData(for: callouts, username: profile.username, profileImageUrl: profile.imageUrl)
            )
        } catch {
            print("⚠️ TrackRecordWriter: couldn't write traderStats: \(error.localizedDescription)")
        }

        // One doc per community with callouts, from that community's callouts only
        let byCommunity = Dictionary(grouping: callouts.filter { !($0.communityId ?? "").isEmpty }) { $0.communityId ?? "" }
        for (communityId, communityCallouts) in byCommunity {
            do {
                try await db.collection("communities").document(communityId)
                    .collection("traderStats").document(userId)
                    .setData(TrackRecordMath.statsData(for: communityCallouts, username: profile.username, profileImageUrl: profile.imageUrl))
            } catch {
                // e.g. the author has since left or been removed from the community
                print("⚠️ TrackRecordWriter: couldn't write community traderStats (\(communityId)): \(error.localizedDescription)")
            }
            CommunityLeaderboardService.shared.invalidate(communityId: communityId)
        }
        CommunityLeaderboardService.shared.invalidate(communityId: "global")
    }

    /// Username and photo for the leaderboard, from the signed-in profile when it's loaded.
    private func profile(userId: String) async -> (username: String, imageUrl: String?) {
        if let user = FirebaseAuthService.shared.currentUser, user.id == userId {
            return (user.username, user.profileImageUrl)
        }
        let data = try? await db.collection("users").document(userId).getDocument().data()
        return (data?["username"] as? String ?? "", data?["profileImageUrl"] as? String)
    }

    // MARK: - Helpers

    /// Ids in `communities/{cid}/members`. Empty when the list can't be read.
    func memberIds(communityId: String) async -> [String] {
        if let hit = memberCache[communityId], hit.expires > Date() { return hit.ids }
        guard let snapshot = try? await db.collection("communities").document(communityId)
            .collection("members").getDocuments() else { return [] }
        let ids = snapshot.documents.map { $0.documentID }
        memberCache[communityId] = (ids, Date().addingTimeInterval(memberCacheTimeout))
        return ids
    }

    /// Deep link to a message in a channel (docs/backend-contracts.md, section 2).
    static func channelRoute(communityId: String, channelId: String, messageId: String) -> [String: String] {
        ["route": "channel", "communityId": communityId, "channelId": channelId, "messageId": messageId]
    }
}

// MARK: - Stats math

/// Builds a `traderStats` doc (docs/backend-contracts.md, section 3) from a list of callouts.
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
