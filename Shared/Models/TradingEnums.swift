import Foundation

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

    var emoji: String {
        switch self {
        case .bullish: return "🐂"
        case .bearish: return "🐻"
        case .neutral: return "⚖️"
        }
    }

    var color: String {
        switch self {
        case .bullish: return "green"
        case .bearish: return "red"
        case .neutral: return "gray"
        }
    }
}

enum TimeFrame: String, CaseIterable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case allTime = "All Time"
}
