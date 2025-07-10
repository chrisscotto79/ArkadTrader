// File: Core/Search/ViewModel/SearchViewModel.swift
// Enhanced Search ViewModel with advanced search functionality - NO MOCK DATA

import Foundation
import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var searchHistory: [String] = []
    @Published var suggestions: [SearchSuggestion] = []
    @Published var trendingTopics: [TrendingTopic] = []
    @Published var currentQuery = ""
    @Published var searchPerformance: SearchPerformance?
    
    // MARK: - Private Properties
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var searchCache: [String: CachedSearchResult] = [:]
    private let maxCacheSize = 50
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    private var searchStartTime: Date?
    
    // MARK: - Search Analytics
    struct SearchPerformance {
        let query: String
        let resultCount: Int
        let searchTime: TimeInterval
        let cacheHit: Bool
        let searchTimestamp: Date
    }
    
    private struct CachedSearchResult {
        let results: [SearchResult]
        let timestamp: Date
        let performance: SearchPerformance
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 300 // 5 minutes
        }
    }
    
    // MARK: - Initialization
    init() {
        loadSearchHistory()
        loadTrendingTopics()
        setupSearchSuggestions()
    }
    
    // MARK: - Enhanced Search Methods
    
    func search(query: String) async {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            clearResults()
            return
        }
        
        currentQuery = cleanQuery
        searchStartTime = Date()
        
        // Check cache first
        if let cachedResult = getCachedResult(for: cleanQuery) {
            await handleCachedResult(cachedResult, query: cleanQuery)
            return
        }
        
        // Perform new search
        await performNewSearch(query: cleanQuery)
        
        // Add to search history
        addToSearchHistory(cleanQuery)
    }
    
    private func performNewSearch(query: String) async {
        isLoading = true
        searchResults = []
        
        do {
            // Parallel search execution for better performance
            async let userResults = searchUsers(query: query)
            async let postResults = searchPosts(query: query)
            async let tradeResults = searchTrades(query: query)
            async let communityResults = searchCommunities(query: query)
            
            // Wait for all results
            let (users, posts, trades, communities) = try await (userResults, postResults, tradeResults, communityResults)
            
            // Combine and rank results
            let allResults = users + posts + trades + communities
            searchResults = rankSearchResults(allResults, query: query)
            
            // Cache the results
            cacheSearchResults(allResults, query: query)
            
            // Record performance
            recordSearchPerformance(query: query, resultCount: allResults.count, cacheHit: false)
            
        } catch {
            handleSearchError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Individual Search Methods
    
    private func searchUsers(query: String) async throws -> [SearchResult] {
        let users = try await authService.searchUsers(query: query)
        return users.map { SearchResult(user: $0) }
    }
    
    private func searchPosts(query: String) async throws -> [SearchResult] {
        let posts = try await authService.searchPosts(query: query)
        return posts.map { SearchResult(post: $0) }
    }
    
    private func searchTrades(query: String) async throws -> [SearchResult] {
        // TODO: Implement real trade search when backend is ready
        // Return empty array - no mock data
        return []
    }
    
    private func searchCommunities(query: String) async throws -> [SearchResult] {
        let communities = try await authService.searchCommunities(query: query)
        return communities.map { SearchResult(community: $0) }
    }
    
    // MARK: - Enhanced Result Ranking
    
    private func rankSearchResults(_ results: [SearchResult], query: String) -> [SearchResult] {
        let queryLower = query.lowercased()
        
        return results.sorted { result1, result2 in
            let score1 = calculateRelevanceScore(result1, query: queryLower)
            let score2 = calculateRelevanceScore(result2, query: queryLower)
            return score1 > score2
        }
    }
    
    private func calculateRelevanceScore(_ result: SearchResult, query: String) -> Double {
        var score: Double = 0
        
        switch result.type {
        case .user:
            if let user = result.user {
                // Exact username match gets highest score
                if user.username.lowercased() == query {
                    score += 100
                } else if user.username.lowercased().contains(query) {
                    score += 80
                }
                
                // Full name match
                if user.fullName.lowercased().contains(query) {
                    score += 60
                }
                
                // Verified users get bonus
                if user.isVerified {
                    score += 20
                }
                
                // Popular users get slight bonus
                score += min(Double(user.followersCount) / 1000, 10)
            }
            
        case .post:
            if let post = result.post {
                // Content relevance
                let contentMatch = post.content.lowercased().components(separatedBy: " ").filter { $0.contains(query) }.count
                score += Double(contentMatch) * 15
                
                // Recent posts get bonus
                let daysSinceCreation = Date().timeIntervalSince(post.createdAt) / (24 * 3600)
                score += max(0, 10 - daysSinceCreation)
                
                // Popular posts get bonus
                score += min(Double(post.likesCount) / 10, 15)
            }
            
        case .trade:
            if let trade = result.trade {
                // Exact ticker match
                if trade.ticker.lowercased() == query {
                    score += 90
                } else if trade.ticker.lowercased().contains(query) {
                    score += 70
                }
                
                // Open trades get slight bonus
                if trade.isOpen {
                    score += 10
                }
                
                // Recent trades get bonus
                let daysSinceEntry = Date().timeIntervalSince(trade.entryDate) / (24 * 3600)
                score += max(0, 5 - daysSinceEntry)
            }
            
        case .group:
            if let community = result.community {
                // Name match
                if community.name.lowercased().contains(query) {
                    score += 80
                }
                
                // Description match
                if community.description.lowercased().contains(query) {
                    score += 40
                }
                
                // Member count bonus
                score += min(Double(community.memberCount) / 100, 15)
                
                // Public communities get slight bonus for discoverability
                if !community.isPrivate {
                    score += 5
                }
            }
        }
        
        return score
    }
    
    // MARK: - Caching System
    
    private func getCachedResult(for query: String) -> CachedSearchResult? {
        guard let cached = searchCache[query.lowercased()],
              !cached.isExpired else {
            return nil
        }
        return cached
    }
    
    private func cacheSearchResults(_ results: [SearchResult], query: String) {
        // Clean expired cache entries
        cleanExpiredCache()
        
        // Remove oldest entries if cache is full
        if searchCache.count >= maxCacheSize {
            let oldestKey = searchCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key
            if let key = oldestKey {
                searchCache.removeValue(forKey: key)
            }
        }
        
        // Cache new results
        let performance = SearchPerformance(
            query: query,
            resultCount: results.count,
            searchTime: Date().timeIntervalSince(searchStartTime ?? Date()),
            cacheHit: false,
            searchTimestamp: Date()
        )
        
        searchCache[query.lowercased()] = CachedSearchResult(
            results: results,
            timestamp: Date(),
            performance: performance
        )
    }
    
    private func handleCachedResult(_ cached: CachedSearchResult, query: String) async {
        searchResults = cached.results
        
        // Record cache hit performance
        let cacheHitPerformance = SearchPerformance(
            query: query,
            resultCount: cached.results.count,
            searchTime: 0.001, // Cache hits are very fast
            cacheHit: true,
            searchTimestamp: Date()
        )
        searchPerformance = cacheHitPerformance
    }
    
    private func cleanExpiredCache() {
        searchCache = searchCache.filter { !$0.value.isExpired }
    }
    
    // MARK: - Search History Management
    
    private func addToSearchHistory(_ query: String) {
        // Remove if already exists
        searchHistory.removeAll { $0.lowercased() == query.lowercased() }
        
        // Add to beginning
        searchHistory.insert(query, at: 0)
        
        // Keep only last 20 searches
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        
        // Save to UserDefaults
        saveSearchHistory()
    }
    
    private func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: "search_history"),
           let history = try? JSONDecoder().decode([String].self, from: data) {
            searchHistory = history
        }
    }
    
    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "search_history")
        }
    }
    
    func clearSearchHistory() {
        searchHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "search_history")
    }
    
    // MARK: - Search Suggestions and Trending Topics - NO MOCK DATA
    
    private func setupSearchSuggestions() {
        // TODO: Load real search suggestions from backend based on user behavior
        // Initialize with empty array - no mock data
        suggestions = []
    }
    
    private func loadTrendingTopics() {
        // TODO: Load real trending topics from backend analytics
        // Initialize with empty array - no mock data
        trendingTopics = []
    }
    
    func getSuggestionsForQuery(_ query: String) -> [SearchSuggestion] {
        guard !query.isEmpty else { return suggestions }
        
        let queryLower = query.lowercased()
        return suggestions.filter { suggestion in
            suggestion.text.lowercased().contains(queryLower)
        }
    }
    
    func updateSuggestions(_ newSuggestions: [SearchSuggestion]) {
        // Method to update suggestions when real data is available from backend
        suggestions = newSuggestions
    }
    
    func updateTrendingTopics(_ topics: [TrendingTopic]) {
        // Method to update trending topics when real data is available from backend
        trendingTopics = topics
    }
    
    // MARK: - Filter and Sort Methods
    
    func filteredResults(for type: SearchResultType) -> [SearchResult] {
        return searchResults.filter { $0.type == type }
    }
    
    func sortResults(by option: SearchSortOption) -> [SearchResult] {
        switch option {
        case .relevance:
            return searchResults // Already sorted by relevance
        case .recent:
            return searchResults.sorted { result1, result2 in
                getCreationDate(result1) > getCreationDate(result2)
            }
        case .popular:
            return searchResults.sorted { result1, result2 in
                getPopularityScore(result1) > getPopularityScore(result2)
            }
        case .alphabetical:
            return searchResults.sorted { result1, result2 in
                getDisplayName(result1) < getDisplayName(result2)
            }
        case .activity:
            return searchResults.sorted { result1, result2 in
                getActivityScore(result1) > getActivityScore(result2)
            }
        }
    }
    
    private func getCreationDate(_ result: SearchResult) -> Date {
        switch result.type {
        case .user:
            return result.user?.createdAt ?? Date.distantPast
        case .post:
            return result.post?.createdAt ?? Date.distantPast
        case .trade:
            return result.trade?.entryDate ?? Date.distantPast
        case .group:
            return result.community?.createdAt ?? Date.distantPast
        }
    }
    
    private func getPopularityScore(_ result: SearchResult) -> Double {
        switch result.type {
        case .user:
            return Double(result.user?.followersCount ?? 0)
        case .post:
            return Double(result.post?.likesCount ?? 0)
        case .trade:
            return result.trade?.isOpen == true ? 10 : 0
        case .group:
            return Double(result.community?.memberCount ?? 0)
        }
    }
    
    private func getDisplayName(_ result: SearchResult) -> String {
        switch result.type {
        case .user:
            return result.user?.fullName ?? ""
        case .post:
            return result.post?.content ?? ""
        case .trade:
            return result.trade?.ticker ?? ""
        case .group:
            return result.community?.name ?? ""
        }
    }
    
    private func getActivityScore(_ result: SearchResult) -> Double {
        switch result.type {
        case .user:
            // Activity based on recent posts/trades
            return Double(result.user?.followersCount ?? 0) * 0.1
        case .post:
            // Activity based on recent engagement
            return Double(result.post?.likesCount ?? 0) + Double(result.post?.commentsCount ?? 0)
        case .trade:
            // Activity based on whether trade is open and recent
            let daysSinceEntry = Date().timeIntervalSince(result.trade?.entryDate ?? Date.distantPast) / (24 * 3600)
            let recencyScore = max(0, 30 - daysSinceEntry) // Higher score for more recent trades
            return (result.trade?.isOpen == true ? 20 : 0) + recencyScore
        case .group:
            // Activity based on member count and engagement
            return Double(result.community?.memberCount ?? 0) * 0.1
        }
    }
    
    // MARK: - Utility Methods
    
    func clearResults() {
        searchResults = []
        currentQuery = ""
        searchPerformance = nil
    }
    
    func resultCount(for type: SearchResultType) -> Int {
        return filteredResults(for: type).count
    }
    
    var hasResults: Bool {
        return !searchResults.isEmpty
    }
    
    var isEmpty: Bool {
        return searchResults.isEmpty && !isLoading
    }
    
    func getRecentSearches() -> [String] {
        // Return actual search history from UserDefaults
        return searchHistory
    }
    
    // MARK: - Error Handling
    
    private func handleSearchError(_ error: Error) {
        errorMessage = "Search failed: \(error.localizedDescription)"
        showError = true
        
        // Log error for analytics
        print("Search error: \(error)")
    }
    
    private func recordSearchPerformance(query: String, resultCount: Int, cacheHit: Bool) {
        guard let startTime = searchStartTime else { return }
        
        searchPerformance = SearchPerformance(
            query: query,
            resultCount: resultCount,
            searchTime: Date().timeIntervalSince(startTime),
            cacheHit: cacheHit,
            searchTimestamp: Date()
        )
    }
}

// MARK: - Supporting Enums

enum SearchSortOption: String, CaseIterable {
    case relevance = "relevance"
    case recent = "recent"
    case popular = "popular"
    case alphabetical = "alphabetical"
    case activity = "activity"
    
    var displayName: String {
        switch self {
        case .relevance: return "Relevance"
        case .recent: return "Recent"
        case .popular: return "Popular"
        case .alphabetical: return "A-Z"
        case .activity: return "Activity"
        }
    }
    
    var icon: String {
        switch self {
        case .relevance: return "star.fill"
        case .recent: return "clock.fill"
        case .popular: return "flame.fill"
        case .alphabetical: return "textformat.abc"
        case .activity: return "chart.bar.fill"
        }
    }
    
    var description: String {
        switch self {
        case .relevance: return "Best matches for your search"
        case .recent: return "Most recently created or updated"
        case .popular: return "Most likes, comments, and engagement"
        case .alphabetical: return "Alphabetical order"
        case .activity: return "Most active or frequently updated"
        }
    }
}
