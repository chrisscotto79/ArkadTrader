// File: Core/Communities/Models/LeaderboardCategory.swift
// Complete Leaderboard Category with All Types

import Foundation

enum LeaderboardCategory: String, CaseIterable {
    case consistencyMasters = "consistency"
    case profitKings = "profit"
    case volumeTraders = "volume"
    case riskMasters = "risk"
    
    var displayName: String {
        switch self {
        case .consistencyMasters: return "Consistency Masters"
        case .profitKings: return "Profit Kings"
        case .volumeTraders: return "Volume Traders"
        case .riskMasters: return "Risk Masters"
        }
    }
    
    var description: String {
        switch self {
        case .consistencyMasters: return "Highest win rates with minimum 5 trades"
        case .profitKings: return "Highest total profit & loss"
        case .volumeTraders: return "Most active traders by trade count"
        case .riskMasters: return "Best risk management and consistency"
        }
    }
    
    var icon: String {
        switch self {
        case .consistencyMasters: return "target"
        case .profitKings: return "dollarsign.circle.fill"
        case .volumeTraders: return "chart.bar.fill"
        case .riskMasters: return "shield.fill"
        }
    }
    
    var color: String {
        switch self {
        case .consistencyMasters: return "blue"
        case .profitKings: return "green"
        case .volumeTraders: return "orange"
        case .riskMasters: return "purple"
        }
    }
}
