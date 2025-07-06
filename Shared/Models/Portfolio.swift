// File: Shared/Models/Portfolio.swift
// Simplified Portfolio Model

import Foundation

struct Portfolio: Identifiable, Codable {
    let id: UUID
    var userId: String
    var totalValue: Double
    var totalProfitLoss: Double
    var dayProfitLoss: Double
    var totalTrades: Int
    var openPositions: Int
    var winRate: Double
    var lastUpdated: Date
    
    init(userId: String) {
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
