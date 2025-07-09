// File: Core/Search/Views/SearchView.swift
// Fixed Search View - addresses compilation errors

import SwiftUI

struct SearchView: View {
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var selectedSearchType: SearchType = .all
    @State private var recentSearches: [String] = []
    @State private var isSearching = false
    @State private var showFilters = false
    @State private var selectedFilters: Set<SearchFilter> = []
    @State private var searchWorkItem: DispatchWorkItem?
    
    @FocusState private var isSearchFieldFocused: Bool
    
    enum SearchType: CaseIterable {
        case all, users, posts, stocks, news
        
        var title: String {
            switch self {
            case .all: return "All"
            case .users: return "Users"
            case .posts: return "Posts"
            case .stocks: return "Stocks"
            case .news: return "News"
            }
        }
        
        var icon: String {
            switch self {
            case .all: return "magnifyingglass"
            case .users: return "person.2"
            case .posts: return "text.bubble"
            case .stocks: return "chart.line.uptrend.xyaxis"
            case .news: return "newspaper"
            }
        }
    }
    
    enum SearchFilter: CaseIterable {
        case verified, recent, trending, followed
        
        var title: String {
            switch self {
            case .verified: return "Verified"
            case .recent: return "Recent"
            case .trending: return "Trending"
            case .followed: return "Following"
            }
        }
        
        var icon: String {
            switch self {
            case .verified: return "checkmark.seal.fill"
            case .recent: return "clock"
            case .trending: return "flame"
            case .followed: return "person.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Enhanced Search Bar
                    enhancedSearchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    // Search Type Selector
                    searchTypeSelector
                        .padding(.top, 16)
                    
                    // Filters (when enabled)
                    if showFilters {
                        filtersSection
                            .padding(.top, 16)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                    }
                    
                    // Search Results or Empty State
                    searchContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilters.toggle() }) {
                        Image(systemName: showFilters ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                            .foregroundColor(.arkadGold)
                    }
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
        .onAppear {
            loadRecentSearches()
        }
        .animation(.easeInOut(duration: 0.3), value: showFilters)
    }
    
