// File: Core/TrackRecord/CalloutQuotes.swift
// Quotes for callouts. A thin layer over QuoteClient (Shared/Services/QuoteClient.swift), which
// owns the Finnhub call budget, the shared cache, in-flight coalescing and 429 back-off. This
// keeps a main-actor copy of the last price per symbol so cards can show it synchronously.
// For the day's high/low (stop and target checks) use `QuoteClient.shared.quote(for:)` directly.
// Quotes fetched here for display are never written to Firestore.

import Foundation

@MainActor
final class CalloutQuotes {
    static let shared = CalloutQuotes()

    struct Quote: Equatable {
        let price: Double
        let at: Date
    }

    private var cache: [String: Quote] = [:]

    /// Display quotes younger than this are reused.
    private let displayFreshFor: TimeInterval = 5 * 60

    private init() {}

    // MARK: - Symbols

    /// Finnhub's /quote covers stocks and ETFs only ("BTC" is an ETF there), so crypto, forex
    /// and options have no live price.
    static func canQuote(_ callout: TradeCallout) -> Bool {
        canQuote(assetType: callout.assetType)
    }

    static func canQuote(assetType: TradeType) -> Bool {
        QuoteClient.isConfigured && assetType == .stock
    }

    static func symbol(for callout: TradeCallout) -> String {
        WatchlistSymbol.normalize(callout.ticker)
    }

    // MARK: - Cache

    func cached(_ symbol: String) -> Quote? { cache[symbol] }

    // MARK: - Fetching

    /// A price to show on a callout card. Reuses a price up to five minutes old and gives up
    /// (nil) rather than waiting long for call budget.
    func displayQuote(for symbol: String) async -> Quote? {
        if let hit = cache[symbol], Date().timeIntervalSince(hit.at) < displayFreshFor { return hit }
        return await fetch(symbol, maxAge: displayFreshFor, maxWait: 2)
    }

    /// A fresh price for checking a new callout's entry. Reuses a quote up to 30 seconds old.
    func postingQuote(for symbol: String) async -> Quote? {
        await fetch(symbol, maxAge: QuoteClient.defaultMaxAge, maxWait: 10)
    }

    /// A price for CalloutAutoTracker. `gap` is kept for callers; QuoteClient now does the spacing.
    func trackingQuote(for symbol: String, gap: TimeInterval) async -> Quote? {
        await fetch(symbol, maxAge: QuoteClient.defaultMaxAge, maxWait: max(gap, 1) * 10)
    }

    private func fetch(_ symbol: String, maxAge: TimeInterval, maxWait: TimeInterval) async -> Quote? {
        guard QuoteClient.isConfigured, !symbol.isEmpty else { return nil }
        guard let quote = await QuoteClient.shared.quote(for: symbol, maxAge: maxAge, maxWait: maxWait).quote else {
            return nil
        }
        let fresh = Quote(price: quote.current, at: quote.fetchedAt)
        cache[symbol] = fresh
        return fresh
    }
}
