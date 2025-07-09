// File: Core/Search/ViewModel/SearchViewModel.swift
// Clean Search ViewModel without model redefinitions

import Foundation
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = FirebaseAuthService.shared
    
    // MARK: - Search Methods
    
    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        searchResults = []
        
        do {
            // Search users
            let users = try await authService.searchUsers(query: query)
            let userResults = users.map { SearchResult(user: $0) }
            
            // Search posts
            let posts = try await authService.searchPosts(query: query)
            let postResults = posts.map { SearchResult(post: $0) }
            
            // Search trades - using mock data for now
            let trades = try await searchTrades(query: query)
            let tradeResults = trades.map { SearchResult(trade: $0) }
            
            // Search communities
            let communities = try await authService.searchCommunities(query: query)
            let communityResults = communities.map { SearchResult(community: $0) }
            
            // Combine all results
            searchResults = userResults + postResults + tradeResults + communityResults
            
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    private func searchTrades(query: String) async throws -> [Trade] {
        // For now, return mock trades that match the query
        // In a real implementation, this would call authService.searchTrades(query: query)
        
        let mockTrades = [
            Trade(ticker: "AAPL", tradeType: .stock, entryPrice: 150.0, quantity: 100, userId: "mock1"),
            Trade(ticker: "TSLA", tradeType: .stock, entryPrice: 200.0, quantity: 50, userId: "mock2"),
            Trade(ticker: "MSFT", tradeType: .stock, entryPrice: 300.0, quantity: 75, userId: "mock3"),
            Trade(ticker: "GOOGL", tradeType: .stock, entryPrice: 2500.0, quantity: 10, userId: "mock4")
        ]
        
        return mockTrades.filter { trade in
            trade.ticker.lowercased().contains(query.lowercased())
        }
    }
    
    // MARK: - Filter Methods
    
    func filteredResults(for type: SearchResultType) -> [SearchResult] {
        return searchResults.filter { $0.type == type }
    }
    
    func clearResults() {
        searchResults = []
    }
    
    // MARK: - Helper Methods
    
    func resultCount(for type: SearchResultType) -> Int {
        return filteredResults(for: type).count
    }
    
    var hasResults: Bool {
        return !searchResults.isEmpty
    }
    
    var isEmpty: Bool {
        return searchResults.isEmpty && !isLoading
    }
    
    // MARK: - Search History
    
    func addToRecentSearches(_ query: String) {
        // This would typically save to UserDefaults or Core Data
        // For now, just a placeholder method
    }
    
    func getRecentSearches() -> [String] {
        // This would typically load from UserDefaults or Core Data
        // For now, return mock recent searches
        return ["AAPL", "Tesla", "Bitcoin", "Apple earnings"]
    }
}
