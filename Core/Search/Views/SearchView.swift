// File: Core/Search/Views/SearchView.swift
// The Discover tab: search communities, traders, posts and trades. Before you type it shows
// recent searches, popular communities and popular traders.

import SwiftUI

struct SearchView: View {
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var selectedSearchType: SearchType = .all
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool
    @EnvironmentObject private var authService: FirebaseAuthService
    @EnvironmentObject private var tabRouter: TabRouter

    /// Result scopes, communities first because they're the heart of Arkad.
    private let scopes: [SearchType] = [.all, .groups, .users, .posts, .stocks]
    /// How many of each kind "All" shows before "See all".
    private let previewLimit = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenHeader(title: "Discover")

                searchField
                    .padding(.horizontal, DS.pageMargin)

                if hasQuery {
                    scopeChips
                        .padding(.top, DS.Spacing.m)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                content
                    .padding(.top, DS.Spacing.s)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .animation(.snappy(duration: 0.25), value: hasQuery)
        }
        .task {
            if !searchViewModel.hasLoadedSuggestions {
                await searchViewModel.loadDiscoverSuggestions()
            }
        }
        .alert("Search error", isPresented: $searchViewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(searchViewModel.errorMessage)
        }
    }

    // MARK: - Search field

    private var hasQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchField: some View {
        HStack(spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                TextField("Communities, traders, tickers", text: $searchText)
                    .font(.body)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { performSearch() }
                    .onChange(of: searchText) { _, newValue in
                        handleSearchTextChange(newValue)
                    }

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity)
                }

                if !searchText.isEmpty {
                    Button {
                        clearText()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, DS.Spacing.m)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(Color.surfaceRaised)
            )

            if isSearchFocused {
                Button("Cancel") { cancelSearch() }
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: isSearchFocused)
        .animation(.snappy(duration: 0.2), value: searchText.isEmpty)
        .animation(.snappy(duration: 0.2), value: isSearching)
    }

    private var scopeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                ForEach(scopes, id: \.self) { type in
                    Chip(title: scopeTitle(for: type), isSelected: selectedSearchType == type) {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedSearchType = type
                        }
                    }
                }
            }
        }
        .contentMargins(.horizontal, DS.pageMargin, for: .scrollContent)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !hasQuery {
            discoverHome
                .transition(.opacity)
        } else if (isSearching || searchViewModel.isLoading) && searchViewModel.searchResults.isEmpty {
            searchingState
                .transition(.opacity)
        } else if filteredResults.isEmpty {
            noResultsState
                .transition(.opacity)
        } else {
            resultsList
                .transition(.opacity)
        }
    }

    // MARK: - Discover home (empty query)

    private var discoverHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                if !searchViewModel.searchHistory.isEmpty {
                    recentSearchesSection
                }

                if !searchViewModel.suggestedCommunities.isEmpty {
                    popularCommunitiesSection
                }

                if !searchViewModel.suggestedTraders.isEmpty {
                    popularTradersSection
                }

                if searchViewModel.isLoadingSuggestions && !hasSuggestions {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if !hasSuggestions && searchViewModel.searchHistory.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "Search Arkad",
                        message: "Find communities to join, traders to follow, and posts and trades by ticker."
                    )
                }
            }
            .padding(.top, DS.Spacing.m)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await searchViewModel.loadDiscoverSuggestions() }
    }

    private var hasSuggestions: Bool {
        !searchViewModel.suggestedCommunities.isEmpty || !searchViewModel.suggestedTraders.isEmpty
    }

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Recent", actionTitle: "Clear") {
                withAnimation(.snappy(duration: 0.25)) {
                    searchViewModel.clearSearchHistory()
                }
            }

            VStack(spacing: 0) {
                let recent = Array(searchViewModel.searchHistory.prefix(5))
                ForEach(Array(recent.enumerated()), id: \.element) { index, search in
                    if index > 0 { rowDivider(inset: DS.Spacing.l + 28) }
                    recentSearchRow(search)
                }
            }
            .cardStyle(padding: 0)
        }
        .padding(.horizontal, DS.pageMargin)
    }

    private func recentSearchRow(_ search: String) -> some View {
        Button {
            searchText = search
            performSearch()
        } label: {
            HStack(spacing: DS.Spacing.m) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(search)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.Spacing.l)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Search for \(search)")
    }

    private var popularCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Popular communities", actionTitle: "See all") {
                tabRouter.selected = .communities
            }
            .padding(.horizontal, DS.pageMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.m) {
                    ForEach(searchViewModel.suggestedCommunities) { community in
                        SearchResultView(result: SearchResult(community: community), style: .communityCard)
                            .environmentObject(authService)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, DS.pageMargin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private var popularTradersSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Popular traders")

            VStack(spacing: 0) {
                let traders = searchViewModel.suggestedTraders
                ForEach(Array(traders.enumerated()), id: \.element.id) { index, user in
                    if index > 0 { rowDivider() }
                    SearchResultView(result: SearchResult(user: user))
                        .environmentObject(authService)
                }
            }
            .cardStyle(padding: 0)
        }
        .padding(.horizontal, DS.pageMargin)
    }

    // MARK: - Searching / no results

    private var searchingState: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.m) {
                ProgressView()
                    .controlSize(.large)
                Text("Searching…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private var noResultsState: some View {
        ScrollView {
            if selectedSearchType != .all && !searchViewModel.searchResults.isEmpty {
                EmptyStateView(
                    systemImage: "line.3.horizontal.decrease.circle",
                    title: "No \(scopeTitle(for: selectedSearchType).lowercased())",
                    message: "Nothing in \(scopeTitle(for: selectedSearchType).lowercased()) matched “\(trimmedQuery)”.",
                    actionTitle: "Show all results"
                ) {
                    withAnimation(.snappy(duration: 0.25)) { selectedSearchType = .all }
                }
            } else {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No results",
                    message: "Nothing matched “\(trimmedQuery)”. Try a ticker, a username or a community name."
                )
            }
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.xl) {
                if selectedSearchType == .all {
                    ForEach(scopes.filter { $0 != .all }, id: \.self) { scope in
                        let scoped = results(for: scope)
                        if !scoped.isEmpty {
                            resultsSection(scope: scope, results: scoped, limit: previewLimit)
                        }
                    }
                } else {
                    resultsSection(scope: selectedSearchType, results: filteredResults, limit: nil)
                }
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.m)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func resultsSection(scope: SearchType, results: [SearchResult], limit: Int?) -> some View {
        let shown = limit.map { Array(results.prefix($0)) } ?? results
        var expandAction: (() -> Void)? = nil
        if limit != nil && results.count > shown.count {
            expandAction = {
                withAnimation(.snappy(duration: 0.25)) { selectedSearchType = scope }
            }
        }

        return VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(
                title: scopeTitle(for: scope),
                count: results.count,
                actionTitle: expandAction == nil ? nil : "See all",
                action: expandAction
            )

            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, result in
                    if index > 0 { rowDivider() }
                    SearchResultView(result: result)
                        .environmentObject(authService)
                }
            }
            .cardStyle(padding: 0)
        }
    }

    private func rowDivider(inset: CGFloat = DS.Spacing.l + 44 + DS.Spacing.m) -> some View {
        Divider()
            .overlay(Color.hairline)
            .padding(.leading, inset)
    }

    // MARK: - Computed Properties

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredResults: [SearchResult] {
        results(for: selectedSearchType)
    }

    private func results(for scope: SearchType) -> [SearchResult] {
        switch scope {
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

    /// Scope label. `.stocks` matches traders' logged trades, so it's "Trades".
    private func scopeTitle(for type: SearchType) -> String {
        switch type {
        case .all: return "All"
        case .groups: return "Communities"
        case .users: return "Traders"
        case .posts: return "Posts"
        case .stocks: return "Trades"
        }
    }

    // MARK: - Helper Methods

    private func handleSearchTextChange(_ newValue: String) {
        searchTask?.cancel()

        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isSearching = false
            searchViewModel.clearResults()
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await performSearchAsync()
            isSearching = false
        }
    }

    private func performSearch() {
        guard hasQuery else { return }

        searchTask?.cancel()
        Task {
            isSearching = true
            await performSearchAsync()
            isSearching = false
        }
    }

    private func performSearchAsync() async {
        await searchViewModel.search(query: searchText)
    }

    /// Clears the text but keeps the keyboard up.
    private func clearText() {
        searchTask?.cancel()
        searchText = ""
        isSearching = false
        selectedSearchType = .all
        searchViewModel.clearResults()
    }

    /// Clears the search and dismisses the keyboard.
    private func cancelSearch() {
        clearText()
        isSearchFocused = false
    }
}

// MARK: - Custom Button Style

/// Subtle press scale. Also used by the Communities leaderboard.
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .environmentObject(FirebaseAuthService.shared)
        .environmentObject(TabRouter())
}
