// File: Shared/Models/TradingEnums.swift
// Centralized Trading Enums - TradeFilter is defined here to avoid duplicates

import Foundation

enum TimeFrame: String, CaseIterable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case allTime = "All Time"
}

// MARK: - Trade Filter (Centralized Definition)
enum TradeFilter: CaseIterable {
    case all, open, closed, profitable, losses
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .open: return "Open"
        case .closed: return "Closed"
        case .profitable: return "Profitable"
        case .losses: return "Losses"
        }
    }
}
