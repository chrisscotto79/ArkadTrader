// File: Core/Tickers/TickerFeedService.swift
// Posts about a ticker, the ticker's Bullish/Bearish split, and trending tickers.
//
// Free mode (docs/backend-contracts.md, section 0): there is no server, so all of this is plain
// Firestore queries on `posts`, counted on the phone.
// - Ticker feed and sentiment: `tickers` array-contains SYMBOL, ordered by `createdAt` desc.
//   Needs the composite index (tickers CONTAINS, createdAt DESC) in firestore.indexes.json.
// - Trending: `createdAt >= now - window`, ordered desc. Single-field, so no composite index.
// Hidden posts (isHidden == true) and posts by people you've blocked are skipped everywhere.
// Prices come from WatchlistQuotes (Finnhub, stocks only).

import Foundation
import FirebaseFirestore

// MARK: - Models

/// Bullish/Bearish split over a ticker's recent posts.
struct TickerSentimentSummary: Hashable, Sendable {
    let bullishCount: Int
    let bearishCount: Int
    /// How many recent posts were looked at (tagged or not).
    let postsConsidered: Int

    /// Fewer tagged posts than this and there's no summary.
    static let minimumTaggedPosts = 3

    var taggedCount: Int { bullishCount + bearishCount }

    /// 0–100
    var bullishPercent: Double {
        taggedCount == 0 ? 0 : Double(bullishCount) / Double(taggedCount) * 100
    }

    /// 0–100
    var bearishPercent: Double { taggedCount == 0 ? 0 : 100 - bullishPercent }

    /// Nil when fewer than `minimumTaggedPosts` posts are tagged.
    static func make(bullish: Int, bearish: Int, postsConsidered: Int) -> TickerSentimentSummary? {
        guard bullish + bearish >= minimumTaggedPosts else { return nil }
        return TickerSentimentSummary(bullishCount: bullish, bearishCount: bearish,
                                      postsConsidered: postsConsidered)
    }
}

/// A ticker that people are posting about.
struct TrendingTicker: Identifiable, Hashable, Sendable {
    let symbol: String
    /// Posts in the window that mention the ticker (each post counts once).
    let mentionCount: Int
    let bullishCount: Int
    let bearishCount: Int
    /// The newest post that mentions it.
    let lastMentionAt: Date
    /// The window the counts cover: 24 hours, or 7 days when the last day was quiet.
    let window: TimeInterval

    var id: String { symbol }

    /// Same rules as the ticker page's meter: nil with fewer than 3 tagged posts.
    var sentiment: TickerSentimentSummary? {
        TickerSentimentSummary.make(bullish: bullishCount, bearish: bearishCount, postsConsidered: mentionCount)
    }

    /// 0–100, or nil when there aren't enough tagged posts.
    var bullishPercent: Double? { sentiment?.bullishPercent }
}

// MARK: - Service

@MainActor
final class TickerFeedService {
    static let shared = TickerFeedService()

    /// How many recent posts the sentiment summary looks at.
    nonisolated static let sentimentSampleSize = 100
    /// Upper bound on posts read for trending, to keep Firestore reads (free plan) in check.
    nonisolated static let trendingDocumentCap = 300
    /// The trending window is widened to 7 days when the last day has fewer tickers than this.
    nonisolated static let trendingMinimumTickers = 5
    nonisolated static let trendingWideWindow: TimeInterval = 7 * 24 * 3600

    private let trendingCacheLifetime: TimeInterval = 5 * 60
    private let sentimentCacheLifetime: TimeInterval = 2 * 60
    private let quoteCacheLifetime: TimeInterval = 60

    private var db: Firestore { FirebaseServices.shared.db }
    private let blockStore = BlockStore.shared

    private struct TrendingCache {
        let window: TimeInterval
        let limit: Int
        let tickers: [TrendingTicker]
        let fetchedAt: Date
    }
    private var trendingCache: TrendingCache?
    private var trendingTask: Task<[TrendingTicker], Error>?
    private var trendingTaskKey: String?

    private var sentimentCache: [String: (summary: TickerSentimentSummary?, fetchedAt: Date)] = [:]
    private var quoteCache: [String: (quote: WatchlistQuote?, fetchedAt: Date)] = [:]

    private init() {}

    // MARK: - Ticker feed

    /// One page of posts mentioning `ticker`, newest first. Pass the returned cursor as `after`
    /// to get the next page; the cursor is nil when there are no more pages.
    /// A page can hold fewer than `limit` posts (hidden and blocked posts are dropped) while
    /// still returning a cursor.
    func posts(for ticker: String, limit: Int = 30, after: DocumentSnapshot?) async throws -> ([Post], DocumentSnapshot?) {
        let symbol = Self.normalize(ticker)
        guard !symbol.isEmpty, limit > 0 else { return ([], nil) }
        await blockStore.loadIfNeeded()

        var query = db.collection("posts")
            .whereField("tickers", arrayContains: symbol)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        if let after {
            query = query.start(afterDocument: after)
        }

        let snapshot = try await query.getDocuments()
        let posts = snapshot.documents
            .compactMap { try? Post.fromFirestore(data: $0.data(), id: $0.documentID) }
            .filter(isVisible)
        let cursor: DocumentSnapshot? = snapshot.documents.count < limit ? nil : snapshot.documents.last
        return (posts, cursor)
    }

