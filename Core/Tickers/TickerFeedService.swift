// File: Core/Tickers/TickerFeedService.swift
// Posts about a ticker, the ticker's Bullish/Bearish split, and trending tickers.
//
// Free mode (docs/backend-contracts.md, section 0): there is no server, so all of this is plain
// Firestore queries on `posts`, counted on the phone.
// - Ticker feed and sentiment: `tickers` array-contains SYMBOL, ordered by `createdAt` desc.
//   Needs the composite index (tickers CONTAINS, createdAt DESC) in firestore.indexes.json.
// - Trending: `createdAt >= now - window`, ordered desc. Single-field, so no composite index.
// One person can't swing the numbers: sentiment counts each author's latest tagged post about
// the ticker (posts tagging several tickers don't vote), and trending counts each author once
// per ticker.
// Hidden posts (isHidden == true) and posts by people you've blocked are skipped everywhere.
// Prices come from QuoteClient via WatchlistQuotes (Finnhub, stocks only).

import Foundation
import FirebaseFirestore

// MARK: - Models

/// Bullish/Bearish split over a ticker's recent posts.
struct TickerSentimentSummary: Hashable, Sendable {
    /// People whose latest tagged post about the ticker is Bullish / Bearish.
    let bullishCount: Int
    let bearishCount: Int
    /// How many recent posts were looked at (tagged or not).
    let postsConsidered: Int

    /// Fewer people tagging than this and there's no summary.
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
    /// People who posted about the ticker in the window (each person counts once).
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

/// Bullish/Bearish votes for one ticker: one per author (their first post seen, so feed posts
/// newest first), and only from posts that tag that one ticker.
struct SentimentVotes {
    private var voted = Set<String>()
    private(set) var bullish = 0
    private(set) var bearish = 0

    mutating func add(_ data: [String: Any], for symbol: String) {
        guard let sentiment = PostSentiment(firestoreValue: data[PostSentiment.firestoreField]),
              let authorId = data["authorId"] as? String, !authorId.isEmpty,
              !voted.contains(authorId) else { return }
        let symbols = Set((data["tickers"] as? [String] ?? []).map(Cashtag.normalize).filter(Cashtag.isValid))
        guard symbols == [symbol] else { return }
        voted.insert(authorId)
        switch sentiment {
        case .bullish: bullish += 1
        case .bearish: bearish += 1
        }
    }
}

// MARK: - Service

@MainActor
final class TickerFeedService {
    static let shared = TickerFeedService()

    /// How many recent posts the sentiment summary looks at.
    nonisolated static let sentimentSampleSize = 100
    /// Upper bound on posts read for trending, to keep Firestore reads (free plan) in check.
    nonisolated static let trendingDocumentCap = 300
    /// The trending list uses 7 days when the last day has fewer tickers than this.
    nonisolated static let trendingMinimumTickers = 5
    nonisolated static let trendingWideWindow: TimeInterval = 7 * 24 * 3600

    private let trendingCacheLifetime: TimeInterval = 5 * 60
    private let sentimentCacheLifetime: TimeInterval = 2 * 60

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
            .compactMap(Post.fromDocument)
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

        var votes = SentimentVotes()
        var considered = 0
        // Newest first, so each author's first tagged post here is their latest
        for document in snapshot.documents {
            let data = document.data(with: .estimate)
            guard isVisible(data) else { continue }
            considered += 1
            votes.add(data, for: symbol)
        }
        let bullish = votes.bullish
        let bearish = votes.bearish

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
            let recent = try await recentPostData(since: Date().addingTimeInterval(-window))
            var tickers = countMentions(in: recent, window: window, limit: limit)
            // A quiet day: the last 7 days instead (a quiet app reads few posts either way)
            if tickers.count < Self.trendingMinimumTickers, window < Self.trendingWideWindow {
                let week = try await recentPostData(since: Date().addingTimeInterval(-Self.trendingWideWindow))
                let wider = countMentions(in: week, window: Self.trendingWideWindow, limit: limit)
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

    /// Visible posts since `since`, newest first, at most `trendingDocumentCap`.
    private func recentPostData(since: Date) async throws -> [[String: Any]] {
        let snapshot = try await db.collection("posts")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: since))
            .order(by: "createdAt", descending: true)
            .limit(to: Self.trendingDocumentCap)
            .getDocuments()
        return snapshot.documents.map { $0.data(with: .estimate) }.filter { isVisible($0) }
    }

    /// Tickers mentioned in the posts from the last `window`, counting each author once per
    /// ticker, with each author's latest single-ticker Bullish/Bearish tag. `documents` is
    /// newest first.
    private func countMentions(in documents: [[String: Any]], window: TimeInterval, limit: Int) -> [TrendingTicker] {
        let since = Date().addingTimeInterval(-window)

        struct Tally {
            var authors = Set<String>()
            var votes = SentimentVotes()
            var lastMentionAt = Date.distantPast
        }
        var tallies: [String: Tally] = [:]

        for data in documents {
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            guard createdAt >= since, let rawTickers = data["tickers"] as? [String] else { continue }
            let authorId = data["authorId"] as? String ?? ""
            for symbol in Set(rawTickers.map(Self.normalize).filter(Self.isTickerSymbol)) {
                var tally = tallies[symbol, default: Tally()]
                tally.authors.insert(authorId)
                tally.votes.add(data, for: symbol)
                tally.lastMentionAt = max(tally.lastMentionAt, createdAt)
                tallies[symbol] = tally
            }
        }

        return tallies
            .map { symbol, tally in
                TrendingTicker(symbol: symbol, mentionCount: tally.authors.count,
                               bullishCount: tally.votes.bullish, bearishCount: tally.votes.bearish,
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

    /// Day quotes for stock symbols, through QuoteClient (shared Finnhub budget and 30 s cache).
    /// Symbols with no quote (crypto, unknown, rate limited, no API key) are left out.
    func quotes(for symbols: [String]) async -> [String: WatchlistQuote] {
        let wanted = Set(symbols.map(Self.normalize).filter { Self.assetType(for: $0) == .stock })
        guard !wanted.isEmpty, WatchlistQuotes.isConfigured else { return [:] }
        return await WatchlistQuotes.fetch(symbols: wanted)
    }

    // MARK: - Helpers

    /// "$aapl " -> "AAPL"
    nonisolated static func normalize(_ ticker: String) -> String {
        Cashtag.normalize(ticker)
    }

    /// Cashtag symbols: 1-5 letters plus an optional class, like "BRK.B" (see `Cashtag`).
    nonisolated static func isTickerSymbol(_ symbol: String) -> Bool {
        Cashtag.isValid(symbol)
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
    static func friendlyMessage(for error: Error, feature: String = "posts") -> String {
        let nsError = error as NSError
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 9:      // failedPrecondition: an index that's still building
                return "Still setting up. Try again in a minute."
            case 14:     // unavailable
                return "You seem to be offline. Check your connection and try again."
            case 16:     // unauthenticated
                return "Sign in again to see this."
            default:
                break
            }
        }
        return "Couldn't load \(feature). Pull to refresh or try again."
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
