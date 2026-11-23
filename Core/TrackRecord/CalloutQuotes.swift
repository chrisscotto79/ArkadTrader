// File: Core/TrackRecord/CalloutQuotes.swift
// Finnhub quotes for callouts, through `WatchlistQuotes`, with one in-memory cache and one
// request spacer for the whole app so chat scrolling, posting and CalloutAutoTracker
// together stay well under Finnhub's free tier (60 calls a minute).
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
    /// Symbols that returned no quote, and when, so we don't keep asking for them
    private var misses: [String: Date] = [:]
    private var inflight: [String: Task<Quote?, Never>] = [:]
    /// Earliest time the next request may start
    private var nextSlot = Date.distantPast

    /// Display quotes younger than this are reused.
    private let displayFreshFor: TimeInterval = 5 * 60
    private let missRetryAfter: TimeInterval = 10 * 60
    /// Spacing after a display request, and the longest a display request will queue.
    private let displayGap: TimeInterval = 2
    private let displayMaxWait: TimeInterval = 20

    private init() {}

    // MARK: - Symbols

    /// Options are quoted on the premium, which Finnhub's /quote doesn't cover. Stocks have
    /// quotes; crypto and forex are tried and simply come back empty when Finnhub has none.
    static func canQuote(_ callout: TradeCallout) -> Bool {
        canQuote(assetType: callout.assetType)
    }

    static func canQuote(assetType: TradeType) -> Bool {
        WatchlistQuotes.isConfigured && assetType != .option
    }

    static func symbol(for callout: TradeCallout) -> String {
        WatchlistSymbol.normalize(callout.ticker)
    }

    // MARK: - Cache

    func cached(_ symbol: String) -> Quote? { cache[symbol] }

    // MARK: - Fetching

    /// A price to show on a callout card. Cached for a few minutes, shared between cards
    /// with the same ticker, and dropped (nil) rather than queued for long.
    func displayQuote(for symbol: String) async -> Quote? {
        if let hit = cache[symbol], Date().timeIntervalSince(hit.at) < displayFreshFor { return hit }
        if let miss = misses[symbol], Date().timeIntervalSince(miss) < missRetryAfter { return cache[symbol] }
        if let running = inflight[symbol] { return await running.value }

        let task = Task { [weak self] () -> Quote? in
            guard let self else { return nil }
            return await self.fetch(symbol, gap: self.displayGap, maxWait: self.displayMaxWait)
        }
        inflight[symbol] = task
        let quote = await task.value
        inflight[symbol] = nil
        return quote
    }

    /// A fresh price for checking a new callout's entry. Reuses a quote up to a minute old.
    func postingQuote(for symbol: String) async -> Quote? {
        if let hit = cache[symbol], Date().timeIntervalSince(hit.at) < 60 { return hit }
        return await fetch(symbol, gap: displayGap, maxWait: 10)
    }

    /// A price for CalloutAutoTracker. Always queues, spaced `gap` apart from other requests.
    func trackingQuote(for symbol: String, gap: TimeInterval) async -> Quote? {
        await fetch(symbol, gap: gap, maxWait: nil)
    }

    /// One Finnhub request, started no sooner than the reserved slot.
    private func fetch(_ symbol: String, gap: TimeInterval, maxWait: TimeInterval?) async -> Quote? {
        guard WatchlistQuotes.isConfigured, !symbol.isEmpty,
              let wait = reserveSlot(gap: gap, maxWait: maxWait) else { return nil }
        if wait > 0 {
            try? await Task.sleep(for: .seconds(wait))
        }
        let result = await WatchlistQuotes.fetch(symbols: [symbol])
        guard let quote = result[symbol] else {
            misses[symbol] = Date()
            return nil
        }
        let fresh = Quote(price: quote.price, at: Date())
        cache[symbol] = fresh
        misses[symbol] = nil
        return fresh
    }

    /// Reserves the next request slot and returns how long to wait for it,
    /// or nil when the wait would be longer than `maxWait`.
    private func reserveSlot(gap: TimeInterval, maxWait: TimeInterval?) -> TimeInterval? {
        let now = Date()
        let start = max(now, nextSlot)
        let wait = start.timeIntervalSince(now)
        if let maxWait, wait > maxWait { return nil }
        nextSlot = start.addingTimeInterval(gap)
        return wait
    }
}
