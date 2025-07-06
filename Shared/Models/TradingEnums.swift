// File: Shared/Models/TradingEnums.swift
// Simplified Trading Enums

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
