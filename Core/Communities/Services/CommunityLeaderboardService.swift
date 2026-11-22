// File: Core/Communities/Services/CommunityLeaderboardService.swift
// Ranks traders by their closed trades, either within one community or across the whole app.

import Foundation
import FirebaseFirestore

@MainActor
class CommunityLeaderboardService: ObservableObject {

    static let shared = CommunityLeaderboardService()

    let authService = FirebaseAuthService.shared
    private var db: Firestore { FirebaseServices.shared.db }

    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var lastUpdated: Date?

    /// Minimum closed trades to appear in the win-rate and risk boards
    static let minimumTradesForRatios = 3

    /// Firestore allows at most 30 values in an `in` filter
    private let inQueryLimit = 30
    /// Upper bound on closed trades read for the global board
    private let globalTradeScanLimit = 2000

    private var cache: [String: (entries: [CommunityLeaderboardEntry], expires: Date)] = [:]
    private let cacheTimeout: TimeInterval = 300

    private init() {}

    // MARK: - Public API

    /// Leaderboard for one community's members
    func getLeaderboard(
        communityId: String,
        category: LeaderboardCategory,
        timeframe: LeaderboardTimeframe = .allTime,
        limit: Int = 50
    ) async throws -> [CommunityLeaderboardEntry] {
        let key = "\(communityId)_\(category.rawValue)_\(timeframe.rawValue)"
        if let cached = cachedEntries(for: key) { return cached }

        isLoading = true
        errorMessage = ""
        defer { isLoading = false; lastUpdated = Date() }

        do {
            let members = try await authService.getCommunityMembers(communityId: communityId)
            let users = Dictionary(members.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let trades = try await closedTrades(forUserIds: Array(users.keys))
            let entries = rank(
                trades: filter(trades, to: timeframe),
                users: users,
                communityId: communityId,
                category: category,
                limit: limit
            )
            cache[key] = (entries, Date().addingTimeInterval(cacheTimeout))
            return entries
        } catch {
            errorMessage = "Couldn't load the leaderboard: \(error.localizedDescription)"
            throw error
        }
    }

    /// Leaderboard across every trader in the app
    func getGlobalLeaderboard(
        category: LeaderboardCategory,
        timeframe: LeaderboardTimeframe = .allTime,
        limit: Int = 100
    ) async throws -> [CommunityLeaderboardEntry] {
        let key = "global_\(category.rawValue)_\(timeframe.rawValue)"
        if let cached = cachedEntries(for: key) { return cached }

        isLoading = true
        errorMessage = ""
        defer { isLoading = false; lastUpdated = Date() }

        do {
            let snapshot = try await db.collection("trades")
                .whereField("isOpen", isEqualTo: false)
                .limit(to: globalTradeScanLimit)
                .getDocuments()
            let trades = filter(
                snapshot.documents.compactMap { try? Trade.fromFirestore(data: $0.data(), id: $0.documentID) },
                to: timeframe
            )

            // Rank first, then look up profiles only for the users who made the cut
            var entries = rank(trades: trades, users: nil, communityId: "global", category: category, limit: limit)
            let users = Dictionary(
                try await fetchUsers(ids: entries.map(\.userId)).map { ($0.id, $0) },
                uniquingKeysWith: { a, _ in a }
            )
            for i in entries.indices { entries[i].apply(users[entries[i].userId]) }

            cache[key] = (entries, Date().addingTimeInterval(cacheTimeout))
            return entries
        } catch {
            errorMessage = "Couldn't load the global leaderboard: \(error.localizedDescription)"
            throw error
        }
    }

    func clearCache() {
        cache.removeAll()
    }

    /// Drop cached boards for one community (or "global") so the next load is fresh
    func invalidate(communityId: String) {
        cache = cache.filter { !$0.key.hasPrefix("\(communityId)_") }
    }

    // MARK: - Ranking

    private func rank(
        trades: [Trade],
        users: [String: User]?,
        communityId: String,
        category: LeaderboardCategory,
        limit: Int
    ) -> [CommunityLeaderboardEntry] {
        let byUser = Dictionary(grouping: trades, by: \.userId)

        var entries: [CommunityLeaderboardEntry] = byUser.compactMap { userId, trades in
            // Community boards only rank members (users != nil); the global board ranks everyone
            if let users, users[userId] == nil { return nil }
            return CommunityLeaderboardEntry(userId: userId, communityId: communityId, trades: trades, user: users?[userId])
        }

        switch category {
        case .consistencyMasters:
            entries = entries.filter { $0.totalTrades >= Self.minimumTradesForRatios }
            for i in entries.indices { entries[i].score = entries[i].winRate }
        case .profitKings:
            for i in entries.indices { entries[i].score = entries[i].totalProfitLoss }
        case .volumeTraders:
            for i in entries.indices { entries[i].score = Double(entries[i].totalTrades) }
        case .riskMasters:
            entries = entries.filter { $0.totalTrades >= Self.minimumTradesForRatios && $0.totalProfitLoss > 0 }
            for i in entries.indices { entries[i].score = entries[i].profitFactor }
        }

        // Ties go to the trader with more trades, then higher P&L
        entries.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.totalTrades != $1.totalTrades { return $0.totalTrades > $1.totalTrades }
            return $0.totalProfitLoss > $1.totalProfitLoss
        }

        return entries.prefix(limit).enumerated().map { index, entry in
            var ranked = entry
            ranked.rank = index + 1
            return ranked
        }
    }