    // MARK: - Enhanced Search Bar
    private var enhancedSearchBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Search Icon
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isSearchFieldFocused ? .arkadGold : .gray)
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.2), value: isSearchFieldFocused)
                
                // Search Text Field
                TextField("Search users, posts, stocks...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { _, newValue in
                        if !newValue.isEmpty {
                            debounceSearch()
                        } else {
                            clearSearch()
                        }
                    }
                
                // Loading Indicator
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .arkadGold))
                }
                
                // Clear Button
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSearchFieldFocused ? Color.arkadGold : Color.gray.opacity(0.3), lineWidth: isSearchFieldFocused ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            
            // Search Suggestions (when focused and text is not empty)
            if isSearchFieldFocused && !searchText.isEmpty && searchText.count >= 2 {
                searchSuggestions
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSearchFieldFocused)
    }
    
    // MARK: - Search Type Selector
    private var searchTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    SearchTypeButton(
                        type: type,
                        isSelected: selectedSearchType == type
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedSearchType = type
                            if !searchText.isEmpty {
                                performSearch()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Filters Section
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filters")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                if !selectedFilters.isEmpty {
                    Button("Clear") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilters.removeAll()
                        }
                        if !searchText.isEmpty {
                            performSearch()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.arkadGold)
                }
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            filter: filter,
                            isSelected: selectedFilters.contains(filter)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if selectedFilters.contains(filter) {
                                    selectedFilters.remove(filter)
                                } else {
                                    selectedFilters.insert(filter)
                                }
                            }
                            
                            if !searchText.isEmpty {
                                performSearch()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Search Content
    @ViewBuilder
    private var searchContent: some View {
        if searchText.isEmpty {
            emptySearchState
        } else if searchViewModel.searchResults.isEmpty && !isSearching {
            noResultsState
        } else {
            searchResults
        }
    }
    
    // MARK: - Empty Search State
    private var emptySearchState: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Welcome Section
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.arkadGold.opacity(0.7))
                    
                    VStack(spacing: 8) {
                        Text("Discover ArkadTrader")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("Search for traders, posts, market insights, and more")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                
                // Quick Search Categories
                quickSearchCategories
                
                // Recent Searches
                if !recentSearches.isEmpty {
                    recentSearchesSection
                }
                
                // Trending Topics (placeholder)
                trendingTopicsSection
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 32)
        }
    }
    
    // MARK: - No Results State
    private var noResultsState: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text("Try adjusting your search terms or filters")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Search suggestions
            VStack(alignment: .leading, spacing: 12) {
                Text("Try searching for:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(getSearchSuggestions(), id: \.self) { suggestion in
                        Button(action: {
                            searchText = suggestion
                            performSearch()
                        }) {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.arkadGold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.arkadGold.opacity(0.1))
                                .cornerRadius(16)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }
    

    // MARK: - Search Results Section
    private var searchResultsSection: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if searchType == .all {
                    // Show grouped results
                    ForEach(SearchResultType.allCases, id: \.self) { type in
                        let filteredResults = searchViewModel.filteredResults(for: type)
                        if !filteredResults.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                // Section header
                                HStack {
                                    Image(systemName: type.icon)
                                        .foregroundColor(type.color)
                                    Text(type.displayName + "s")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("(\(filteredResults.count))")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                
                                // Results
                                ForEach(filteredResults.prefix(3)) { result in
                                    SearchResultView(result: result)
                                        .padding(.horizontal, 16)
                                }
                                
                                // Show more button if needed
                                if filteredResults.count > 3 {
                                    Button(action: {
                                        // Switch to specific tab
                                        withAnimation {
                                            searchType = SearchType(from: type)
                                        }
                                    }) {
                                        Text("Show all \(filteredResults.count) \(type.displayName.lowercased())s")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Show filtered results
                    let results = filteredSearchResults
                    ForEach(results) { result in
                        SearchResultView(result: result)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    // Helper extension to convert SearchResultType to SearchType
    extension SearchView.SearchType {
        init(from resultType: SearchResultType) {
            switch resultType {
            case .user:
                self = .users
            case .post:
                self = .posts
            case .trade:
                self = .stocks
            case .group:
                self = .stocks // or add a .groups case to SearchType
            }
        }
    }

    
    // MARK: - Search Suggestions
    private var searchSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(generateSearchSuggestions(), id: \.self) { suggestion in
                Button(action: {
                    searchText = suggestion
                    performSearch()
                    hideKeyboard()
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.caption)
                        
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left")
                            .foregroundColor(.gray)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                if suggestion != generateSearchSuggestions().last {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Quick Search Categories
    private var quickSearchCategories: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Search")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickSearchCard(
                    title: "Top Traders",
                    subtitle: "Follow successful traders",
                    icon: "person.2.fill",
                    color: .arkadGold
                ) {
                    selectedSearchType = .users
                    searchText = "top traders"
                    performSearch()
                }
                
                QuickSearchCard(
                    title: "Market News",
                    subtitle: "Latest market insights",
                    icon: "newspaper.fill",
                    color: .info
                ) {
                    selectedSearchType = .news
                    searchText = "market news"
                    performSearch()
                }
                
                QuickSearchCard(
                    title: "Popular Stocks",
                    subtitle: "Trending securities",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .success
                ) {
                    selectedSearchType = .stocks
                    searchText = "popular stocks"
                    performSearch()
                }
                
                QuickSearchCard(
                    title: "Trading Ideas",
                    subtitle: "Community insights",
                    icon: "lightbulb.fill",
                    color: .warning
                ) {
                    selectedSearchType = .posts
                    searchText = "trading ideas"
                    performSearch()
                }
            }
        }
    }
    
    // MARK: - Recent Searches Section
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Searches")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button("Clear All") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        recentSearches.removeAll()
                        saveRecentSearches()
                    }
                }
                .font(.caption)
                .foregroundColor(.arkadGold)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(recentSearches.prefix(6), id: \.self) { search in
                    Button(action: {
                        searchText = search
                        performSearch()
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(search)
                                .font(.caption)
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                    }
                }
            }
        }
    }
    
    // MARK: - Trending Topics Section
    private var trendingTopicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                
                Text("Trending")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                ForEach(getTrendingTopics(), id: \.title) { topic in
                    TrendingTopicCard(topic: topic) {
                        searchText = topic.title
                        performSearch()
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var filteredSearchResults: [SearchResult] {
        let results: [SearchResult]
        
        switch searchType {
        case .all:
            results = searchViewModel.searchResults
        case .users:
            results = searchViewModel.filteredResults(for: .user)
        case .posts:
            results = searchViewModel.filteredResults(for: .post)
        case .stocks:
            results = searchViewModel.filteredResults(for: .trade)
        case .news:
            results = [] // No news search implemented yet
        }
        
        // Apply filters
        if activeFilters.contains(.verified) {
            // Filter verified users
            return results.filter { result in
                if case .user = result.type {
                    return result.user?.isVerified == true
                }
                return true
            }
        }
        
        return results
    }
    // MARK: - Helper Methods
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        searchViewModel.searchText = searchText
        
        Task {
            await searchViewModel.performSearch()
            await MainActor.run {
                isSearching = false
                addToRecentSearches(searchText)
            }
        }
    }
    
    private func debounceSearch() {
        // Cancel previous work item
        searchWorkItem?.cancel()
        
        // Create new work item
        let workItem = DispatchWorkItem {
            Task { @MainActor in
                performSearch()
            }
        }
        
        // Store and execute after delay
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    private func clearSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            searchText = ""
            searchViewModel.searchResults = []
            isSearching = false
        }
        searchWorkItem?.cancel()
    }
    
    private func hideKeyboard() {
        isSearchFieldFocused = false
    }
    
    private func addToRecentSearches(_ search: String) {
        let trimmedSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty, !recentSearches.contains(trimmedSearch) else { return }
        
        recentSearches.insert(trimmedSearch, at: 0)
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        saveRecentSearches()
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "recent_searches")
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "recent_searches") ?? []
    }
    
    private func generateSearchSuggestions() -> [String] {
        let searchLower = searchText.lowercased()
        let suggestions = [
            "AAPL", "TSLA", "MSFT", "GOOGL", "AMZN",
            "trading strategies", "market analysis", "day trading",
            "portfolio management", "risk assessment"
        ]
        
        return suggestions.filter { $0.lowercased().contains(searchLower) }
    }
    
    private func getSearchSuggestions() -> [String] {
        return ["AAPL", "TSLA", "Bitcoin", "Trading tips"]
    }
    
    private func getTrendingTopics() -> [TrendingTopic] {
        return [
            TrendingTopic(title: "#TechStocks", subtitle: "Technology sector discussion", count: "12.5K posts"),
            TrendingTopic(title: "#CryptoTrading", subtitle: "Cryptocurrency insights", count: "8.2K posts"),
            TrendingTopic(title: "#MarketAnalysis", subtitle: "Technical analysis", count: "15.1K posts")
        ]
    }
}

