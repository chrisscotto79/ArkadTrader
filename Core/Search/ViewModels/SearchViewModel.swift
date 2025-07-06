
// File: Core/Search/ViewModels/SearchViewModel.swift
// Updated SearchViewModel for Firebase

import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [SearchResult] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = FirebaseAuthService.shared
    private let firestoreService = FirestoreService.shared
    
    init() {
        loadRecentSearches()
    }
    
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        Task {
            do {
                // For now, create mock search results
                let results = createMockSearchResults()
                
                await MainActor.run {
                    self.searchResults = results
                    self.addToRecentSearches(self.searchText)
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Search failed: \(error.localizedDescription)"
                    self.showError = true
                    self.isSearching = false
                }
            }
        }
    }
    
    func clearSearchResults() {
        searchResults = []
    }
    
    func clearRecentSearches() {
        recentSearches = []
        saveRecentSearches()
    }
    
    func getSearchSuggestions(for query: String) -> [String] {
        let suggestions = ["AAPL", "TSLA", "NVDA", "SPY", "QQQ", "AMZN", "GOOGL", "MSFT"]
        return suggestions.filter { $0.localizedCaseInsensitiveContains(query) }
    }
    
    func getPopularSearches() -> [String] {
        return ["AAPL", "TSLA", "NVDA", "SPY", "QQQ"]
    }
    
    private func addToRecentSearches(_ search: String) {
        let trimmedSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return }
        
        // Remove if already exists
        recentSearches.removeAll { $0.lowercased() == trimmedSearch.lowercased() }
        
        // Add to beginning
        recentSearches.insert(trimmedSearch, at: 0)
        
        // Keep only last 10
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        saveRecentSearches()
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "recent_searches") ?? []
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "recent_searches")
    }
    
    private func createMockSearchResults() -> [SearchResult] {
        let mockUsers = [
            User(email: "john@example.com", username: "johndoe", fullName: "John Doe"),
            User(email: "jane@example.com", username: "janetrader", fullName: "Jane Smith"),
            User(email: "mike@example.com", username: "mikeinvests", fullName: "Mike Johnson")
        ]
        
        return mockUsers.filter { user in
            user.username.localizedCaseInsensitiveContains(searchText) ||
            user.fullName.localizedCaseInsensitiveContains(searchText)
        }.map { SearchResult(user: $0) }
    }
}

struct SearchResult: Identifiable {
    let id: UUID = UUID()
    let type: SearchResultType
    let user: User?
    let ticker: String?
    
    init(user: User) {
        self.type = .user
        self.user = user
        self.ticker = nil
    }
    
    init(ticker: String) {
        self.type = .ticker
        self.user = nil
        self.ticker = ticker
    }
}

enum SearchResultType {
    case user
    case ticker
    case post
    
    var displayName: String {
        switch self {
        case .user: return "User"
        case .ticker: return "Ticker"
        case .post: return "Post"
        }
    }
}
