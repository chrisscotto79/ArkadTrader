// File: Core/TrackRecord/TraderStatsService.swift
// Reads server-written callout records (`traderStats`). Read only: the app never writes these.

import Foundation
import FirebaseFirestore

@MainActor
final class TraderStatsService {
    static let shared = TraderStatsService()

    private var db: Firestore { FirebaseServices.shared.db }

    /// Upper bound on ranked docs read for one board. Boards are sorted on the device,
    /// so no composite index is needed.
    private let rankedScanLimit = 500

    private init() {}

    /// `traderStats` for the whole app, or `communities/{cid}/traderStats` for one community.
    private func collection(communityId: String?) -> CollectionReference {
        if let communityId, !communityId.isEmpty {
            return db.collection("communities").document(communityId).collection("traderStats")
        }
        return db.collection("traderStats")
    }

    /// One trader's record, or nil when they have never posted a callout.
    func stats(userId: String, communityId: String? = nil) async throws -> TraderStats? {
        guard !userId.isEmpty else { return nil }
        let snapshot = try await collection(communityId: communityId).document(userId).getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return TraderStats.fromFirestore(data: data, id: snapshot.documentID)
    }

    /// Every trader with at least `TraderStats.minimumClosedCallouts` closed callouts.
    func rankedStats(communityId: String? = nil) async throws -> [TraderStats] {
        let snapshot = try await collection(communityId: communityId)
            .whereField("calloutsClosed", isGreaterThanOrEqualTo: TraderStats.minimumClosedCallouts)
            .order(by: "calloutsClosed", descending: true)
            .limit(to: rankedScanLimit)
            .getDocuments()
        return snapshot.documents
            .map { TraderStats.fromFirestore(data: $0.data(), id: $0.documentID) }
            .filter(\.isRanked)
    }
}
