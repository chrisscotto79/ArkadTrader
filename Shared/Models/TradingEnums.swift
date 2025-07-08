// File: Shared/Models/TradingEnums.swift
// Centralized Trading Enums - TradeFilter is defined here to avoid duplicates

import Foundation

enum TimeFrame: String, CaseIterable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case allTime = "All Time"
}

enum MarketSentiment: String, CaseIterable, Codable {
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
