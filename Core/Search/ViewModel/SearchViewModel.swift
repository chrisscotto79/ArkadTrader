// File: Core/Search/ViewModel/SearchViewModel.swift
// Discover search: runs user, post, trade and community searches in parallel, ranks and caches
// them. People you've blocked, their posts and hidden posts are left out; trades are only
// public ones. Recent searches are saved when you submit a search or open a result.

import Foundation
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var searchHistory: [String] = []
    @Published var currentQuery = ""

    // Discover suggestions shown before the user types
    @Published var suggestedCommunities: [Community] = []
    @Published var suggestedTraders: [User] = []
    @Published var isLoadingSuggestions = false
    @Published var hasLoadedSuggestions = false

    // MARK: - Private Properties
    private let authService = FirebaseAuthService.shared
    private let blockStore = BlockStore.shared
    /// Ranked results per lowercased query
    private var searchCache: [String: CachedSearchResult] = [:]
    private let maxCacheSize = 50
    private static let cacheLifetime: TimeInterval = 300
    private static let historyKey = "arkad_search_history"
    private static let historyLimit = 20

    private struct CachedSearchResult {
        let results: [SearchResult]
        let timestamp: Date

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > SearchViewModel.cacheLifetime
        }
    }

    // MARK: - Initialization
    init() {
        loadSearchHistory()
    }

    // MARK: - Search

    /// Searches for `query`. Results only land if `query` is still the current search when they
    /// arrive, so a slow earlier search can't replace a newer one.
    func search(query: String) async {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanQuery.isEmpty else {
            clearResults()
            return
        }

        guard authService.currentUser != nil else {
            errorMessage = "Sign in to search."
            showError = true
            isLoading = false
            return
        }

        currentQuery = cleanQuery

        if let cached = cachedResults(for: cleanQuery) {
            searchResults = visible(cached)
            isLoading = false
            return
        }

        isLoading = true
        searchResults = []
        errorMessage = ""
        showError = false
        await blockStore.loadIfNeeded()

        // Run the four searches in parallel; each one handles its own errors.
        async let userResults = searchUsers(query: cleanQuery)
        async let postResults = searchPosts(query: cleanQuery)
        async let tradeResults = searchTrades(query: cleanQuery)
        async let communityResults = searchCommunities(query: cleanQuery)
        let allResults = await userResults + postResults + tradeResults + communityResults

        let ranked = rankSearchResults(allResults, query: cleanQuery)
        cacheSearchResults(ranked, query: cleanQuery)

        // A newer search (or a clear) started meanwhile
        guard currentQuery == cleanQuery else { return }
        searchResults = visible(ranked)
        isLoading = false
    }

    private func searchUsers(query: String) async -> [SearchResult] {
        let users = (try? await authService.searchUsers(query: query, limit: 20)) ?? []
        return users.filter { !blockStore.isBlocked($0.id) }.map { SearchResult(user: $0) }
    }

    private func searchPosts(query: String) async -> [SearchResult] {
        let posts = (try? await authService.searchPosts(query: query, limit: 15)) ?? []
        return posts
            .filter { !$0.isHidden && !blockStore.isBlocked($0.authorId) }
            .map { SearchResult(post: $0) }
    }

    /// Public trades only (the database only lets you read other people's public trades).
    private func searchTrades(query: String) async -> [SearchResult] {
        let trades = (try? await authService.searchTrades(query: query, limit: 10)) ?? []
        return trades
            .filter { $0.isPublic && !blockStore.isBlocked($0.userId) }
            .map { SearchResult(trade: $0) }
    }

    private func searchCommunities(query: String) async -> [SearchResult] {
        let communities = (try? await authService.searchCommunities(query: query, limit: 10)) ?? []
        return communities.map { SearchResult(community: $0) }
    }

    /// Drops results from people blocked, and posts deleted or reported, since they were fetched.
    private func visible(_ results: [SearchResult]) -> [SearchResult] {
        results.filter { result in
            switch result.type {
            case .user:
                return result.user.map { !blockStore.isBlocked($0.id) } ?? false
            case .post:
                return result.post.map { PostStore.shared.isVisible($0) } ?? false
            case .trade:
                return result.trade.map { !blockStore.isBlocked($0.userId) } ?? false
            case .group:
                return true
            }
        }
    }

    // MARK: - Ranking

    private func rankSearchResults(_ results: [SearchResult], query: String) -> [SearchResult] {
        let queryLower = query.lowercased()
        return results
            .map { ($0, calculateRelevanceScore($0, query: queryLower)) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private func calculateRelevanceScore(_ result: SearchResult, query: String) -> Double {
        var score: Double = 0

        switch result.type {
        case .user:
            if let user = result.user {
                let username = user.username.lowercased()
                if username == query {
                    score += 100
                } else if username.hasPrefix(query) {
                    score += 80
                } else if username.contains(query) {
                    score += 60
                }
                if user.fullName.lowercased().contains(query) {
                    score += 50
                }
                if user.winRate > 70 {
                    score += 15
                } else if user.winRate > 50 {
                    score += 10
                }
                let daysSinceJoined = Date().timeIntervalSince(user.createdAt) / (24 * 3600)
                if daysSinceJoined < 30 {
                    score += 5
                }
            }

        case .post:
            if let post = result.post {
                let contentWords = post.content.lowercased().components(separatedBy: .whitespacesAndNewlines)
                for queryWord in query.components(separatedBy: .whitespacesAndNewlines) {
                    if contentWords.contains(queryWord) {
                        score += 20
                    } else if contentWords.contains(where: { $0.contains(queryWord) }) {
                        score += 10
                    }
                }
                if post.authorUsername.lowercased().contains(query) {
                    score += 30
                }
                score += min(Double(post.likesCount) * 0.5, 20)
                score += min(Double(post.commentsCount) * 0.3, 15)
                let daysSinceCreation = Date().timeIntervalSince(post.createdAt) / (24 * 3600)
                score += max(0, 10 - daysSinceCreation * 0.5)
            }

        case .trade:
            if let trade = result.trade {
                let ticker = trade.ticker.lowercased()
                if ticker == query {
                    score += 100
                } else if ticker.contains(query) {
                    score += 80
                }
                if trade.isOpen {
                    score += 20
                }
                if !trade.isOpen && trade.profitLossPercentage > 0 {
                    score += min(trade.profitLossPercentage * 0.1, 15)
                }
                let daysSinceEntry = Date().timeIntervalSince(trade.entryDate) / (24 * 3600)
                score += max(0, 15 - daysSinceEntry * 0.2)
            }

        case .group:
            if let community = result.community {
                let name = community.name.lowercased()
                if name == query {
                    score += 100
                } else if name.hasPrefix(query) {
                    score += 80
                } else if name.contains(query) {
                    score += 60
                }
                if community.description.lowercased().contains(query) {
                    score += 40
                }
                score += min(Double(community.memberCount) * 0.05, 25)
                if !community.isPrivate {
                    score += 10
                }
                let daysSinceCreated = Date().timeIntervalSince(community.createdAt) / (24 * 3600)
                if daysSinceCreated < 7 {
                    score += 8
                } else if daysSinceCreated < 30 {
                    score += 5
                }
            }
        }

        return score
    }

    // MARK: - Cache

    private func cachedResults(for query: String) -> [SearchResult]? {
        searchCache = searchCache.filter { !$0.value.isExpired }
        return searchCache[query.lowercased()]?.results
    }

    private func cacheSearchResults(_ results: [SearchResult], query: String) {
        searchCache = searchCache.filter { !$0.value.isExpired }
        if searchCache.count >= maxCacheSize,
           let oldestKey = searchCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
            searchCache.removeValue(forKey: oldestKey)
        }
        searchCache[query.lowercased()] = CachedSearchResult(results: results, timestamp: Date())
    }

    // MARK: - Recent searches

    /// Saves a search to Recent. Called when a search is submitted or a result is opened, not
    /// while typing. Drops older entries that are a start of this one ("Chri" before "Chris")
    /// and case-insensitive duplicates.
    func recordSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lowered = trimmed.lowercased()
        searchHistory.removeAll { lowered.hasPrefix($0.lowercased()) }
        searchHistory.insert(trimmed, at: 0)
        if searchHistory.count > Self.historyLimit {
            searchHistory = Array(searchHistory.prefix(Self.historyLimit))
        }
        saveSearchHistory()
    }

    private func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: Self.historyKey),
           let history = try? JSONDecoder().decode([String].self, from: data) {
            let cleaned = Self.cleanedHistory(history)
            searchHistory = cleaned
            // Older versions saved every keystroke ("C", "Ch", ..., "Chris"); tidy those once.
            if cleaned != history { saveSearchHistory() }
        }
    }

    /// Newest first: drops entries that are the start of a newer one, and case-insensitive repeats.
    static func cleanedHistory(_ history: [String]) -> [String] {
        var kept: [String] = []
        for entry in history {
            let lowered = entry.lowercased()
            if kept.contains(where: { $0.lowercased().hasPrefix(lowered) }) { continue }
            kept.append(entry)
        }
        return kept
    }

    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: Self.historyKey)
        }
    }

    func clearSearchHistory() {
        searchHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.historyKey)
    }

    // MARK: - Discover Suggestions

    /// Popular public communities and the most-followed traders, for Discover's empty state.
    /// Each list fails quietly: if it can't load, its section just isn't shown.
    func loadDiscoverSuggestions() async {
        guard !isLoadingSuggestions else { return }
        isLoadingSuggestions = true

        async let communitiesRequest = FirebaseServices.shared.getCommunities(limit: 20)
        async let tradersRequest = authService.getPopularUsers(limit: 11)
        async let blocks: Void = blockStore.loadIfNeeded()

        let loadedCommunities = (try? await communitiesRequest) ?? []
        let loadedTraders = (try? await tradersRequest) ?? []
        await blocks
        let currentUserId = authService.currentUser?.id

        suggestedCommunities = Array(
            loadedCommunities
                .sorted { $0.discoveryScore > $1.discoveryScore }
                .prefix(8)
        )
        suggestedTraders = Array(
            loadedTraders
                .filter { $0.id != currentUserId && !blockStore.isBlocked($0.id) }
                .prefix(10)
        )

        isLoadingSuggestions = false
        hasLoadedSuggestions = true
    }

    // MARK: - Tickers

    /// Unique tickers in the current trade results, in ranked order, so Discover can offer
    /// "Add to watchlist". An option trade's ticker is its underlying, so it's watched as a stock.
    var resultTickers: [SearchTicker] {
        var seen = Set<String>()
        var tickers: [SearchTicker] = []
        for result in searchResults where result.type == .trade {
            guard let trade = result.trade else { continue }
            let symbol = WatchlistSymbol.normalize(trade.ticker)
            guard WatchlistSymbol.isValid(symbol), seen.insert(symbol).inserted else { continue }
            let assetType: TradeType = trade.tradeType == .option ? .stock : trade.tradeType
            tickers.append(SearchTicker(symbol: symbol, assetType: assetType))
        }
        return tickers
    }

    // MARK: - Utility Methods

    func clearResults() {
        searchResults = []
        currentQuery = ""
        isLoading = false
        errorMessage = ""
        showError = false
    }
}

// MARK: - Supporting Types

/// A ticker found in Discover's trade results.
struct SearchTicker: Identifiable, Hashable {
    let symbol: String
    let assetType: TradeType
    var id: String { symbol }
}
