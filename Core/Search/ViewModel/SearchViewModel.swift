// File: Core/Search/ViewModels/SearchViewModel.swift
// Fixed Search ViewModel - removes mock data, uses Firebase

import Foundation
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = FirebaseAuthService.shared
    
    func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        do {
            // Search users from Firebase
            let users = try await authService.searchUsers(query: searchText)
            let userResults = users.map { user in
                SearchResult(user: user)
            }
            
            // Search posts from Firebase
            let posts = try await authService.searchPosts(query: searchText)
            let postResults = posts.map { post in
                SearchResult(post: post)
            }
            
            // Combine results
            searchResults = userResults + postResults
            
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            showError = true
            searchResults = []
        }
        
        isSearching = false
    }
    
    func clearResults() {
        searchResults = []
        searchText = ""
        isSearching = false
    }
}
