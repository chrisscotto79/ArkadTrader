
import Foundation

@MainActor
class SearchService: ObservableObject {
    static let shared = SearchService()
    
    @Published var searchResults: [SearchResult] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching = false
    
    private init() {
        loadRecentSearches()
    }
    
    func searchUsers(query: String) async throws -> [User] {
        // Return empty array for now
        return []
    }
    
    func searchAll(query: String) async throws -> [SearchResult] {
        // Return empty array for now
        return []
    }
    
    func clearSearchResults() {
        searchResults = []
    }
    
    func clearRecentSearches() {
        recentSearches = []
    }
    
    func getSearchSuggestions(for query: String) -> [String] {
        return []
    }
    
    func getPopularSearches() -> [String] {
        return ["AAPL", "TSLA", "NVDA", "SPY", "QQQ"]
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "recent_searches") ?? []
    }
}
