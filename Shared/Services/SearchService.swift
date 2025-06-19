// File: Shared/Services/SearchService.swift
// Updated to remove duplicate SearchResult definitions

import Foundation

@MainActor
class SearchService: ObservableObject {
    static let shared = SearchService()
    private let networkService = NetworkService.shared
    
    @Published var searchResults: [SearchResult] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching = false
    
    private init() {
        loadRecentSearches()
    }
    
    // MARK: - Search Methods
    func searchUsers(query: String) async throws -> [User] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        isSearching = true
        
        do {
            let response = try await networkService.searchUsers(query: query)
            
            // Add to recent searches
            addToRecentSearches(query)
            
            isSearching = false
            return response.users
        } catch {
            isSearching = false
            print("User search failed: \(error)")
            // Return mock data for development
            addToRecentSearches(query)
            return getMockUsers(for: query)
        }
    }
    
    func searchAll(query: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return []
        }
        
        isSearching = true
        
        do {
            // Search users
            let userResponse = try await networkService.searchUsers(query: query)
            let userResults = userResponse.users.map { SearchResult(user: $0) }
            
            // In a real implementation, you'd also search posts, trades, etc.
            // For now, just return user results
            searchResults = userResults
            
            // Add to recent searches
            addToRecentSearches(query)
            
            isSearching = false
            return searchResults
        } catch {
            isSearching = false
            print("Search failed: \(error)")
            
            // Return mock data for development
            addToRecentSearches(query)
            let mockUsers = getMockUsers(for: query)
            let mockResults = mockUsers.map { SearchResult(user: $0) }
            searchResults = mockResults
            return searchResults
        }
    }
    
    func clearSearchResults() {
        searchResults = []
    }
    
    // MARK: - Recent Searches
    private func addToRecentSearches(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove if already exists
        recentSearches.removeAll { $0.lowercased() == trimmedQuery.lowercased() }
        
        // Add to beginning
        recentSearches.insert(trimmedQuery, at: 0)
        
        // Keep only last 10 searches
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        saveRecentSearches()
    }
    
    func clearRecentSearches() {
        recentSearches = []
        saveRecentSearches()
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "recent_searches")
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "recent_searches") ?? []
    }
    
    // MARK: - Search Suggestions
    func getSearchSuggestions(for query: String) -> [String] {
        let lowercaseQuery = query.lowercased()
        return recentSearches.filter { $0.lowercased().contains(lowercaseQuery) }
    }
    
    // MARK: - Popular Searches
    func getPopularSearches() -> [String] {
        // In a real implementation, this would come from the server
        return [
            "AAPL", "TSLA", "NVDA", "SPY", "QQQ",
            "day trading", "swing trading", "options",
            "crypto", "earnings"
        ]
    }
    
    // MARK: - Mock Data for Development
    private func getMockUsers(for query: String) -> [User] {
        let mockUsers = [
            User(email: "john@example.com", username: "johntrader", fullName: "John Trader"),
            User(email: "jane@example.com", username: "janesmith", fullName: "Jane Smith"),
            User(email: "mike@example.com", username: "mikeinvest", fullName: "Mike Investment"),
            User(email: "sarah@example.com", username: "sarahstocks", fullName: "Sarah Stocks"),
            User(email: "alex@example.com", username: "alexcrypto", fullName: "Alex Crypto")
        ]
        
        // Filter based on query
        let lowercaseQuery = query.lowercased()
        return mockUsers.filter { user in
            user.fullName.lowercased().contains(lowercaseQuery) ||
            user.username.lowercased().contains(lowercaseQuery)
        }
    }
}
