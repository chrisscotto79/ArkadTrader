// File: Core/TrackRecord/CalloutTrackingService.swift
// The one write the app makes to a callout's track record: the author closing it by hand.
// Everything else (live prices, target / stop hits, traderStats) is written by the server.

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
    /// - Returns: the callout as it now reads, so callers can show the result straight away.
    @discardableResult
    func closeCallout(
        _ callout: TradeCallout,
        exitPrice: Double,
        communityId: String,
        channelId: String,
        messageId: String,
        authorId: String? = nil
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
        return closed
    }
}
