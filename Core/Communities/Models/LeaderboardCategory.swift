// File: Core/Communities/Models/LeaderboardCategory.swift
// The ways a leaderboard can be ranked.

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
        case .consistencyMasters: return "Highest win rate (3+ closed trades)"
        case .profitKings: return "Highest total realized P&L"
        case .volumeTraders: return "Most closed trades"
        case .riskMasters: return "Best profit factor: gross wins ÷ gross losses (3+ trades)"
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
