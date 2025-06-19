//
//  LeaderboardEntry.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Models/LeaderboardEntry.swift

import Foundation

struct LeaderboardEntry: Identifiable, Codable {
    let id: UUID
    var rank: Int
    var username: String
    var profitLoss: Double
    var winRate: Double
    var isVerified: Bool
    var userId: UUID?
    var totalTrades: Int
    var marketStance: MarketStance?
    
    init(rank: Int, username: String, profitLoss: Double, winRate: Double, isVerified: Bool) {
        self.id = UUID()
        self.rank = rank
        self.username = username
        self.profitLoss = profitLoss
        self.winRate = winRate
        self.isVerified = isVerified
        self.userId = nil
        self.totalTrades = 0
        self.marketStance = nil
    }
}

enum MarketStance: String, CaseIterable, Codable {
    case bullish = "bullish"
    case bearish = "bearish"
    case neutral = "neutral"
    
    var displayName: String {
        switch self {
        case .bullish: return "Bullish"
        case .bearish: return "Bearish"
        case .neutral: return "Neutral"
        }
    }
    
    var emoji: String {
        switch self {
        case .bullish: return "🐂"
        case .bearish: return "🐻"
        case .neutral: return "⚖️"
        }
    }
}
