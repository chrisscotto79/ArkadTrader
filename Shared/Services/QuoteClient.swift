// File: Shared/Services/QuoteClient.swift
// The one Finnhub client in the app. Every stock quote (portfolio, trade proof checks, watchlist,
// price alerts, callouts, ticker pages) goes through `QuoteClient.shared`, so they share:
// - a token bucket of 50 calls a minute (Finnhub's free tier allows 60),
// - a per-symbol cache (30 s by default) and one in-flight request per symbol,
// - HTTP 429 handling: back off, and report `.rateLimited` instead of a price.
// Finnhub's /quote covers stocks and ETFs only. "BTC" resolves to an ETF, so callers must not
// ask for crypto, forex or option prices. Quotes are never written to Firestore.

import Foundation

/// One Finnhub /quote answer: { c, d, dp, h, l, o, pc, t }.
struct MarketQuote: Equatable, Sendable {
    let symbol: String
    /// "c": current (last) price
    let current: Double
    /// "d": change since the previous close, in dollars
    let change: Double?
    /// "dp": change since the previous close, in percent
    let changePercent: Double?
    /// "h" / "l": the session's high and low
    let high: Double?
    let low: Double?
    /// "o": the session's open
    let open: Double?
    /// "pc": previous close
    let previousClose: Double?
    /// "t": time of the last trade; nil when Finnhub doesn't send one
    let time: Date?
    /// When the app received it
    let fetchedAt: Date

    var age: TimeInterval { Date().timeIntervalSince(fetchedAt) }
}

/// What `QuoteClient` answers. Only `.quote` carries a price; never treat anything else as one.
enum QuoteResult: Equatable, Sendable {
    case quote(MarketQuote)
    /// Finnhub has no price for the symbol (unknown symbol: it answers with zeros)
    case noQuote
    /// Over our call budget, or Finnhub answered 429. Try again shortly.
    case rateLimited
    /// Network or server error
    case unavailable
    /// No Finnhub key in this build
    case notConfigured

    var quote: MarketQuote? {
        if case .quote(let quote) = self { return quote }
        return nil
    }

    /// True when the price is missing for a reason that may clear up on retry
    var isTemporarilyUnavailable: Bool {
        self == .rateLimited || self == .unavailable
    }
}

