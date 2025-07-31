// File: Core/Search/ViewModel/SearchViewModel.swift
// FIXED - SearchViewModel with correct property names

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
        setupSearchSuggestions()
        loadTrendingTopics()
    }
    
    // MARK: - Enhanced Search Methods
    
    func search(query: String) async {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 SearchViewModel: Starting search for '\(cleanQuery)'")
        
        guard !cleanQuery.isEmpty else {
            print("⚠️ SearchViewModel: Empty query, clearing results")
            clearResults()
            return
        }
        
        // Check authentication first
        guard authService.currentUser != nil else {
            print("❌ SearchViewModel: User not authenticated")
            await MainActor.run {
                errorMessage = "Please log in to search"
                showError = true
                isLoading = false
            }
            return
        }
        
        currentQuery = cleanQuery
        searchStartTime = Date()
        
        // Check cache first
        if let cachedResult = getCachedResult(for: cleanQuery) {
            print("💾 SearchViewModel: Using cached results")
            await handleCachedResult(cachedResult, query: cleanQuery)
            return
        }
        
        // Perform new search
        await performNewSearch(query: cleanQuery)
        
        // Add to search history only if successful
        if !searchResults.isEmpty {
            addToSearchHistory(cleanQuery)
        }
    }
    func searchUsers(query: String, limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.searchUsers(query: query, limit: limit)
    }

    func searchPosts(query: String, limit: Int = 20) async throws -> [Post] {
        return try await FirebaseServices.shared.searchPosts(query: query, limit: limit)
    }

    func searchTrades(query: String, limit: Int = 20) async throws -> [Trade] {
        return try await FirebaseServices.shared.searchTrades(query: query, limit: limit)
    }

    func searchCommunities(query: String, limit: Int = 20) async throws -> [Community] {
        return try await FirebaseServices.shared.searchCommunities(query: query, limit: limit)
    }
    
    private func performNewSearch(query: String) async {
        await MainActor.run {
            isLoading = true
            searchResults = []
            errorMessage = ""
            showError = false
        }
        
        print("🚀 SearchViewModel: Starting parallel search for '\(query)'")
        
        do {
            // Perform searches with individual error handling
            let userResults = await searchUsersWithErrorHandling(query: query)
            let postResults = await searchPostsWithErrorHandling(query: query)
            let tradeResults = await searchTradesWithErrorHandling(query: query)
            let communityResults = await searchCommunitiesWithErrorHandling(query: query)
            
            // Combine all results
            let allResults = userResults + postResults + tradeResults + communityResults
            print("📊 SearchViewModel: Total results found: \(allResults.count)")
            
            await MainActor.run {
                // Rank and set results
                searchResults = rankSearchResults(allResults, query: query)
                
                // Cache the results
                cacheSearchResults(allResults, query: query)
                
                // Record performance
                recordSearchPerformance(query: query, resultCount: allResults.count, cacheHit: false)
                
                isLoading = false
                
                print("✅ SearchViewModel: Search completed with \(searchResults.count) results")
            }
            
        } catch {
            print("❌ SearchViewModel: Search failed with error: \(error)")
            await MainActor.run {
                handleSearchError(error)
            }
        }
    }
    private func searchUsersWithErrorHandling(query: String) async -> [SearchResult] {
        do {
            print("👥 SearchViewModel: Searching users...")
            let users = try await authService.searchUsers(query: query, limit: 20)
            print("✅ SearchViewModel: Found \(users.count) users")
            return users.map { SearchResult(user: $0) }
        } catch {
            print("❌ SearchViewModel: User search failed: \(error)")
            return []
        }
    }

    private func searchPostsWithErrorHandling(query: String) async -> [SearchResult] {
        do {
            print("📝 SearchViewModel: Searching posts...")
            let posts = try await authService.searchPosts(query: query, limit: 15)
            print("✅ SearchViewModel: Found \(posts.count) posts")
            return posts.map { SearchResult(post: $0) }
        } catch {
            print("❌ SearchViewModel: Posts search failed: \(error)")
            return []
        }
    }

    private func searchTradesWithErrorHandling(query: String) async -> [SearchResult] {
        do {
            print("📈 SearchViewModel: Searching trades...")
            let trades = try await authService.searchTrades(query: query, limit: 10)
            print("✅ SearchViewModel: Found \(trades.count) trades")
            return trades.map { SearchResult(trade: $0) }
        } catch {
            print("❌ SearchViewModel: Trades search failed: \(error)")
            return []
        }
    }

    private func searchCommunitiesWithErrorHandling(query: String) async -> [SearchResult] {
        do {
            print("🏘️ SearchViewModel: Searching communities...")
            let communities = try await authService.searchCommunities(query: query, limit: 10)
            print("✅ SearchViewModel: Found \(communities.count) communities")
            return communities.map { SearchResult(community: $0) }
        } catch {
            print("❌ SearchViewModel: Communities search failed: \(error)")
            return []
        }
    }
    
    // MARK: - Individual Search Methods (FIXED - No limit parameter)
    
    private func searchUsers(query: String) async throws -> [SearchResult] {
        let users = try await authService.searchUsers(query: query)
        return users.map { SearchResult(user: $0) }
    }
    
    private func searchPosts(query: String) async throws -> [SearchResult] {
        let posts = try await authService.searchPosts(query: query)
        return posts.map { SearchResult(post: $0) }
    }
    
    private func searchTrades(query: String) async throws -> [SearchResult] {
        let trades = try await authService.searchTrades(query: query)
        return trades.map { SearchResult(trade: $0) }
    }
    
    private func searchCommunities(query: String) async throws -> [SearchResult] {
        let communities = try await authService.searchCommunities(query: query)
        return communities.map { SearchResult(community: $0) }
    }
    
    // MARK: - Enhanced Result Ranking (FIXED - Using correct property names)
    
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
                } else if user.username.lowercased().hasPrefix(query) {
                    score += 80
                } else if user.username.lowercased().contains(query) {
                    score += 60
                }
                
                // Full name match (if fullName exists)
                if user.fullName.lowercased().contains(query) {
                    score += 50
                }
                
                // Boost for users with good win rates
                if user.winRate > 70 {
                    score += 15
                } else if user.winRate > 50 {
                    score += 10
                }
                
                // Boost for active users
                let daysSinceJoined = Date().timeIntervalSince(user.createdAt) / (24 * 3600)
                if daysSinceJoined < 30 {
                    score += 5
                }
            }
            
        case .post:
            if let post = result.post {
                // Content relevance - word matching
                let contentWords = post.content.lowercased().components(separatedBy: .whitespacesAndNewlines)
                let queryWords = query.components(separatedBy: .whitespacesAndNewlines)
                
                for queryWord in queryWords {
                    if contentWords.contains(queryWord.lowercased()) {
                        score += 20
                    } else if contentWords.contains(where: { $0.contains(queryWord.lowercased()) }) {
                        score += 10
                    }
                }
                
                // Author username match
                if post.authorUsername.lowercased().contains(query) {
                    score += 30
                }
                
                // Boost for popular posts
                score += min(Double(post.likesCount) * 0.5, 20)
                score += min(Double(post.commentsCount) * 0.3, 15)
                
                // Boost for recent posts
                let daysSinceCreation = Date().timeIntervalSince(post.createdAt) / (24 * 3600)
                score += max(0, 10 - daysSinceCreation * 0.5)
            }
            
        case .trade:
            if let trade = result.trade {
                // FIXED: Use 'ticker' instead of 'symbol'
                if trade.ticker.lowercased() == query.lowercased() {
                    score += 100
                } else if trade.ticker.lowercased().contains(query.lowercased()) {
                    score += 80
                }
                
                // Boost for open trades
                if trade.isOpen {
                    score += 20
                }
                
                // Boost for profitable trades
                if !trade.isOpen && trade.profitLossPercentage > 0 {
                    score += min(trade.profitLossPercentage * 0.1, 15)
                }
                
                // Boost for recent trades
                let daysSinceEntry = Date().timeIntervalSince(trade.entryDate) / (24 * 3600)
                score += max(0, 15 - daysSinceEntry * 0.2)
            }
            
        case .group:
            if let community = result.community {
                // Exact name match
                if community.name.lowercased() == query.lowercased() {
                    score += 100
                } else if community.name.lowercased().hasPrefix(query.lowercased()) {
                    score += 80
                } else if community.name.lowercased().contains(query.lowercased()) {
                    score += 60
                }
                
                // Description match
                if community.description.lowercased().contains(query.lowercased()) {
                    score += 40
                }
                
                // Boost for larger communities
                score += min(Double(community.memberCount) * 0.05, 25)
                
                // Boost for public communities
                if !community.isPrivate {
                    score += 10
                }
                
                // Boost for active communities
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
    
    // MARK: - Caching System
    
    private func getCachedResult(for query: String) -> CachedSearchResult? {
        let normalizedQuery = query.lowercased()
        cleanExpiredCache()
        
        guard let cached = searchCache[normalizedQuery], !cached.isExpired else {
            return nil
        }
        
        return cached
    }
    
    private func cacheSearchResults(_ results: [SearchResult], query: String) {
        let normalizedQuery = query.lowercased()
        cleanExpiredCache()
        
        if searchCache.count >= maxCacheSize {
            let oldestKey = searchCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key
            if let key = oldestKey {
                searchCache.removeValue(forKey: key)
            }
        }
        
        let performance = SearchPerformance(
            query: query,
            resultCount: results.count,
            searchTime: searchStartTime.map { Date().timeIntervalSince($0) } ?? 0,
            cacheHit: false,
            searchTimestamp: Date()
        )
        
        searchCache[normalizedQuery] = CachedSearchResult(
            results: results,
            timestamp: Date(),
            performance: performance
        )
    }
    
    private func handleCachedResult(_ cached: CachedSearchResult, query: String) async {
        searchResults = cached.results
        
        let cacheHitPerformance = SearchPerformance(
            query: query,
            resultCount: cached.results.count,
            searchTime: 0.001,
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
        searchHistory.removeAll { $0.lowercased() == query.lowercased() }
        searchHistory.insert(query, at: 0)
        
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        
        saveSearchHistory()
    }
    
    private func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: "arkad_search_history"),
           let history = try? JSONDecoder().decode([String].self, from: data) {
            searchHistory = history
        }
    }
    
    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "arkad_search_history")
        }
    }
    
    func clearSearchHistory() {
        searchHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "arkad_search_history")
    }
    
    // MARK: - Search Suggestions and Trending Topics
    
    private func setupSearchSuggestions() {
        suggestions = []
    }
    
    private func loadTrendingTopics() {
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
        suggestions = newSuggestions
    }
    
    func updateTrendingTopics(_ topics: [TrendingTopic]) {
        trendingTopics = topics
    }
    
    // MARK: - Filter and Sort Methods
    
    func filteredResults(for type: SearchResultType) -> [SearchResult] {
        return searchResults.filter { $0.type == type }
    }
    
    func resultCount(for type: SearchResultType) -> Int {
        return filteredResults(for: type).count
    }
    
    func sortResults(by option: SearchSortOption) -> [SearchResult] {
        switch option {
        case .relevance:
            return searchResults
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
                getDisplayName(result1).lowercased() < getDisplayName(result2).lowercased()
            }
        case .activity:
            return searchResults.sorted { result1, result2 in
                getActivityScore(result1) > getActivityScore(result2)
            }
        }
    }
    
    // MARK: - Helper Methods (FIXED - Using correct property names)
    
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
            return (result.user?.winRate ?? 0) * 10
        case .post:
            return Double(result.post?.likesCount ?? 0) + Double(result.post?.commentsCount ?? 0) * 2
        case .trade:
            if let trade = result.trade {
                if trade.isOpen {
                    return 100
                } else {
                    return max(0, trade.profitLossPercentage) * 10
                }
            }
            return 0
        case .group:
            return Double(result.community?.memberCount ?? 0)
        }
    }
    
    private func getDisplayName(_ result: SearchResult) -> String {
        switch result.type {
        case .user:
            // FIXED: Use fullName or username as fallback
            return result.user?.fullName ?? result.user?.username ?? ""
        case .post:
            return result.post?.content.prefix(50).description ?? ""
        case .trade:
            // FIXED: Use 'ticker' instead of 'symbol'
            return result.trade?.ticker ?? ""
        case .group:
            return result.community?.name ?? ""
        }
    }
    
    private func getActivityScore(_ result: SearchResult) -> Double {
        switch result.type {
        case .user:
            let daysSinceJoined = Date().timeIntervalSince(result.user?.createdAt ?? Date.distantPast) / (24 * 3600)
            let recencyBonus = max(0, 365 - daysSinceJoined) / 365 * 20
            return recencyBonus + (result.user?.winRate ?? 0) * 0.5
            
        case .post:
            let daysSinceCreated = Date().timeIntervalSince(result.post?.createdAt ?? Date.distantPast) / (24 * 3600)
            let recencyBonus = max(0, 30 - daysSinceCreated) * 2
            let engagementScore = Double(result.post?.likesCount ?? 0) + Double(result.post?.commentsCount ?? 0) * 1.5
            return recencyBonus + engagementScore
            
        case .trade:
            let daysSinceEntry = Date().timeIntervalSince(result.trade?.entryDate ?? Date.distantPast) / (24 * 3600)
            let recencyScore = max(0, 90 - daysSinceEntry) / 90 * 50
            let openBonus = result.trade?.isOpen == true ? 30 : 0
            return recencyScore + Double(openBonus)
            
        case .group:
            let daysSinceCreated = Date().timeIntervalSince(result.community?.createdAt ?? Date.distantPast) / (24 * 3600)
            let ageBonus = max(0, 180 - daysSinceCreated) / 180 * 10
            let memberScore = Double(result.community?.memberCount ?? 0) * 0.1
            return ageBonus + memberScore
        }
    }
    
    // MARK: - Utility Methods
    
    func clearResults() {
        print("🧹 SearchViewModel: Clearing search results")
        searchResults = []
        currentQuery = ""
        searchPerformance = nil
        errorMessage = ""
        showError = false
    }
    
    var hasResults: Bool {
        return !searchResults.isEmpty
    }
    
    var isEmpty: Bool {
        return searchResults.isEmpty && !isLoading && currentQuery.isEmpty
    }
    
    var hasSearched: Bool {
        return !currentQuery.isEmpty
    }
    
    func getSearchSummary() -> String {
        let count = searchResults.count
        if count == 0 {
            return "No results"
        } else if count == 1 {
            return "1 result"
        } else {
            return "\(count) results"
        }
    }
    
    // MARK: - Error Handling
    
    private func handleSearchError(_ error: Error) {
        let friendlyMessage = getFriendlyErrorMessage(error)
        errorMessage = friendlyMessage
        showError = true
        isLoading = false
        
        // Detailed logging for debugging
        print("❌ SearchViewModel - Detailed error info:")
        print("   Error type: \(type(of: error))")
        print("   Error description: \(error.localizedDescription)")
        
        if let searchError = error as? SearchError {
            print("   Search error type: \(searchError)")
        }
        
        // Log to console for debugging
        print("❌ SearchViewModel - Search error: \(error.localizedDescription)")
    }
    
    private func getFriendlyErrorMessage(_ error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()
        
        print("🔍 SearchViewModel: Analyzing error: \(errorDescription)")
        
        if errorDescription.contains("network") || errorDescription.contains("internet") {
            return "Check your internet connection and try again"
        } else if errorDescription.contains("permission") || errorDescription.contains("unauthorized") {
            return "You don't have permission to search. Please log in again"
        } else if errorDescription.contains("timeout") {
            return "Search is taking too long. Please try again"
        } else if errorDescription.contains("index") {
            return "Search is temporarily unavailable. Please try again later"
        } else if errorDescription.contains("quota") || errorDescription.contains("limit") {
            return "Search limit reached. Please try again in a few minutes"
        } else {
            return "Search failed. Please check your connection and try again"
        }
    }
    func debugSearchState() {
        print("🔍 SearchViewModel Debug State:")
        print("   Current query: '\(currentQuery)'")
        print("   Is loading: \(isLoading)")
        print("   Has error: \(showError)")
        print("   Error message: '\(errorMessage)'")
        print("   Results count: \(searchResults.count)")
        print("   Auth user: \(authService.currentUser?.username ?? "none")")
        print("   Cache size: \(searchCache.count)")
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
