// File: Core/TrackRecord/CalloutAutoTracker.swift
// Free mode: the author's own app prices and auto-closes their open callouts, since there is
// no scheduled server function (docs/backend-contracts.md, section 0).
//
// Call `checkMyOpenCallouts()` on launch and whenever the app comes to the foreground.
// It runs at most once every 10 minutes per signed-in user, and does nothing when
// `AppConfig.serverFunctionsEnabled` is true. Stops and targets are read from the message, so a
// level the author moved (a `calloutUpdate`) is the one checked.
//
// Price rules:
// - Only a fresh quote (QuoteClient) moves or closes a callout; a stored price never does,
//   including for the 30-day close of callouts with no stop or target.
// - The quote's day high / low counts too, when the whole trading day came after the callout
//   was posted and its levels last moved: a long whose low touched the stop is stopped out even
//   if the price came back. If the stop and the target were both crossed, the stop wins.
//   Days between two runs that the app never saw can't be checked (no free price history).
// - A deleted callout closes at a fresh price (never at entry); until there is one it stays
//   open in the mirror with `deletedAt`.
// After a close it posts the `calloutResult` message through CalloutFollowUps.

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class CalloutAutoTracker {
    static let shared = CalloutAutoTracker()

    private let minimumInterval: TimeInterval = 10 * 60
    /// QuoteClient shares one call budget with the rest of the app; a run uses at most this many.
    private let maxQuotesPerRun = 25

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
        /// The mirror already records that the message was deleted
        let markedDeleted: Bool
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
            let messageRef = FirebaseServices.shared.channelMessageRef(communityId: communityId, channelId: channelId,
                                                                        messageId: messageId)

            let messageData: [String: Any]?
            do {
                messageData = try await messageRef.getDocument().data()
            } catch {
                continue  // no access or offline: leave it for the next run
            }
            let isDeleted = messageData == nil || (messageData?["isDeleted"] as? Bool ?? false)
            let messageCallout = isDeleted ? nil : (messageData?["callout"] as? [String: Any]).flatMap(TradeCallout.fromFirestore)

            if let messageCallout, !messageCallout.isOpen {
                // Closed elsewhere (another device): bring the mirror in line.
                var synced = messageCallout
                synced.priceCheck = synced.priceCheck ?? mirrorCallout.priceCheck
                synced.quoteAtPost = synced.quoteAtPost ?? mirrorCallout.quoteAtPost
                synced.postedAt = synced.postedAt ?? mirrorCallout.postedAt
                // A target or stop hit counts as price-checked only when its numbers follow the
                // close rules. A plain close made elsewhere whose mirror write failed can't be
                // shown to have had a live exit, so it doesn't count.
                let exitCheck: TradeCallout.PriceCheck =
                    synced.status != .closed && synced.isConsistentClose ? .live : .unchecked
                do {
                    try await writer.mirrorClosed(synced, authorId: userId, communityId: communityId,
                                                  channelId: channelId, messageId: messageId,
                                                  closedNow: synced.closedAt == nil, exitCheck: exitCheck)
                    recordChanged = true
                } catch {
                    TrackRecordWriter.log("couldn't sync a close made elsewhere: \(error.localizedDescription)")
                }
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
                markedDeleted: data["deletedAt"] != nil,
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
        var quotes: [String: MarketQuote] = [:]
        for symbol in symbols {
            if let quote = await QuoteClient.shared.quote(for: symbol, maxAge: 60, maxWait: 15).quote {
                quotes[symbol] = quote
            }
        }

        // 3. Update prices and close what crossed its stop or target (or aged out).
        let now = Date()
        var closedForNotice: [Tracked] = []
        for var item in tracked {
            let quote = CalloutQuotes.canQuote(item.callout) ? quotes[CalloutQuotes.symbol(for: item.callout)] : nil

            // The message was deleted: the callout still counts, closed at a fresh price.
            guard let messageRef = item.messageRef else {
                if let quote {
                    do {
                        try await writer.closeDeleted(item.callout, freshPrice: quote.current, authorId: userId,
                                                      communityId: item.communityId, channelId: item.channelId,
                                                      messageId: item.messageId)
                        recordChanged = true
                    } catch {
                        TrackRecordWriter.log("couldn't close a deleted callout: \(error.localizedDescription)")
                    }
                } else if !item.markedDeleted {
                    try? await writer.markDeleted(authorId: userId, messageId: item.messageId)
                }
                continue
            }

            // No fresh quote: nothing changes, not even the 30-day close.
            guard let quote else { continue }
            let price = quote.current
            let range = Self.usableRange(of: quote, for: item.callout)

            guard let close = item.callout.autoClose(at: price, high: range?.high, low: range?.low, now: now) else {
                let batch = db.batch()
                batch.updateData([
                    "callout.lastPrice": price,
                    "callout.lastPriceAt": FieldValue.serverTimestamp()
                ], forDocument: messageRef)
                batch.updateData([
                    "lastPrice": price,
                    "lastPriceAt": FieldValue.serverTimestamp()
                ], forDocument: db.collection("users").document(userId).collection("callouts").document(item.messageId))
                do {
                    try await batch.commit()
                } catch {
                    TrackRecordWriter.log("couldn't record a price check: \(error.localizedDescription)")
                }
                continue
            }

            let result = CalloutTrackingService.resultPercent(for: item.callout, exitPrice: close.exitPrice)
            do {
                try await messageRef.updateData([
                    "callout.status": close.status.rawValue,
                    "callout.exitPrice": close.exitPrice,
                    "callout.closedAt": FieldValue.serverTimestamp(),
                    "callout.resultPercent": result,
                    "callout.lastPrice": price,
                    "callout.lastPriceAt": FieldValue.serverTimestamp()
                ])
            } catch {
                TrackRecordWriter.log("couldn't auto-close a callout: \(error.localizedDescription)")
                continue  // try again next run
            }

            item.callout.status = close.status
            item.callout.exitPrice = close.exitPrice
            item.callout.closedAt = now
            item.callout.resultPercent = result
            item.callout.lastPrice = price
            item.callout.lastPriceAt = now
            // Auto-closes are price-based, so their exit counts as live-checked.
            // If this fails, the next run sees the closed message and syncs the mirror.
            do {
                try await writer.mirrorClosed(item.callout, authorId: userId, communityId: item.communityId,
                                              channelId: item.channelId, messageId: item.messageId,
                                              exitCheck: .live)
            } catch {
                TrackRecordWriter.log("couldn't mirror an auto-close: \(error.localizedDescription)")
            }
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

    // MARK: - Day range

    /// The quote's day high and low, when every trade in them came after the callout was posted
    /// and after its stop / target last moved. That's true when both happened before the trading
    /// day of the quote's last trade began (midnight in New York). Nil otherwise.
    nonisolated static func usableRange(of quote: MarketQuote, for callout: TradeCallout) -> (high: Double?, low: Double?)? {
        guard quote.high != nil || quote.low != nil,
              let tradeTime = quote.time, let postedAt = callout.postedAt else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let sessionStart = calendar.startOfDay(for: tradeTime)
        guard postedAt < sessionStart else { return nil }
        if let moved = CalloutFollowUps.updateTime(fromUpdateId: callout.lastUpdateId), moved >= sessionStart {
            return nil
        }
        return (quote.high, quote.low)
    }
}