    // MARK: - Sentiment

    /// Bullish/Bearish split over the ticker's most recent ~100 posts. Nil when fewer than 3
    /// of them are tagged. Cached for 2 minutes per ticker unless `forceRefresh`.
    func sentimentSummary(for ticker: String, forceRefresh: Bool = false) async throws -> TickerSentimentSummary? {
        let symbol = Self.normalize(ticker)
        guard !symbol.isEmpty else { return nil }
        if !forceRefresh, let cached = sentimentCache[symbol],
           Date().timeIntervalSince(cached.fetchedAt) < sentimentCacheLifetime {
            return cached.summary
        }
        await blockStore.loadIfNeeded()

        let snapshot = try await db.collection("posts")
            .whereField("tickers", arrayContains: symbol)
            .order(by: "createdAt", descending: true)
            .limit(to: Self.sentimentSampleSize)
            .getDocuments()

        var bullish = 0
        var bearish = 0
        var considered = 0
        for document in snapshot.documents {
            let data = document.data()
            guard isVisible(data) else { continue }
            considered += 1
            switch PostSentiment(firestoreValue: data[PostSentiment.firestoreField]) {
            case .bullish: bullish += 1
            case .bearish: bearish += 1
            case nil: break
            }
        }

        let summary = TickerSentimentSummary.make(bullish: bullish, bearish: bearish, postsConsidered: considered)
        sentimentCache[symbol] = (summary, Date())
        return summary
    }

    // MARK: - Trending

    /// The most-mentioned tickers in recent posts, with their Bullish/Bearish split, most
    /// mentions first. Reads at most ~300 posts. If the window has fewer than 5 tickers it's
    /// widened to 7 days (see `TrendingTicker.window`). Cached in memory for 5 minutes.
    func trendingTickers(window: TimeInterval = 24 * 3600, limit: Int = 10) async throws -> [TrendingTicker] {
        guard limit > 0, window > 0 else { return [] }
        if let cache = trendingCache, cache.window == window, cache.limit == limit,
           Date().timeIntervalSince(cache.fetchedAt) < trendingCacheLifetime {
            return cache.tickers
        }

        // Several screens asking at once share one fetch
        let key = "\(window)-\(limit)"
        if let trendingTask, trendingTaskKey == key {
            return try await trendingTask.value
        }

        let task = Task { () throws -> [TrendingTicker] in
            await blockStore.loadIfNeeded()
            var tickers = try await countMentions(window: window, limit: limit)
            if tickers.count < Self.trendingMinimumTickers, window < Self.trendingWideWindow {
                let wider = try await countMentions(window: Self.trendingWideWindow, limit: limit)
                if wider.count > tickers.count { tickers = wider }
            }
            return tickers
        }
        trendingTask = task
        trendingTaskKey = key
        defer {
            if trendingTaskKey == key {
                trendingTask = nil
                trendingTaskKey = nil
            }
        }

        let tickers = try await task.value
        trendingCache = TrendingCache(window: window, limit: limit, tickers: tickers, fetchedAt: Date())
        return tickers
    }

    /// Drops the cached trending list (and sentiment), for an explicit pull to refresh.
    func clearCaches() {
        trendingCache = nil
        sentimentCache = [:]
    }