// MARK: - Supporting Views

struct SearchTypeButton: View {
    let type: SearchView.SearchType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption)
                
                Text(type.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.arkadGold : Color.gray.opacity(0.1))
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
    }
}

struct FilterChip: View {
    let filter: SearchView.SearchFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption2)
                
                Text(filter.title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .arkadGold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.arkadGold : Color.arkadGold.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(Color.arkadGold, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

struct QuickSearchCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

struct SearchResultCard: View {
    let result: SearchResult
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Result icon/avatar
                ZStack {
                    Circle()
                        .fill(Color.arkadGold.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: iconForResultType(result.type))
                        .foregroundColor(.arkadGold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.user?.username ?? String(result.post?.content.prefix(30) ?? "Result"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text(result.type.displayName)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    private func iconForResultType(_ type: SearchResultType) -> String {
        switch type {
        case .user: return "person.fill"
        case .post: return "text.bubble.fill"
        }
    }
}

struct TrendingTopicCard: View {
    let topic: TrendingTopic
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text(topic.subtitle)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Text(topic.count)
                        .font(.caption2)
                        .foregroundColor(.arkadGold)
                }
                
                Spacer()
                
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

struct SearchResultView: View {
    let result: SearchResult
    @State private var showDetail = false
    
    var body: some View {
        Button(action: { showDetail = true }) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(result.type.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: result.type.icon)
                        .font(.title3)
                        .foregroundColor(result.type.color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryText)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(secondaryText)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetail) {
            NavigationView {
                destinationView
                    .navigationBarItems(trailing: Button("Done") { showDetail = false })
            }
        }
    }
    
    private var primaryText: String {
        switch result.type {
        case .user:
            return result.user?.fullName ?? "Unknown User"
        case .post:
            return String(result.post?.content.prefix(50) ?? "Post")
        case .trade:
            return result.trade?.ticker ?? "Trade"
        case .group:
            return result.community?.name ?? "Group"
        }
    }
    
    private var secondaryText: String {
        switch result.type {
        case .user:
            return "@\(result.user?.username ?? "username")"
        case .post:
            return "by @\(result.post?.authorUsername ?? "unknown")"
        case .trade:
            let trade = result.trade
            return trade?.isOpen ?? true ? "Open Position" : "Closed Position"
        case .group:
            return "\(result.community?.memberCount ?? 0) members"
        }
    }
    
    @ViewBuilder
    private var destinationView: some View {
        switch result.type {
        case .user:
            if let user = result.user {
                UserProfileDetailView(user: user)
            }
        case .post:
            if let post = result.post {
                Text("Post: \(post.content)")
                    .padding()
            }
        case .trade:
            if let trade = result.trade {
                Text("Trade: \(trade.ticker)")
                    .padding()
            }
        case .group:
            if let community = result.community {
                Text("Community: \(community.name)")
                    .padding()
            }
        }
    }
}

// Simple User Profile View for search results
struct UserProfileDetailView: View {
    let user: User
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isFollowing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(user.fullName.prefix(1).uppercased())
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                        )
                    
                    Text(user.fullName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Stats
                HStack(spacing: 40) {
                    VStack {
                        Text("\(user.followersCount)")
                            .font(.headline)
                        Text("Followers")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text("\(user.followingCount)")
                            .font(.headline)
                        Text("Following")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text("\(user.postsCount)")
                            .font(.headline)
                        Text("Posts")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Follow Button
                if user.id != authService.currentUser?.id {
                    Button(action: toggleFollow) {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFollowing ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkFollowStatus()
        }
    }
    
    private func checkFollowStatus() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        Task {
            do {
                let following = try await authService.getUserFollowing(userId: currentUserId)
                isFollowing = following.contains(user.id)
            } catch {
                print("Error checking follow status: \(error)")
            }
        }
    }
    
    private func toggleFollow() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        Task {
            do {
                if isFollowing {
                    try await authService.unfollowUser(userId: user.id, followerId: currentUserId)
                } else {
                    try await authService.followUser(userId: user.id, followerId: currentUserId)
                }
                isFollowing.toggle()
            } catch {
                print("Error toggling follow: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types
struct TrendingTopic {
    let title: String
    let subtitle: String
    let count: String
}

#Preview {
    SearchView()
}
