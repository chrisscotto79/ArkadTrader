// File: Core/Communities/Services/CommunityLeaderboardService.swift
// Ranks traders by their verified callout records (`traderStats`), within one community
// or across the whole app. Only traders with enough closed callouts are ranked.

import Foundation

@MainActor
final class CommunityLeaderboardService {

    static let shared = CommunityLeaderboardService()

    /// Minimum closed portfolio trades for the "consistent trader" badge in UserProfileSheet.
    /// Leaderboards use `TraderStats.minimumClosedCallouts` instead.
    static let minimumTradesForRatios = 3

    private let statsService = TraderStatsService.shared
    private let globalKey = "global"

    /// Ranked stats per board ("global" or a community id). Sorting is done on the device,
    /// so switching category doesn't need another read.
    private var cache: [String: (stats: [TraderStats], expires: Date)] = [:]
    private let cacheTimeout: TimeInterval = 300

    private init() {}

    // MARK: - Public API

    /// Leaderboard for one community, from `communities/{cid}/traderStats`
    func getLeaderboard(
        communityId: String,
        category: LeaderboardCategory,
        limit: Int = 50
    ) async throws -> [CommunityLeaderboardEntry] {
        let stats = try await rankedStats(key: communityId) {
            try await statsService.rankedStats(communityId: communityId)
        }
        return rank(stats, by: category, limit: limit)
    }

    /// Leaderboard across every trader on Arkad, from `traderStats`
    func getGlobalLeaderboard(
        category: LeaderboardCategory,
        limit: Int = 100
    ) async throws -> [CommunityLeaderboardEntry] {
        let stats = try await rankedStats(key: globalKey) {
            try await statsService.rankedStats()
        }
        return rank(stats, by: category, limit: limit)
    }

    func clearCache() {
        cache.removeAll()
    }

    /// Drop one board ("global" or a community id) so the next load is fresh
    func invalidate(communityId: String) {
        cache[communityId] = nil
    }

    // MARK: - Ranking

    private func rank(_ stats: [TraderStats], by category: LeaderboardCategory, limit: Int) -> [CommunityLeaderboardEntry] {
        // Ties go to the trader with more closed callouts, then the higher average return
        let sorted = stats.sorted { a, b in
            let lhs = category.sortValue(for: a), rhs = category.sortValue(for: b)
            if lhs != rhs { return lhs > rhs }
            if a.calloutsClosed != b.calloutsClosed { return a.calloutsClosed > b.calloutsClosed }
            return a.avgReturnPercent > b.avgReturnPercent
        }
        return sorted.prefix(limit).enumerated().map { index, stats in
            CommunityLeaderboardEntry(stats: stats, rank: index + 1)
        }
    }

    private func rankedStats(key: String, fetch: () async throws -> [TraderStats]) async throws -> [TraderStats] {
        if let hit = cache[key], hit.expires > Date() { return hit.stats }
        let stats = try await fetch()
        cache[key] = (stats, Date().addingTimeInterval(cacheTimeout))
        return stats
    }
}

// MARK: - Helpers

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
