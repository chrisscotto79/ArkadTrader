// File: Core/Search/Views/SearchView.swift
// Clean, working Search View

import SwiftUI

struct SearchView: View {
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var selectedSearchType: SearchType = .all
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Search Type Picker
                searchTypePicker
                
                // Content
                searchContent
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Search Error", isPresented: $searchViewModel.showError) {
            Button("OK") { }
        } message: {
            Text(searchViewModel.errorMessage)
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search traders, posts, stocks...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    performSearch()
                }
                .onChange(of: searchText) { newValue in
                    // Cancel previous search task
                    searchTask?.cancel()
                    
                    // Start new debounced search
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        if !Task.isCancelled && !newValue.isEmpty {
                            await performSearchAsync()
                        }
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Search Type Picker
    
    private var searchTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedSearchType = type
                        if !searchText.isEmpty {
                            performSearch()
                        }
                    }) {
                        Text(type.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedSearchType == type ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedSearchType == type ? Color.blue : Color.gray.opacity(0.2))
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Search Content
    
    @ViewBuilder
    private var searchContent: some View {
        if searchText.isEmpty {
            emptySearchState
        } else if searchViewModel.isLoading {
            loadingState
        } else if searchViewModel.searchResults.isEmpty {
            noResultsState
        } else {
            searchResults
        }
    }
    
    // MARK: - Empty Search State
    
    private var emptySearchState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("Search ArkadTrader")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Find traders, posts, stocks, and communities")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            // Quick Search Suggestions
            VStack(alignment: .leading, spacing: 12) {
                Text("Popular Searches")
                    .font(.headline)
                    .padding(.horizontal)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(getPopularSearches(), id: \.self) { suggestion in
                        Button(action: {
                            searchText = suggestion
                            performSearch()
                        }) {
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Results State
    
    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No results for \"\(searchText)\"")
                .font(.headline)
            
            Text("Try searching for something else")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Search Results
    
    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredResults) { result in
                    SearchResultView(result: result)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredResults: [SearchResult] {
        switch selectedSearchType {
        case .all:
            return searchViewModel.searchResults
        case .users:
            return searchViewModel.searchResults.filter { $0.type == .user }
        case .posts:
            return searchViewModel.searchResults.filter { $0.type == .post }
        case .stocks:
            return searchViewModel.searchResults.filter { $0.type == .trade }
        case .groups:
            return searchViewModel.searchResults.filter { $0.type == .group }
        }
    }
    
    // MARK: - Helper Methods
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            await performSearchAsync()
        }
    }
    
    private func performSearchAsync() async {
        await searchViewModel.search(query: searchText)
    }
    
    private func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        searchViewModel.clearResults()
    }
    
    private func getPopularSearches() -> [String] {
        return ["AAPL", "TSLA", "Bitcoin", "Trading Tips", "Market Analysis", "Options", "Crypto", "Stocks"]
    }
}

#Preview {
    SearchView()
        .environmentObject(FirebaseAuthService.shared)
}
