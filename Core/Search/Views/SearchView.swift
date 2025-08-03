// File: Core/Search/Views/SearchView.swift
// Enhanced Search View with modern, professional UI/UX

import SwiftUI

struct SearchView: View {
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var selectedSearchType: SearchType = .all
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool
    @EnvironmentObject private var authService: FirebaseAuthService

    
    // Sheet states for future features
    @State private var showAdvancedFilters = false
    @State private var showSearchSettings = false
    @State private var showSearchAnalytics = false
    @State private var pressedTab: SearchType?
    
    // Animation states
    @State private var searchBarScale = 1.0
    @State private var showSearchHint = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Enhanced Header
                    headerSection
                    
                    // Main Content with transitions
                    Group {
                        if searchText.isEmpty {
                            emptySearchState
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                    removal: .opacity
                                ))
                        } else if searchViewModel.isLoading {
                            loadingState
                                .transition(.opacity)
                        } else if searchViewModel.searchResults.isEmpty {
                            noResultsState
                                .transition(.opacity)
                        } else {
                            searchResults
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: searchText.isEmpty)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: searchViewModel.isLoading)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showAdvancedFilters) {
            advancedFiltersSheet
        }
        .sheet(isPresented: $showSearchSettings) {
            searchSettingsSheet
        }
        .sheet(isPresented: $showSearchAnalytics) {
            searchAnalyticsSheet
        }
        .alert("Search Error", isPresented: $searchViewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(searchViewModel.errorMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                // Enhanced Search Bar
                enhancedSearchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Modern Filter Pills
                modernFilterPills
                    .padding(.top, 8)
            }
            .padding(.bottom, 16)
            .background(
                Rectangle()
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(0.04),
                        radius: 10,
                        x: 0,
                        y: 5
                    )
            )
        }
    }
    
    private var enhancedSearchBar: some View {
        HStack(spacing: 12) {
            // Animated search icon
            ZStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isSearchFocused ? .arkadGold : .secondary)
                    .font(.system(size: 17, weight: .medium))
                    .scaleEffect(isSearchFocused ? 1.1 : 1.0)
            }
            .animation(.spring(response: 0.3), value: isSearchFocused)
            
            // Text field with placeholder animation
            ZStack(alignment: .leading) {
                if searchText.isEmpty && !isSearchFocused {
                    Text("Search traders, posts, stocks...")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                TextField("", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .focused($isSearchFocused)
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { newValue in
                        handleSearchTextChange(newValue)
                    }
            }
            
            // Action buttons
            HStack(spacing: 8) {
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 18))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.arkadGold)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Microphone button (future voice search)
                Button(action: { showSearchHint.toggle() }) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 16))
                }
                .opacity(searchText.isEmpty ? 1 : 0)
                .animation(.easeInOut, value: searchText.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: isSearchFocused ?
                                    [Color.arkadGold.opacity(0.6), Color.arkadGold.opacity(0.3)] :
                                    [Color.clear, Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .scaleEffect(searchBarScale)
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                searchBarScale = 0.98
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3)) {
                    searchBarScale = 1.0
                }
            }
        }
    }
    
    private var modernFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    modernFilterPill(type: type)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func modernFilterPill(type: SearchType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedSearchType = type
                if !searchText.isEmpty {
                    performSearch()
                }
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 13, weight: .semibold))
                
                Text(type.displayName)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(selectedSearchType == type ? .white : .primary.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selectedSearchType == type ?
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color(.systemGray5), Color(.systemGray5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: selectedSearchType == type ? Color.arkadGold.opacity(0.3) : .clear,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        selectedSearchType == type ? Color.clear : Color.primary.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(pressedTab == type ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: pressedTab == type)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            pressedTab = pressing ? type : nil
        }, perform: {})
    }
    
    // MARK: - Empty Search State
    
    private var emptySearchState: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Hero Section with Animation
                VStack(spacing: 24) {
                    // Animated Search Icon
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.arkadGold.opacity(0.3), Color.arkadGold.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(showSearchHint ? 360 : 0))
                            .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: showSearchHint)
                        
                        // Inner gradient circle
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.arkadGold.opacity(0.1), Color.arkadGold.opacity(0.05)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36, weight: .light, design: .rounded))
                            .foregroundColor(.arkadGold)
                            .scaleEffect(showSearchHint ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: showSearchHint)
                    }
                    .onAppear { showSearchHint = true }
                    
                    VStack(spacing: 12) {
                        Text("Discover ArkadTrader")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Find traders, insights, and opportunities")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                
                // Modern Recent Searches Section
                modernRecentSearchesSection
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
    }

    
    private var modernRecentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !searchViewModel.searchHistory.isEmpty {
                    Button(action: {
                        withAnimation(.spring()) {
                            searchViewModel.clearSearchHistory()
                        }
                    }) {
                        Text("Clear")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.arkadGold)
                    }
                }
            }
            
            if searchViewModel.searchHistory.isEmpty {
                emptyRecentSearches
            } else {
                VStack(spacing: 8) {
                    ForEach(searchViewModel.searchHistory.prefix(5), id: \.self) { search in
                        modernRecentSearchRow(search: search)
                    }
                }
            }
        }
    }
    
    private var emptyRecentSearches: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "clock")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("No recent searches")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Your search history will appear here")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    private func modernRecentSearchRow(search: String) -> some View {
        Button(action: {
            withAnimation(.spring()) {
                searchText = search
                performSearch()
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(.systemGray6), Color(.systemGray5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text(search)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 32) {
            // Custom loading animation
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.arkadGold.opacity(0.3 - Double(index) * 0.1))
                        .frame(width: 40 + CGFloat(index) * 20, height: 40 + CGFloat(index) * 20)
                        .scaleEffect(showSearchHint ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: showSearchHint
                        )
                }
            }
            .onAppear { showSearchHint = true }
            
            VStack(spacing: 12) {
                Text("Searching...")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Finding the best results for you")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Results State
    
    private var noResultsState: some View {
        VStack(spacing: 32) {
            // Enhanced no results illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(.systemGray5), Color(.systemGray6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(-15))
            }
            
            VStack(spacing: 16) {
                Text("No results found")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("We couldn't find anything matching\n\"\(searchText)\"")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Enhanced suggestions
            VStack(spacing: 12) {
                Text("Try these:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                
                VStack(spacing: 10) {
                    suggestionPill("Different keywords")
                    suggestionPill("Check spelling")
                    suggestionPill("Broader search terms")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    private func suggestionPill(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 12))
                .foregroundColor(.arkadGold)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.arkadGold.opacity(0.1))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.arkadGold.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Search Results
    
    private var searchResults: some View {
        ScrollView {
                    LazyVStack(spacing: 12) {
                        // Enhanced results header
                        enhancedResultsHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        // Results with enhanced cards
                        ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, result in
                            SearchResultView(result: result)
                                .environmentObject(authService)  // ← Now this will work
                                .padding(.horizontal, 20)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.05),
                                    value: filteredResults.count
                                )
                        }
                    }
                    .padding(.bottom, 100)
                }
    }
    
    private var enhancedResultsHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(filteredResults.count) Results")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                if let performance = searchViewModel.searchPerformance {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.arkadGold)
                        
                        Text("\(String(format: "%.1f", performance.searchTime))s")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Sort/Filter button
            Button(action: { showAdvancedFilters = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 14))
                    
                    Text("Filter")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.arkadGold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.arkadGold.opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.arkadGold.opacity(0.3), lineWidth: 1)
                        )
                )
            }
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
            try? await Task.sleep(nanoseconds: 300_000_000) // Reduced debounce
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
        withAnimation(.spring()) {
            searchTask?.cancel()
            searchText = ""
            isSearching = false
            searchViewModel.clearResults()
            isSearchFocused = false
        }
    }
    
    // MARK: - Sheet Views
    
    private var advancedFiltersSheet: some View {
        NavigationView {
            VStack {
                Text("Advanced Filters")
                    .font(.largeTitle.bold())
                    .padding()
                
                Text("Coming Soon")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationBarItems(trailing: Button("Done") { showAdvancedFilters = false })
        }
    }
    
    private var searchSettingsSheet: some View {
        NavigationView {
            VStack {
                Text("Search Settings")
                    .font(.largeTitle.bold())
                    .padding()
                
                Text("Coming Soon")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationBarItems(trailing: Button("Done") { showSearchSettings = false })
        }
    }
    
    private var searchAnalyticsSheet: some View {
        NavigationView {
            VStack {
                Text("Search Analytics")
                    .font(.largeTitle.bold())
                    .padding()
                
                Text("Coming Soon")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationBarItems(trailing: Button("Done") { showSearchAnalytics = false })
        }
    }
}

// MARK: - Supporting Views

struct EnhancedSearchResultView: View {
    let result: SearchResult
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar/Icon with gradient border
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 52, height: 52)
                
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 48, height: 48)
                
                Image(systemName: getResultIcon(for: result.type))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.arkadGold)
            }
            
            // Content
            
            Spacer()
            
            // Action indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    private func getResultIcon(for type: SearchResultType) -> String {
        switch type {
        case .user: return "person.fill"
        case .post: return "text.bubble.fill"
        case .trade: return "chart.line.uptrend.xyaxis"
        case .group: return "person.3.fill"
        }
    }
}

// MARK: - Custom Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .environmentObject(FirebaseAuthService.shared)
}
