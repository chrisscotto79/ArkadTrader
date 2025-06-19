//
//  Portfolio.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Models/Portfolio.swift

import Foundation

struct Portfolio: Identifiable, Codable {
    let id: UUID
    var userId: UUID
    var totalValue: Double
    var totalProfitLoss: Double
    var dayProfitLoss: Double
    var totalTrades: Int
    var openPositions: Int
    var winRate: Double
    var lastUpdated: Date
    
    init(userId: UUID) {
        self.id = UUID()
        self.userId = userId
        self.totalValue = 0.0
        self.totalProfitLoss = 0.0
        self.dayProfitLoss = 0.0
        self.totalTrades = 0
        self.openPositions = 0
        self.winRate = 0.0
        self.lastUpdated = Date()
    }
    
    var totalProfitLossPercentage: Double {
        guard totalValue > 0 else { return 0 }
        return (totalProfitLoss / (totalValue - totalProfitLoss)) * 100
    }
    
    var dayProfitLossPercentage: Double {
        guard totalValue > 0 else { return 0 }
        return (dayProfitLoss / totalValue) * 100
    }
}