actor QuoteClient {
    static let shared = QuoteClient()

    /// Default freshness: a cached quote younger than this is reused.
    static let defaultMaxAge: TimeInterval = 30

    nonisolated static var isConfigured: Bool { !AppConfig.finnhubAPIKey.isEmpty }

    // Token bucket: `capacity` calls, refilled evenly over a minute.
    private let capacity: Double = 50
    private var tokens: Double = 50
    private var lastRefill = Date()

    /// After a 429: no calls until then
    private var blockedUntil: Date?
    private var backoff: TimeInterval = 0

    private var cache: [String: MarketQuote] = [:]
    /// Symbols Finnhub had no price for, and when, so we don't keep asking
    private var misses: [String: Date] = [:]
    private let missRetryAfter: TimeInterval = 10 * 60
    private var inFlight: [String: Task<QuoteResult, Never>] = [:]

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    // MARK: - Public API

    /// A quote for one stock/ETF symbol, at most `maxAge` seconds old. Waits up to `maxWait`
    /// seconds for call budget, otherwise answers `.rateLimited`.
    func quote(for rawSymbol: String, maxAge: TimeInterval = QuoteClient.defaultMaxAge,
               maxWait: TimeInterval = 8) async -> QuoteResult {
        let symbol = Self.normalize(rawSymbol)
        guard Self.isConfigured else { return .notConfigured }
        guard !symbol.isEmpty else { return .noQuote }

        if let hit = cache[symbol], hit.age < maxAge { return .quote(hit) }
        if let miss = misses[symbol], Date().timeIntervalSince(miss) < missRetryAfter { return .noQuote }
        if let running = inFlight[symbol] { return await running.value }

        let task = Task { await self.fetch(symbol, maxWait: maxWait) }
        inFlight[symbol] = task
        let result = await task.value
        inFlight[symbol] = nil
        return result
    }

    /// Quotes for several symbols. Every symbol gets an answer.
    func quotes(for symbols: Set<String>, maxAge: TimeInterval = QuoteClient.defaultMaxAge,
                maxWait: TimeInterval = 8) async -> [String: QuoteResult] {
        await withTaskGroup(of: (String, QuoteResult).self) { group in
            for symbol in symbols {
                group.addTask { (symbol, await self.quote(for: symbol, maxAge: maxAge, maxWait: maxWait)) }
            }
            var results: [String: QuoteResult] = [:]
            for await (symbol, result) in group { results[symbol] = result }
            return results
        }
    }

    /// The last quote received for a symbol, however old (for display while refreshing).
    func cachedQuote(for rawSymbol: String) -> MarketQuote? {
        cache[Self.normalize(rawSymbol)]
    }

    /// Spends one call from the shared budget for another Finnhub endpoint (market news).
    /// False when over budget or backing off after a 429.
    func reserveCall(maxWait: TimeInterval = 5) async -> Bool {
        await acquireToken(maxWait: maxWait)
    }

    /// Tells the client another Finnhub endpoint answered 429.
    func reportRateLimited(retryAfter: TimeInterval? = nil) {
        noteRateLimited(retryAfter: retryAfter)
    }

    /// Forgets cached quotes (sign-out).
    func reset() {
        cache = [:]
        misses = [:]
    }

    /// Upper-cased, trimmed symbol ("aapl " -> "AAPL"); slashes and spaces removed.
    nonisolated static func normalize(_ raw: String) -> String {
        raw.uppercased().filter { !$0.isWhitespace && $0 != "/" && $0 != "$" }
    }

    // MARK: - Fetching

    private func fetch(_ symbol: String, maxWait: TimeInterval) async -> QuoteResult {
        guard await acquireToken(maxWait: maxWait) else { return .rateLimited }

        var components = URLComponents(string: "https://finnhub.io/api/v1/quote")
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "token", value: AppConfig.finnhubAPIKey)
        ]
        guard let url = components?.url else { return .unavailable }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            return .unavailable
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 {
                let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init)
                noteRateLimited(retryAfter: retryAfter)
                return .rateLimited
            }
            guard (200..<300).contains(http.statusCode) else { return .unavailable }
        }
        backoff = 0

        guard let decoded = try? JSONDecoder().decode(RawQuote.self, from: data) else { return .unavailable }
        guard let current = decoded.c, current.isFinite, current > 0 else {
            misses[symbol] = Date()
            cache[symbol] = nil
            return .noQuote
        }
        let quote = MarketQuote(
            symbol: symbol,
            current: current,
            change: decoded.d.finite,
            changePercent: decoded.dp.finite,
            high: decoded.h.positive,
            low: decoded.l.positive,
            open: decoded.o.positive,
            previousClose: decoded.pc.positive,
            time: decoded.t.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil },
            fetchedAt: Date()
        )
        cache[symbol] = quote
        misses[symbol] = nil
        return .quote(quote)
    }

    private struct RawQuote: Decodable {
        let c: Double?
        let d: Double?
        let dp: Double?
        let h: Double?
        let l: Double?
        let o: Double?
        let pc: Double?
        let t: Double?
    }

    // MARK: - Budget

    /// Takes one token, waiting for a refill up to `maxWait` seconds.
    private func acquireToken(maxWait: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(maxWait)
        while true {
            let now = Date()
            if let blockedUntil, now < blockedUntil {
                let wait = blockedUntil.timeIntervalSince(now)
                guard now.addingTimeInterval(wait) <= deadline else { return false }
                try? await Task.sleep(for: .seconds(wait))
                continue
            }
            refill(now: now)
            if tokens >= 1 {
                tokens -= 1
                return true
            }
            let wait = (1 - tokens) / (capacity / 60)
            guard now.addingTimeInterval(wait) <= deadline else { return false }
            try? await Task.sleep(for: .seconds(wait))
            if Task.isCancelled { return false }
        }
    }

    private func refill(now: Date) {
        let elapsed = now.timeIntervalSince(lastRefill)
        guard elapsed > 0 else { return }
        tokens = min(capacity, tokens + elapsed * capacity / 60)
        lastRefill = now
    }

    private func noteRateLimited(retryAfter: TimeInterval?) {
        backoff = min(max(backoff * 2, 15), 5 * 60)
        let wait = max(retryAfter ?? 0, backoff)
        blockedUntil = Date().addingTimeInterval(wait)
        tokens = 0
        lastRefill = Date()
    }
}

private extension Optional where Wrapped == Double {
    var finite: Double? { flatMap { $0.isFinite ? $0 : nil } }
    var positive: Double? { flatMap { $0.isFinite && $0 > 0 ? $0 : nil } }
}
