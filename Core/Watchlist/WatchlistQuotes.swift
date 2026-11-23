// File: Core/Watchlist/WatchlistQuotes.swift
// Stock quotes with the day's change, for the watchlist, price alerts and ticker pages.
// A thin wrapper over QuoteClient (Shared/Services/QuoteClient.swift), which owns the Finnhub
// budget, cache and 429 handling.

import Foundation

enum WatchlistQuotes {
    static var isConfigured: Bool { QuoteClient.isConfigured }

    /// Stock symbols only. Symbols without a quote (unknown, rate limited, offline) are left out.
    static func fetch(symbols: Set<String>) async -> [String: WatchlistQuote] {
        let results = await fetchResults(symbols: symbols)
        return results.compactMapValues { $0.quote.map(WatchlistQuote.init) }
    }

    /// Like `fetch`, but every symbol gets an answer, so callers can tell "no price for this
    /// symbol" from "live prices are unavailable right now".
    static func fetchResults(symbols: Set<String>) async -> [String: QuoteResult] {
        guard isConfigured, !symbols.isEmpty else { return [:] }
        return await QuoteClient.shared.quotes(for: symbols)
    }
}

extension WatchlistQuote {
    init(_ quote: MarketQuote) {
        self.init(price: quote.current, change: quote.change, changePercent: quote.changePercent)
    }
}

extension Dictionary where Value == QuoteResult {
    /// True when every answer failed for a temporary reason (rate limit, offline).
    var allTemporarilyUnavailable: Bool {
        !isEmpty && values.allSatisfy(\.isTemporarilyUnavailable)
    }
}