    /// Keep trades closed within the timeframe (falls back to entry date for trades without an exit date)
    func filter(_ trades: [Trade], to timeframe: LeaderboardTimeframe) -> [Trade] {
        guard let start = timeframe.startDate() else { return trades.filter { !$0.isOpen } }
        return trades.filter { !$0.isOpen && ($0.exitDate ?? $0.entryDate) >= start }
    }

    // MARK: - Firestore

    private func closedTrades(forUserIds userIds: [String]) async throws -> [Trade] {
        var trades: [Trade] = []
        for chunk in userIds.chunked(into: inQueryLimit) {
            let snapshot = try await db.collection("trades")
                .whereField("userId", in: chunk)
                .getDocuments()
            trades += snapshot.documents.compactMap { try? Trade.fromFirestore(data: $0.data(), id: $0.documentID) }
        }
        return trades.filter { !$0.isOpen }
    }

    private func fetchUsers(ids: [String]) async throws -> [User] {
        var users: [User] = []
        for chunk in ids.chunked(into: inQueryLimit) {
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            users += snapshot.documents.compactMap { try? User.fromFirestore(data: $0.data(), id: $0.documentID) }
        }
        return users
    }

    private func cachedEntries(for key: String) -> [CommunityLeaderboardEntry]? {
        guard let hit = cache[key], hit.expires > Date() else { return nil }
        return hit.entries
    }
}

// MARK: - Supporting Types

enum LeaderboardTimeframe: String, CaseIterable {
    case weekly
    case monthly
    case yearly
    case allTime

    var displayName: String {
        switch self {
        case .weekly: return "Week"
        case .monthly: return "Month"
        case .yearly: return "Year"
        case .allTime: return "All Time"
        }
    }

    /// Start of the window, or nil for all time
    func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .weekly: return calendar.dateInterval(of: .weekOfYear, for: now)?.start
        case .monthly: return calendar.dateInterval(of: .month, for: now)?.start
        case .yearly: return calendar.dateInterval(of: .year, for: now)?.start
        case .allTime: return nil
        }
    }
}

enum LeaderboardError: Error, LocalizedError {
    case noCurrentUser

    var errorDescription: String? {
        switch self {
        case .noCurrentUser: return "You need to be signed in to see leaderboards"
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
