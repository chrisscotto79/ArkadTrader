// File: Core/TrackRecord/CalloutTrackingService.swift
// The author closing their own callout by hand.
// With the server functions deployed, that's the app's only track-record write: live prices,
// target / stop hits and traderStats are the server's. In free mode the author's app also
// updates the mirror doc and rebuilds traderStats (TrackRecordWriter), and prices and
// auto-closes callouts itself (CalloutAutoTracker). After any close the author's app posts the
// `calloutResult` message (CalloutFollowUps).

import Foundation
import FirebaseFirestore

enum CalloutTrackingError: LocalizedError {
    case notAuthor
    case alreadyClosed
    case invalidPrice

    var errorDescription: String? {
        switch self {
        case .notAuthor: return "Only the person who posted this callout can close it."
        case .alreadyClosed: return "This callout is already closed."
        case .invalidPrice: return "Enter an exit price above zero."
        }
    }
}

@MainActor
final class CalloutTrackingService {
    static let shared = CalloutTrackingService()

    private var db: Firestore { FirebaseServices.shared.db }

    private init() {}

    /// The signed result for closing `callout` at `exitPrice`, rounded to 2 decimals.
    nonisolated static func resultPercent(for callout: TradeCallout, exitPrice: Double) -> Double {
        (callout.percentMove(to: exitPrice) * 100).rounded() / 100
    }

    /// Close an open callout at `exitPrice`. Only the author may do this.
    /// - Parameter authorId: the message's author, used when the callout predates `callout.authorId`.
    /// - Parameter exitCheck: `.live` when the exit passed the check against a live quote
    ///   (TradeCallout.exitCheckError). In free mode it's
    ///   stored on the mirror doc only (never the message); unchecked closes don't count in stats.
    /// - Returns: the callout as it now reads, so callers can show the result straight away.
    @discardableResult
    func closeCallout(
        _ callout: TradeCallout,
        exitPrice: Double,
        communityId: String,
        channelId: String,
        messageId: String,
        authorId: String? = nil,
        exitCheck: TradeCallout.PriceCheck = .unchecked
    ) async throws -> TradeCallout {
        guard let userId = FirebaseAuthService.shared.currentUser?.id,
              userId == (callout.authorId ?? authorId) else {
            throw CalloutTrackingError.notAuthor
        }
        guard callout.isOpen else { throw CalloutTrackingError.alreadyClosed }
        guard exitPrice > 0, exitPrice.isFinite else { throw CalloutTrackingError.invalidPrice }

        let result = Self.resultPercent(for: callout, exitPrice: exitPrice)

        try await db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages").document(messageId)
            .updateData([
                "callout.status": TradeCallout.Status.closed.rawValue,
                "callout.exitPrice": exitPrice,
                "callout.closedAt": FieldValue.serverTimestamp(),
                "callout.resultPercent": result
            ])

        var closed = callout
        closed.status = .closed
        closed.exitPrice = exitPrice
        closed.closedAt = Date()
        closed.resultPercent = result

        if TrackRecordWriter.isActive {
            let writer = TrackRecordWriter.shared
            do {
                try await writer.mirrorClosed(closed, authorId: userId, communityId: communityId,
                                              channelId: channelId, messageId: messageId,
                                              exitCheck: exitCheck)
            } catch {
                // The message is closed; CalloutAutoTracker syncs the mirror on its next run.
                TrackRecordWriter.log("couldn't update callout mirror: \(error.localizedDescription)")
            }
        }

        // The close is written: post the result message (once) with the same numbers, then
        // rebuild stats and tell members.
        let closedCallout = closed
        Task {
            await CalloutFollowUps.shared.postResult(
                for: closedCallout,
                parentMessageId: messageId,
                communityId: communityId,
                channelId: channelId,
                exitCheck: exitCheck
            )
            guard TrackRecordWriter.isActive else { return }
            let writer = TrackRecordWriter.shared
            await writer.recomputeStats()
            await writer.notifyResult(closedCallout, authorId: userId, communityId: communityId,
                                      channelId: channelId, messageId: messageId)
        }
        return closed
    }
}
