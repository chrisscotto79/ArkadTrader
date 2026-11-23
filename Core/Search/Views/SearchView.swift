// File: Core/Search/Views/SearchView.swift
// The Discover tab: search communities, traders, posts and trades. Before you type it shows
// Learn and Watchlist shortcuts, recent searches, popular communities and popular traders.

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
    @ObservedObject private var watchlist = WatchlistStore.shared
    @ObservedObject private var learnProgress = LearnProgressStore.shared
    @State private var watchlistError: String?
    @State private var showLearnFromLink = false
    @State private var showWatchlistFromLink = false
    /// A ticker opened from Trending tickers
    @State private var trendingTicker: String?
    /// Bumped by pull to refresh so Trending tickers skips its cache
    @State private var trendingRefresh = 0

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
                    .navigationDestination(isPresented: $showLearnFromLink) { LearnHubView() }
                    .navigationDestination(isPresented: $showWatchlistFromLink) { WatchlistView() }
                    .navigationDestination(item: $trendingTicker) { symbol in TickerPageView(ticker: symbol) }
                    .onAppear { openLinkedScreen(tabRouter.pendingDeepLink) }
                    .onChange(of: tabRouter.pendingDeepLink) { _, link in openLinkedScreen(link) }
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .animation(.snappy(duration: 0.25), value: hasQuery)
        }
        .task {
            await learnProgress.load()
            if !watchlist.hasLoaded {
                await watchlist.load()
            }
            if !searchViewModel.hasLoadedSuggestions {
                await searchViewModel.loadDiscoverSuggestions()
            }
        }
        .alert("Search error", isPresented: $searchViewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(searchViewModel.errorMessage)
        }
        .alert("Watchlist", isPresented: Binding(
            get: { watchlistError != nil },
            set: { if !$0 { watchlistError = nil } }
        )) {
            Button("OK", role: .cancel) { watchlistError = nil }
        } message: {
            Text(watchlistError ?? "")
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
                shortcutsSection

                TrendingTickersSection(refreshID: trendingRefresh) { symbol in
                    trendingTicker = symbol
                }

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
        .refreshable {
            trendingRefresh += 1
            await searchViewModel.loadDiscoverSuggestions()
            await watchlist.load()
        }
    }

    // MARK: - Learn and Watchlist shortcuts

    /// Notifications can point at Learn or the watchlist.
    private func openLinkedScreen(_ link: DeepLink?) {
        switch link {
        case .learn: showLearnFromLink = true
        case .watchlist: showWatchlistFromLink = true
        default: return
        }
        tabRouter.pendingDeepLink = nil
    }

    private var shortcutsSection: some View {
        VStack(spacing: DS.Spacing.m) {
            NavigationLink {
                LearnHubView()
            } label: {
                learnCard
            }
            .buttonStyle(PressableStyle())

            NavigationLink {
                WatchlistView()
            } label: {
                watchlistCard
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, DS.pageMargin)
    }

    private var learnCard: some View {
        let total = LearnContent.totalLessonCount
        let done = learnProgress.totalCompletedLessons

        return VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                IconWell(systemName: "graduationcap.fill", size: 52)
                Spacer(minLength: 0)
                if done > 0 {
                    LearnPercentRing(progress: total == 0 ? 0 : Double(done) / Double(total), size: 52)
                } else {
                    Tag(text: "New", systemImage: "sparkles")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(done > 0 ? "Keep learning" : "Learn to trade")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.primary)
                Text(learnSubtitle(done: done, total: total))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: DS.Spacing.xs) {
                Text(done > 0 ? "Continue" : "Start learning")
                Image(systemName: "arrow.right")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.goldText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .fill(Color.goldTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .strokeBorder(Color.goldText.opacity(0.25), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Learn")
    }

    private func learnSubtitle(done: Int, total: Int) -> String {
        if done == 0 {
            return "\(LearnContent.tracks.count) short tracks on stocks, options, crypto, forex, risk and staying safe in communities."
        }
        if done >= total { return "All \(total) lessons done. Review any time." }
        if let next = learnProgress.continueLesson {
            return "\(done) of \(total) lessons done. Next up: \(next.title)."
        }
        return "\(done) of \(total) lessons done."
    }

    private var watchlistCard: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: "star.fill", tint: .orange, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Watchlist")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(watchlistSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .cardStyle(padding: 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var watchlistSubtitle: String {
        let count = watchlist.items.count
        guard count > 0 else { return "Follow symbols and set price alerts" }
        var parts = ["\(count) symbol\(count == 1 ? "" : "s")"]
        let alerts = watchlist.activeAlerts.count
        if alerts > 0 { parts.append("\(alerts) alert\(alerts == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
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
            if let symbol = typedTicker {
                viewTickerRow(symbol)
                    .padding(.horizontal, DS.pageMargin)
                    .padding(.top, DS.Spacing.m)
            }

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
                let tickers = searchViewModel.resultTickers
                let showTickersFirst = selectedSearchType == .stocks || queryIsTicker(in: tickers)
                // Typed tickers already listed under Tickers open from their own row
                let extraTicker = typedTicker.flatMap { symbol in
                    tickers.contains { $0.symbol == symbol } ? nil : symbol
                }
                let extraTickerFirst = showTickersFirst || queryLooksLikeTicker

                if let extraTicker, extraTickerFirst {
                    viewTickerRow(extraTicker)
                }

                if showTickersFirst && !tickers.isEmpty {
                    tickersSection(tickers)
                }

                if selectedSearchType == .all {
                    ForEach(scopes.filter { $0 != .all }, id: \.self) { scope in
                        let scoped = results(for: scope)
                        if !scoped.isEmpty {
                            resultsSection(scope: scope, results: scoped, limit: previewLimit)
                        }
                    }

                    if !showTickersFirst && !tickers.isEmpty {
                        tickersSection(tickers)
                    }
                } else {
                    resultsSection(scope: selectedSearchType, results: filteredResults, limit: nil)
                }

                if let extraTicker, !extraTickerFirst {
                    viewTickerRow(extraTicker)
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

    // MARK: - Tickers

    /// True when the query is one of the tickers, e.g. "aapl", so tickers lead the results.
    private func queryIsTicker(in tickers: [SearchTicker]) -> Bool {
        let query = WatchlistSymbol.normalize(trimmedQuery)
        return tickers.contains { $0.symbol == query }
    }

    /// Tickers found in trade results, each with a watchlist toggle.
    private func tickersSection(_ tickers: [SearchTicker]) -> some View {
        let shown = selectedSearchType == .all ? Array(tickers.prefix(previewLimit)) : tickers

        return VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Tickers", count: tickers.count)

            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, ticker in
                    if index > 0 { rowDivider(inset: DS.Spacing.l + 40 + DS.Spacing.m) }
                    tickerRow(ticker)
                }
            }
            .cardStyle(padding: 0)
        }
    }

    private func tickerRow(_ ticker: SearchTicker) -> some View {
        let isWatching = watchlist.contains(ticker.symbol)

        return HStack(spacing: DS.Spacing.m) {
            NavigationLink {
                TickerPageView(ticker: ticker.symbol)
            } label: {
                HStack(spacing: DS.Spacing.m) {
                    IconWell(systemName: ticker.assetType.icon, tint: ticker.assetType.color, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ticker.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text(ticker.assetType.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: DS.Spacing.s)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Opens the $\(ticker.symbol) page")

            Button {
                toggleWatch(ticker, isWatching: isWatching)
            } label: {
                Label(isWatching ? "Watching" : "Watch", systemImage: isWatching ? "checkmark" : "star")
            }
            .buttonStyle(PillButtonStyle(kind: isWatching ? .neutral : .gold))
            .accessibilityLabel(isWatching ? "Remove \(ticker.symbol) from watchlist" : "Add \(ticker.symbol) to watchlist")
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
    }

    private func toggleWatch(_ ticker: SearchTicker, isWatching: Bool) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            do {
                if isWatching {
                    if let item = watchlist.items.first(where: { $0.symbol == ticker.symbol }) {
                        try await watchlist.remove(item)
                    }
                } else {
                    try await watchlist.add(symbol: ticker.symbol, assetType: ticker.assetType)
                }
            } catch {
                watchlistError = error.localizedDescription
            }
        }
    }

    /// The query as a cashtag symbol ("aapl", "$TSLA" -> "TSLA"), when it could be one.
    private var typedTicker: String? {
        let symbol = TickerFeedService.normalize(trimmedQuery)
        return TickerFeedService.isTickerSymbol(symbol) ? symbol : nil
    }

    /// Typed with a "$" or in capitals, so the ticker page leads the results.
    private var queryLooksLikeTicker: Bool {
        guard typedTicker != nil else { return false }
        return trimmedQuery.hasPrefix("$") || trimmedQuery == trimmedQuery.uppercased()
    }

    /// "Posts about $AAPL": opens the ticker page for a typed ticker.
    private func viewTickerRow(_ symbol: String) -> some View {
        NavigationLink {
            TickerPageView(ticker: symbol)
        } label: {
            HStack(spacing: DS.Spacing.m) {
                IconWell(systemName: "number", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("$\(symbol)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text("Posts, sentiment and price")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .cardStyle(padding: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the $\(symbol) page")
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
