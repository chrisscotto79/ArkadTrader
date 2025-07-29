// File: Core/Communities/Models/LeaderboardEntry.swift
// Community Leaderboard Entry Model (separate from existing LeaderboardEntry)

import Foundation

struct CommunityLeaderboardEntry: Identifiable {
    let id: String
    let userId: String
    let username: String
    let communityId: String
    var rank: Int
    var score: Double
    
    // Basic stats only
    let totalTrades: Int
    let winRate: Double
    let totalProfitLoss: Double
    
    init(userId: String, username: String, communityId: String, totalTrades: Int, winRate: Double, totalProfitLoss: Double) {
        self.id = "\(communityId)_\(userId)"
        self.userId = userId
        self.username = username
        self.communityId = communityId
        self.rank = 0
        self.totalTrades = totalTrades
        self.winRate = winRate
        self.totalProfitLoss = totalProfitLoss
        
        // Simple score = win rate
        self.score = winRate
    }
}
