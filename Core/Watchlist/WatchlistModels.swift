// File: Core/Watchlist/WatchlistModels.swift
// Watchlist symbols, price alerts and quotes.
//
// users/{uid}/watchlist/{symbol}: { symbol, assetType, addedAt }
// users/{uid}/priceAlerts/{id}: { symbol, assetType, condition, targetPrice, isActive, createdAt, triggeredAt? }

import Foundation

struct WatchlistItem: Identifiable, Hashable, Sendable {
    let symbol: String
    let assetType: TradeType
    let addedAt: Date

    var id: String { symbol }

    /// Live prices come from Finnhub stock quotes, so only stocks have them for now.
    var hasLiveQuote: Bool { assetType == .stock }
}

enum PriceAlertCondition: String, CaseIterable, Hashable, Sendable {
    case above, below

    var title: String {
        switch self {
        case .above: return "Above"
        case .below: return "Below"
        }
    }

    var systemImage: String {
        switch self {
        case .above: return "arrow.up.right"
        case .below: return "arrow.down.right"
        }
    }

    /// "Rises above" / "Falls below", for sentences.
    var phrase: String {
        switch self {
        case .above: return "rises above"
        case .below: return "falls below"
        }
    }
}

struct PriceAlert: Identifiable, Hashable, Sendable {
    let id: String
    let symbol: String
    let assetType: TradeType
    let condition: PriceAlertCondition
    let targetPrice: Double
    let isActive: Bool
    let createdAt: Date
    let triggeredAt: Date?
}

struct WatchlistQuote: Hashable, Sendable {
    let price: Double
    /// Change since the previous close, in dollars.
    let change: Double?
    /// Change since the previous close, in percent.
    let changePercent: Double?
}

enum WatchlistSymbol {
    /// Upper-cases and strips spaces and slashes, so "eur/usd" becomes "EURUSD".
    /// Slashes aren't allowed in Firestore document ids.
    static func normalize(_ raw: String) -> String {
        raw.uppercased()
            .filter { !$0.isWhitespace && $0 != "/" }
    }

    /// 1–15 characters: letters, digits and . - : ^ =, with at least one letter or digit.
    static func isValid(_ symbol: String) -> Bool {
        guard (1...15).contains(symbol.count) else { return false }
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:^=")
        return symbol.allSatisfy { allowed.contains($0) }
            && symbol.contains { $0.isLetter || $0.isNumber }
    }
}
