// File: Shared/Models/LeaderboardEntry.swift
// Simplified LeaderboardEntry Model

import Foundation

struct LeaderboardEntry: Identifiable, Codable {
    let id: UUID
    var rank: Int
    var username: String
    var profitLoss: Double
    var winRate: Double
    var isVerified: Bool
    var userId: String?
    
    init(rank: Int, username: String, profitLoss: Double, winRate: Double, isVerified: Bool) {
        self.id = UUID()
        self.rank = rank
        self.username = username
        self.profitLoss = profitLoss
        self.winRate = winRate
        self.isVerified = isVerified
        self.userId = nil
    }
}
