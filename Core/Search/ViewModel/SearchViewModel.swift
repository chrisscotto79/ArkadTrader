//
//  SearchViewModel.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/6/25.
//


// File: Core/Search/ViewModels/SearchViewModel.swift
// Simplified Search ViewModel

import Foundation

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // For now, just clear results after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.searchResults = []
            self.isSearching = false
        }
    }
}