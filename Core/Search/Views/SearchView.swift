// File: Core/Search/Views/SearchView.swift
// Clean Search View matching original design with arkad gold colors

import SwiftUI

struct SearchView: View {
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var selectedSearchType: SearchType = .all
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool
    
    // Sheet states for future features
    @State private var showAdvancedFilters = false
    @State private var showSearchSettings = false
    @State private var showSearchAnalytics = false
    @State private var pressedTab: SearchType?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Clean Header
                headerSection
                
                // Main Content
                Group {
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
                .animation(.easeInOut(duration: 0.3), value: searchText.isEmpty)
                .animation(.easeInOut(duration: 0.3), value: searchViewModel.isLoading)
                .animation(.easeInOut(duration: 0.3), value: searchViewModel.searchResults.isEmpty)
                
                Spacer()
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showAdvancedFilters) {
            Text("Advanced Filters Coming Soon")
                .padding()
        }
        .sheet(isPresented: $showSearchSettings) {
            Text("Search Settings Coming Soon")
                .padding()
        }
        .sheet(isPresented: $showSearchAnalytics) {
            Text("Search Analytics Coming Soon")
                .padding()
        }
        .alert("Search Error", isPresented: $searchViewModel.showError) {
            Button("OK") { }
        } message: {
            Text(searchViewModel.errorMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            // Simple Search Bar
            simpleSearchBar
            
            // Enhanced Filter Tabs
            cleanFilterTabs
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color.white, Color.gray.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var simpleSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isSearchFocused ? .arkadGold : .gray)
                .font(.system(size: 18, weight: .medium))
                .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
            
            TextField("Search traders, posts, stocks...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
                .focused($isSearchFocused)
                .onSubmit {
                    performSearch()
                }
                .onChange(of: searchText) { newValue in
                    handleSearchTextChange(newValue)
                }
            
            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.arkadGold)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSearchFocused ? Color.arkadGold.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )
        )
        .scaleEffect(isSearchFocused ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSearchFocused)
    }
    
    private var cleanFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    filterTab(type: type)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
    
    private func filterTab(type: SearchType) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSearchType = type
                if !searchText.isEmpty {
                    performSearch()
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedSearchType == type ? .arkadBlack : .gray)
                
                Text(type.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(selectedSearchType == type ? .arkadBlack : .gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedSearchType == type ? Color.arkadGold : Color.clear)
                    .shadow(
                        color: selectedSearchType == type ? .arkadGold.opacity(0.3) : .clear,
                        radius: selectedSearchType == type ? 6 : 0,
                        x: 0,
                        y: selectedSearchType == type ? 3 : 0
                    )
            )
            .scaleEffect(
                pressedTab == type ? 0.95 :
                (selectedSearchType == type ? 1.02 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedSearchType == type ? Color.arkadGold.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                pressedTab = pressing ? type : nil
            }
        }, perform: {})
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedSearchType == type)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: pressedTab == type)
    }
    
    // MARK: - Empty Search State
    
    private var emptySearchState: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero Section
                VStack(spacing: 20) {
                    // Large Search Icon with Animation
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.arkadGold.opacity(0.2), Color.arkadGold.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.arkadGold)
                    }
                    
                    VStack(spacing: 12) {
                        Text("Discover ArkadTrader")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.arkadBlack)
                        
                        Text("Search for traders, posts, market insights,\nand more")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                }
                .padding(.top, 20)
                
                // Quick Search Section
                quickSearchSection
                
                // Recent Searches Section
                recentSearchesSection
                
                Spacer(minLength: 80)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.white)
    }
    
    private var quickSearchSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick Search")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.arkadBlack)
                
                Text("Popular categories and content")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                quickSearchCard(
                    icon: "person.2.fill",
                    title: "Top Traders",
                    subtitle: "Follow successful traders",
                    iconColor: .arkadGold
                )
                
                quickSearchCard(
                    icon: "doc.text.fill",
                    title: "Market News",
                    subtitle: "Latest market insights",
                    iconColor: .blue
                )
                
                quickSearchCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Popular Stocks",
                    subtitle: "Trending securities",
                    iconColor: .green
                )
                
                quickSearchCard(
                    icon: "lightbulb.fill",
                    title: "Trading Ideas",
                    subtitle: "Community insights",
                    iconColor: .orange
                )
            }
        }
    }
    
    private func quickSearchCard(icon: String, title: String, subtitle: String, iconColor: Color) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                searchText = title.lowercased()
                performSearch()
            }
        }) {
            VStack(alignment: .leading, spacing: 16) {
                // Icon with enhanced styling
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [iconColor.opacity(0.2), iconColor.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.arkadBlack)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .frame(height: 120)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .gray.opacity(0.08), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searchText)
    }
    
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Searches")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.arkadBlack)
                    
                    Text("Tap to search again")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if !searchViewModel.searchHistory.isEmpty {
                    Button("Clear All") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            searchViewModel.clearSearchHistory()
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.arkadGold)
                }
            }
            
            if searchViewModel.searchHistory.isEmpty {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Text("No recent searches")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(searchViewModel.searchHistory.prefix(5), id: \.self) { search in
                        recentSearchRow(search: search)
                    }
                }
            }
        }
    }
    
    private func recentSearchRow(search: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                searchText = search
                performSearch()
            }
        }) {
            HStack(spacing: 16) {
                // Clock icon with enhanced styling
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Text(search)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.arkadBlack)
                
                Spacer()
                
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 24) {
            // Animated Loading Indicator
            ProgressView()
                .scaleEffect(1.5)
                .tint(.arkadGold)
            
            VStack(spacing: 8) {
                Text("Searching...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.arkadBlack)
                
                Text("Finding the best results for you")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    // MARK: - No Results State
    
    private var noResultsState: some View {
        VStack(spacing: 24) {
            // No Results Icon
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.6))
            }
            
            VStack(spacing: 12) {
                Text("No results for \"\(searchText)\"")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.arkadBlack)
                
                Text("Try searching for something else or check your spelling")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            // Suggestions
            VStack(spacing: 16) {
                Text("Suggestions:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 8) {
                    suggestionRow("Try different keywords")
                    suggestionRow("Check for typos")
                    suggestionRow("Use more general terms")
                    suggestionRow("Browse popular content")
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .background(Color.white)
    }
    
    private func suggestionRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.arkadGold.opacity(0.3))
                .frame(width: 6, height: 6)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    // MARK: - Search Results
    
    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Results Header
                resultsHeader
                
                // Results List with Staggered Animation
                ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, result in
                    SearchResultView(result: result)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                            value: filteredResults.count
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color.gray.opacity(0.03))
    }
    
    private var resultsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            // Results Count
            VStack(alignment: .leading, spacing: 4) {
                Text("\(filteredResults.count) result\(filteredResults.count == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.arkadBlack)
                
                if let performance = searchViewModel.searchPerformance {
                    Text("Search time: \(String(format: "%.3f", performance.searchTime))s")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Results Type Filter Indicator
            if selectedSearchType != .all {
                HStack(spacing: 6) {
                    Image(systemName: getFilterIcon(for: selectedSearchType))
                        .font(.system(size: 12))
                        .foregroundColor(.arkadGold)
                    
                    Text(selectedSearchType.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.arkadGold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.arkadGold.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }
    
    private func getFilterIcon(for type: SearchType) -> String {
        switch type {
        case .all: return "magnifyingglass"
        case .users: return "person.2"
        case .posts: return "text.bubble"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .groups: return "person.3"
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
    
    private func handleSearchTextChange(_ newValue: String) {
        searchTask?.cancel()
        
        if newValue.isEmpty {
            isSearching = false
            searchViewModel.clearResults()
            return
        }
        
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !Task.isCancelled && !newValue.isEmpty {
                await performSearchAsync()
            }
            isSearching = false
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            isSearching = true
            await performSearchAsync()
            isSearching = false
        }
    }
    
    private func performSearchAsync() async {
        await searchViewModel.search(query: searchText)
    }
    
    private func clearSearch() {
        withAnimation(.easeInOut(duration: 0.3)) {
            searchTask?.cancel()
            searchText = ""
            isSearching = false
            searchViewModel.clearResults()
            isSearchFocused = false
        }
    }
}


#Preview {
    SearchView()
        .environmentObject(FirebaseAuthService.shared)
}