    private func countMentions(window: TimeInterval, limit: Int) async throws -> [TrendingTicker] {
        let since = Date().addingTimeInterval(-window)
        let snapshot = try await db.collection("posts")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: since))
            .order(by: "createdAt", descending: true)
            .limit(to: Self.trendingDocumentCap)
            .getDocuments()

        struct Tally {
            var mentions = 0
            var bullish = 0
            var bearish = 0
            var lastMentionAt = Date.distantPast
        }
        var tallies: [String: Tally] = [:]

        for document in snapshot.documents {
            let data = document.data()
            guard isVisible(data), let rawTickers = data["tickers"] as? [String] else { continue }
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
            let sentiment = PostSentiment(firestoreValue: data[PostSentiment.firestoreField])
            // Each post counts once per ticker
            let symbols = Set(rawTickers.map(Self.normalize).filter(Self.isTickerSymbol))
            for symbol in symbols {
                var tally = tallies[symbol, default: Tally()]
                tally.mentions += 1
                if sentiment == .bullish { tally.bullish += 1 }
                if sentiment == .bearish { tally.bearish += 1 }
                tally.lastMentionAt = max(tally.lastMentionAt, createdAt)
                tallies[symbol] = tally
            }
        }

        return tallies
            .map { symbol, tally in
                TrendingTicker(symbol: symbol, mentionCount: tally.mentions,
                               bullishCount: tally.bullish, bearishCount: tally.bearish,
                               lastMentionAt: tally.lastMentionAt, window: window)
            }
            .sorted {
                if $0.mentionCount != $1.mentionCount { return $0.mentionCount > $1.mentionCount }
                if $0.lastMentionAt != $1.lastMentionAt { return $0.lastMentionAt > $1.lastMentionAt }
                return $0.symbol < $1.symbol
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Quotes

    /// Day quotes for stock symbols, through `WatchlistQuotes.fetch(symbols:)`. Symbols with
    /// no quote (crypto, unknown, no API key) are left out. Answers are cached for a minute.
    func quotes(for symbols: [String]) async -> [String: WatchlistQuote] {
        let now = Date()
        let wanted = Set(symbols.map(Self.normalize).filter { Self.assetType(for: $0) == .stock })
        guard !wanted.isEmpty, WatchlistQuotes.isConfigured else { return [:] }

        let stale = wanted.filter { symbol in
            guard let cached = quoteCache[symbol] else { return true }
            return now.timeIntervalSince(cached.fetchedAt) >= quoteCacheLifetime
        }
        if !stale.isEmpty {
            let fresh = await WatchlistQuotes.fetch(symbols: stale)
            for symbol in stale {
                quoteCache[symbol] = (fresh[symbol], Date())
            }
        }

        var result: [String: WatchlistQuote] = [:]
        for symbol in wanted {
            if let quote = quoteCache[symbol]?.quote { result[symbol] = quote }
        }
        return result
    }

    // MARK: - Helpers

    /// "$aapl " -> "AAPL"
    nonisolated static func normalize(_ ticker: String) -> String {
        var symbol = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        while symbol.hasPrefix("$") { symbol.removeFirst() }
        return symbol
    }

    /// Cashtag symbols are 1–5 letters (see `extractTickers(from:)` in Post.swift).
    nonisolated static func isTickerSymbol(_ symbol: String) -> Bool {
        (1...5).contains(symbol.count) && symbol.allSatisfy { $0.isASCII && $0.isUppercase && $0.isLetter }
    }

    /// Common crypto cashtags are watched as crypto; everything else as a stock.
    nonisolated static func assetType(for symbol: String) -> TradeType {
        cryptoSymbols.contains(normalize(symbol)) ? .crypto : .stock
    }

    private nonisolated static let cryptoSymbols: Set<String> = [
        "BTC", "ETH", "SOL", "XRP", "DOGE", "ADA", "AVAX", "DOT", "LINK", "LTC",
        "SHIB", "PEPE", "BNB", "TRX", "XLM", "USDT", "USDC"
    ]

    private func isVisible(_ post: Post) -> Bool {
        !post.isHidden && !blockStore.isBlocked(post.authorId)
    }

    private func isVisible(_ data: [String: Any]) -> Bool {
        if data["isHidden"] as? Bool == true { return false }
        if let authorId = data["authorId"] as? String, blockStore.isBlocked(authorId) { return false }
        return true
    }
}

// MARK: - Friendly errors

enum TickerFeedError {
    /// Plain-language load error, in the style of `TraderStats.friendlyLoadMessage(for:)`.
    /// A missing index (failed precondition) or unpublished rules (permission denied) mean the
    /// database update hasn't been published yet.
    static func friendlyMessage(for error: Error, feature: String = "This page") -> String {
        let nsError = error as NSError
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 9, 7:   // failedPrecondition (missing index), permissionDenied
                return "\(feature) will work once the database update is published."
            case 14:     // unavailable
                return "You seem to be offline. Check your connection and try again."
            case 16:     // unauthenticated
                return "Sign in again to see this."
            default:
                break
            }
        }
        return "Check your connection and try again."
    }
}

// MARK: - Formatting

enum TickerFormat {
    /// "+1.24%" / "-0.50%", the same style as the watchlist.
    static func percentChange(_ percent: Double) -> String {
        "\(percent >= 0 ? "+" : "")\(percent.formatted(.number.precision(.fractionLength(2))))%"
    }

    /// "+$1.24" / "-$0.50"
    static func dollarChange(_ change: Double) -> String {
        (change < 0 ? "-" : "+") + abs(change).formatted(.currency(code: "USD"))
    }

    /// Whole percentages for a bull/bear split that add up to 100: (62, 38).
    static func splitPercents(bullishPercent: Double) -> (bullish: Int, bearish: Int) {
        let bullish = Int(min(max(bullishPercent, 0), 100).rounded())
        return (bullish, 100 - bullish)
    }

    /// "24 hours" / "7 days"
    static func windowText(_ window: TimeInterval) -> String {
        let hours = Int((window / 3600).rounded())
        if hours < 48 { return hours == 1 ? "hour" : "\(hours) hours" }
        let days = Int((window / 86_400).rounded())
        return "\(days) days"
    }
}
