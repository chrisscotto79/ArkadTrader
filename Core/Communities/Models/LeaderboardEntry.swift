// File: Core/Communities/Models/LeaderboardEntry.swift
// One trader's row on a community or global leaderboard, built from their closed trades.

import Foundation

struct CommunityLeaderboardEntry: Identifiable {
    let id: String
    let userId: String
    var username: String
    let communityId: String
    var isVerified = false
    var profileImageUrl: String?
    var rank: Int = 0
    /// The value the board is sorted by (depends on the category)
    var score: Double = 0

    let totalTrades: Int
    let winningTrades: Int
    let totalProfitLoss: Double
    let grossProfit: Double
    let grossLoss: Double
    let bestTrade: Double

    var winRate: Double {
        totalTrades == 0 ? 0 : Double(winningTrades) / Double(totalTrades) * 100
    }

    /// Gross profit divided by gross loss; capped when there are no losing trades
    var profitFactor: Double {
        guard grossLoss > 0 else { return grossProfit > 0 ? 99 : 0 }
        return min(grossProfit / grossLoss, 99)
    }

    init(userId: String, communityId: String, trades: [Trade], user: User?) {
        self.id = "\(communityId)_\(userId)"
        self.userId = userId
        self.communityId = communityId
        username = "trader"

        let results = trades.map(\.profitLoss)
        totalTrades = results.count
        winningTrades = results.filter { $0 > 0 }.count
        totalProfitLoss = results.reduce(0, +)
        grossProfit = results.filter { $0 > 0 }.reduce(0, +)
        grossLoss = -results.filter { $0 < 0 }.reduce(0, +)
        bestTrade = results.max() ?? 0
        apply(user)
    }

    /// Fill in profile details once the user record is known
    mutating func apply(_ user: User?) {
        guard let user else { return }
        username = user.username
        isVerified = user.isVerified
        profileImageUrl = user.profileImageUrl
    }
}
