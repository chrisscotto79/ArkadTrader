// File: Core/TrackRecord/CalloutAutoTracker.swift
// Free mode: the author's own app prices and auto-closes their open callouts, since there is
// no scheduled server function (docs/backend-contracts.md, section 0).
//
// Call `checkMyOpenCallouts()` on launch and whenever the app comes to the foreground.
// It runs at most once every 10 minutes per signed-in user, and does nothing when
// `AppConfig.serverFunctionsEnabled` is true. Stops and targets are read from the message, so a
// level the author moved (a `calloutUpdate`) is the one checked. After a close it posts the
// `calloutResult` message through CalloutFollowUps.

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class CalloutAutoTracker {
    static let shared = CalloutAutoTracker()

    private let minimumInterval: TimeInterval = 10 * 60
    /// Finnhub's free tier allows 60 calls a minute; a run uses at most this many, one at a time.
    private let maxQuotesPerRun = 25
    private let gapBetweenQuotes: TimeInterval = 1.5

    private var isRunning = false
    private var db: Firestore { FirebaseServices.shared.db }

    private init() {}

    /// One open callout from the author's mirror docs, with where its message lives.
    private struct Tracked {
        var callout: TradeCallout
        let communityId: String
        let channelId: String
        let messageId: String
        /// The message, or nil when it was deleted (its callout is then closed in the mirror).
        let messageRef: DocumentReference?
        /// From the message, for the result post
        var authorUsername: String? = nil
        var authorAvatarURL: String? = nil
    }

    /// A callout closed on another device whose result may still need posting.
    private struct ClosedElsewhere {
        let callout: TradeCallout
        let communityId: String
        let channelId: String
        let messageId: String
        let exitCheck: TradeCallout.PriceCheck
        let authorUsername: String?
        let authorAvatarURL: String?
    }

    private func lastRunKey(_ userId: String) -> String { "calloutAutoTracker.lastRunAt.\(userId)" }

    func checkMyOpenCallouts() async {
        guard !AppConfig.serverFunctionsEnabled, !isRunning,
              let userId = Auth.auth().currentUser?.uid else { return }
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastRunKey(userId)) as? Date,
           Date().timeIntervalSince(last) < minimumInterval { return }

        isRunning = true
        defer { isRunning = false }

        let mirrorDocs: [QueryDocumentSnapshot]
        do {
            mirrorDocs = try await db.collection("users").document(userId).collection("callouts")
                .whereField("status", isEqualTo: TradeCallout.Status.open.rawValue)
                .getDocuments()
                .documents
        } catch {
            return  // offline: try again next time
        }
        defaults.set(Date(), forKey: lastRunKey(userId))
        guard !mirrorDocs.isEmpty else { return }

        let writer = TrackRecordWriter.shared
        var recordChanged = false
        var tracked: [Tracked] = []
        var closedElsewhere: [ClosedElsewhere] = []

        // 1. Read each callout's message, which holds the live state.
        for doc in mirrorDocs {
            let data = doc.data()
            guard let communityId = data["communityId"] as? String, !communityId.isEmpty,
                  let channelId = data["channelId"] as? String, !channelId.isEmpty,
                  let mirrorCallout = TradeCallout.fromFirestore(data) else { continue }
            let messageId = (data["messageId"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? doc.documentID
            let messageRef = db.collection("communities").document(communityId)
                .collection("channels").document(channelId)
                .collection("messages").document(messageId)

            let messageData: [String: Any]?
            do {
                messageData = try await messageRef.getDocument().data()
            } catch {
                continue  // no access or offline: leave it for the next run
            }
            let isDeleted = messageData?["isDeleted"] as? Bool ?? false
            let messageCallout = isDeleted ? nil : (messageData?["callout"] as? [String: Any]).flatMap(TradeCallout.fromFirestore)

            if let messageCallout, !messageCallout.isOpen {
                // Closed elsewhere (another device): bring the mirror in line.
                var synced = messageCallout
                synced.priceCheck = synced.priceCheck ?? mirrorCallout.priceCheck
                synced.quoteAtPost = synced.quoteAtPost ?? mirrorCallout.quoteAtPost
                synced.postedAt = synced.postedAt ?? mirrorCallout.postedAt
                // Target / stop hits are price-based. A plain close made elsewhere whose mirror
                // write failed can't be shown to have had a live exit, so it doesn't count.
                let exitCheck: TradeCallout.PriceCheck = synced.status == .closed ? .unchecked : .live
                try? await writer.mirrorClosed(synced, authorId: userId, communityId: communityId,
                                               channelId: channelId, messageId: messageId,
                                               closedNow: synced.closedAt == nil, exitCheck: exitCheck)
                recordChanged = true
                // Usually already posted by the device that closed it; postResult checks.
                closedElsewhere.append(ClosedElsewhere(
                    callout: messageCallout,
                    communityId: communityId,
                    channelId: channelId,
                    messageId: messageId,
                    exitCheck: exitCheck,
                    authorUsername: messageData?["authorUsername"] as? String,
                    authorAvatarURL: messageData?["authorAvatarURL"] as? String
                ))
                continue
            }

            var callout = messageCallout ?? mirrorCallout
            callout.postedAt = callout.postedAt ?? mirrorCallout.postedAt
            callout.priceCheck = callout.priceCheck ?? mirrorCallout.priceCheck
            callout.quoteAtPost = callout.quoteAtPost ?? mirrorCallout.quoteAtPost
            tracked.append(Tracked(
                callout: callout,
                communityId: communityId,
                channelId: channelId,
                messageId: messageId,
                messageRef: messageCallout == nil ? nil : messageRef,
                authorUsername: messageData?["authorUsername"] as? String,
                authorAvatarURL: messageData?["authorAvatarURL"] as? String
            ))
        }

        // 2. One quote per ticker, stalest first, so with more than the cap every ticker gets a turn.
        var stalest: [String: Date] = [:]
        for item in tracked where CalloutQuotes.canQuote(item.callout) {
            let symbol = CalloutQuotes.symbol(for: item.callout)
            let at = item.callout.lastPriceAt ?? .distantPast
            stalest[symbol] = min(stalest[symbol] ?? at, at)
        }
        let symbols = stalest.sorted { $0.value < $1.value }.prefix(maxQuotesPerRun).map { $0.key }
        var prices: [String: Double] = [:]
        for symbol in symbols {
            if let quote = await CalloutQuotes.shared.trackingQuote(for: symbol, gap: gapBetweenQuotes) {
                prices[symbol] = quote.price
            }
        }

        // 3. Update prices and close what crossed its target or stop (or aged out).
        let now = Date()
        var closedForNotice: [Tracked] = []
        for var item in tracked {
            let price = CalloutQuotes.canQuote(item.callout) ? prices[CalloutQuotes.symbol(for: item.callout)] : nil

            // The message was deleted: the callout still counts, closed at its last price.
            guard let messageRef = item.messageRef else {
                if (try? await writer.closeDeleted(item.callout, lastPrice: price, authorId: userId,
                                                   communityId: item.communityId, channelId: item.channelId,
                                                   messageId: item.messageId)) != nil {
                    recordChanged = true
                }
                continue
            }

            // Without a fresh quote only the 30-day rule can apply, at the last stored price.
            let hasLevels = item.callout.stopPrice != nil || item.callout.targetPrice != nil
            guard let checkPrice = price ?? (hasLevels ? nil : item.callout.lastPrice) else { continue }

            guard let close = item.callout.autoClose(at: checkPrice, now: now) else {
                if let price {
                    try? await messageRef.updateData([
                        "callout.lastPrice": price,
                        "callout.lastPriceAt": Timestamp(date: now)
                    ])
                }
                continue
            }

            let result = CalloutTrackingService.resultPercent(for: item.callout, exitPrice: close.exitPrice)
            var fields: [String: Any] = [
                "callout.status": close.status.rawValue,
                "callout.exitPrice": close.exitPrice,
                "callout.closedAt": FieldValue.serverTimestamp(),
                "callout.resultPercent": result
            ]
            if let price {
                fields["callout.lastPrice"] = price
                fields["callout.lastPriceAt"] = Timestamp(date: now)
            }
            do {
                try await messageRef.updateData(fields)
            } catch {
                continue  // try again next run
            }

            item.callout.status = close.status
            item.callout.exitPrice = close.exitPrice
            item.callout.closedAt = now
            item.callout.resultPercent = result
            if let price {
                item.callout.lastPrice = price
                item.callout.lastPriceAt = now
            }
            // Auto-closes are price-based, so their exit counts as live-checked.
            // If this fails, the next run sees the closed message and syncs the mirror.
            try? await writer.mirrorClosed(item.callout, authorId: userId, communityId: item.communityId,
                                           channelId: item.channelId, messageId: item.messageId,
                                           exitCheck: .live)
            recordChanged = true
            closedForNotice.append(item)
        }

        // 4. Post each result message (only after its close was written), with the numbers
        //    that were written: the tracker's closes are price-based, so `exitCheck: "live"`.
        let followUps = CalloutFollowUps.shared
        for item in closedForNotice {
            await followUps.postResult(for: item.callout, parentMessageId: item.messageId,
                                       communityId: item.communityId, channelId: item.channelId,
                                       exitCheck: .live, authorUsername: item.authorUsername,
                                       authorAvatarURL: item.authorAvatarURL)
        }
        for item in closedElsewhere {
            await followUps.postResult(for: item.callout, parentMessageId: item.messageId,
                                       communityId: item.communityId, channelId: item.channelId,
                                       exitCheck: item.exitCheck, authorUsername: item.authorUsername,
                                       authorAvatarURL: item.authorAvatarURL)
        }

        // 5. Stats once, then tell members about each result.
        if recordChanged {
            await writer.recomputeStats()
        }
        for item in closedForNotice {
            await writer.notifyResult(item.callout, authorId: userId, communityId: item.communityId,
                                      channelId: item.channelId, messageId: item.messageId)
        }
    }
}
