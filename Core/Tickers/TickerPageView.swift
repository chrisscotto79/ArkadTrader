// File: Core/Tickers/TickerPageView.swift
// A ticker's page ($AAPL): live price and day change, watchlist and price alert actions,
// the Bullish/Bearish meter, and every post that mentions the ticker, newest first.
// Pushed onto the caller's NavigationStack; it has no NavigationStack of its own.

import SwiftUI
import FirebaseFirestore

// MARK: - Model

@MainActor
final class TickerPageModel: ObservableObject {
    enum FeedPhase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    enum QuotePhase: Equatable {
        case loading
        case loaded(WatchlistQuote)
        case unavailable
    }

    enum SentimentPhase: Equatable {
        case loading
        /// nil: fewer than 3 tagged posts
        case loaded(TickerSentimentSummary?)
        case failed(String)
    }

    let ticker: String

    /// The page's posts. Likes, counts, deletes, reports and blocks come from PostStore.
    @Published private(set) var posts: [Post] = []

    @Published private(set) var feedPhase: FeedPhase = .loading
    @Published private(set) var quotePhase: QuotePhase = .loading
    @Published private(set) var sentimentPhase: SentimentPhase = .loading
    @Published private(set) var hasMore = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadMoreError: String?
    /// A refresh failed while older posts are still showing.
    @Published private(set) var refreshError: String?
    /// Bumped after every page, so the "load more" trigger runs again if it's still on screen.
    @Published private(set) var pagesLoaded = 0

    private let service = TickerFeedService.shared
    private let pageSize = 30
    private var cursor: DocumentSnapshot?
    private var hasStarted = false
    /// Bumped on every first-page load so a late "load more" for an older list is dropped.
    private var generation = 0

    init(ticker: String) {
        self.ticker = TickerFeedService.normalize(ticker)
    }

    var assetType: TradeType { TickerFeedService.assetType(for: ticker) }

    /// Why there's no price, in plain words.
    var noQuoteReason: String {
        if assetType != .stock { return "Live prices are only available for stocks right now." }
        if !WatchlistQuotes.isConfigured { return "Live prices aren't set up in this version of Arkad." }
        return "There's no price for $\(ticker) right now. Live prices cover US stocks."
    }

    // MARK: Loading

    func loadIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true
        await load(forceRefresh: false)
    }

    /// Pull to refresh: price, meter and the first page of posts.
    func refresh() async {
        hasStarted = true
        await load(forceRefresh: true)
    }

    private func load(forceRefresh: Bool) async {
        async let feed: Void = loadFirstPage()
        async let quote: Void = loadQuote()
        async let sentiment: Void = loadSentiment(forceRefresh: forceRefresh)
        await feed
        await quote
        await sentiment
    }

    private func loadFirstPage() async {
        generation += 1
        let thisGeneration = generation
        if posts.isEmpty { feedPhase = .loading }

        do {
            async let interactions: Void = PostStore.shared.loadIfNeeded()
            let (loaded, next) = try await service.posts(for: ticker, limit: pageSize, after: nil)
            await interactions
            guard thisGeneration == generation else { return }
            posts = loaded
            PostStore.shared.absorb(loaded)
            cursor = next
            hasMore = next != nil
            loadMoreError = nil
            refreshError = nil
            feedPhase = .loaded
            pagesLoaded += 1
        } catch {
            guard thisGeneration == generation else { return }
            let message = TickerFeedError.friendlyMessage(for: error)
            if posts.isEmpty {
                feedPhase = .failed(message)
            } else {
                refreshError = message
            }
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, let cursor else { return }
        let thisGeneration = generation
        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }

        do {
            let (loaded, next) = try await service.posts(for: ticker, limit: pageSize, after: cursor)
            guard thisGeneration == generation else { return }
            let shown = Set(posts.map(\.id))
            let fresh = loaded.filter { !shown.contains($0.id) }
            posts.append(contentsOf: fresh)
            PostStore.shared.absorb(fresh)
            self.cursor = next
            hasMore = next != nil
            pagesLoaded += 1
        } catch {
            guard thisGeneration == generation else { return }
            loadMoreError = TickerFeedError.friendlyMessage(for: error)
        }
    }

    private func loadQuote() async {
        guard assetType == .stock, WatchlistQuotes.isConfigured else {
            quotePhase = .unavailable
            return
        }
        if case .loaded = quotePhase {} else { quotePhase = .loading }
        let quotes = await service.quotes(for: [ticker])
        if let quote = quotes[ticker] {
            quotePhase = .loaded(quote)
        } else if case .loaded = quotePhase {
            // Keep the last price rather than blanking it on a failed refresh
        } else {
            quotePhase = .unavailable
        }
    }

    private func loadSentiment(forceRefresh: Bool) async {
        if case .loaded = sentimentPhase {} else { sentimentPhase = .loading }
        do {
            let summary = try await service.sentimentSummary(for: ticker, forceRefresh: forceRefresh)
            sentimentPhase = .loaded(summary)
        } catch {
            if case .loaded = sentimentPhase { return }
            sentimentPhase = .failed(TickerFeedError.friendlyMessage(for: error, feature: "the sentiment meter"))
        }
    }
}

// MARK: - View

struct TickerPageView: View {
    let ticker: String
    @StateObject private var model: TickerPageModel
    @ObservedObject private var watchlist = WatchlistStore.shared
    @State private var alertItem: WatchlistItem?
    @State private var watchlistError: String?
    @State private var isUpdatingWatchlist = false

    init(ticker: String) {
        let symbol = TickerFeedService.normalize(ticker)
        self.ticker = symbol
        _model = StateObject(wrappedValue: TickerPageModel(ticker: symbol))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                headerCard
                sentimentCard
                postsSection
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .screenBackground()
        .navigationTitle("$" + ticker)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .refreshable { await model.refresh() }
        .postStoreFeedback()
        .task { await model.loadIfNeeded() }
        .task {
            if !watchlist.hasLoaded { await watchlist.load() }
        }
        .sheet(item: $alertItem) { item in
            PriceAlertSheet(item: item)
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

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .center, spacing: DS.Spacing.m) {
                IconWell(systemName: model.assetType.icon, tint: model.assetType.color, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("$" + ticker)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                    Text(model.assetType.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Spacing.s)
                quoteView
            }

            if model.quotePhase == .unavailable {
                Label(model.noQuoteReason, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actionButtons
        }
        .cardStyle()
    }

    @ViewBuilder
    private var quoteView: some View {
        switch model.quotePhase {
        case .loading:
            VStack(alignment: .trailing, spacing: 4) {
                Text("$000.00").arkadNumber(22)
                ChangePill(text: "+0.00%", isPositive: true)
            }
            .redacted(reason: .placeholder)
            .accessibilityLabel("Loading price")

        case .loaded(let quote):
            VStack(alignment: .trailing, spacing: 4) {
                Text(quote.price.formatted(.currency(code: "USD")))
                    .arkadNumber(22)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let percent = quote.changePercent {
                    ChangePill(text: TickerFormat.percentChange(percent), isPositive: percent >= 0)
                }
                if let change = quote.change {
                    Text("\(TickerFormat.dollarChange(change)) today")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

        case .unavailable:
            VStack(alignment: .trailing, spacing: 4) {
                Text("—")
                    .arkadNumber(22)
                    .foregroundStyle(.tertiary)
                Text("No live quote")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("No live quote")
        }
    }

    // MARK: - Watchlist and alerts

    private var isWatching: Bool { watchlist.contains(ticker) }

    private var activeAlertCount: Int { watchlist.activeAlerts(for: ticker).count }

    private var actionButtons: some View {
        HStack(spacing: DS.Spacing.s) {
            Button {
                toggleWatch()
            } label: {
                HStack(spacing: 6) {
                    if isUpdatingWatchlist {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: isWatching ? "checkmark" : "star")
                    }
                    Text(isWatching ? "On watchlist" : "Add to watchlist")
                        .lineLimit(1)
                }
            }
            .buttonStyle(PillButtonStyle(kind: isWatching ? .neutral : .gold))
            .disabled(isUpdatingWatchlist || watchlist.isLoading)
            .accessibilityLabel(isWatching ? "Remove \(ticker) from watchlist" : "Add \(ticker) to watchlist")

            Button {
                openPriceAlert()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: activeAlertCount > 0 ? "bell.fill" : "bell")
                    Text(activeAlertCount > 0 ? "Alerts · \(activeAlertCount)" : "Price alert")
                        .lineLimit(1)
                }
            }
            .buttonStyle(PillButtonStyle(kind: .neutral))
            .accessibilityLabel(activeAlertCount > 0
                                ? "Price alerts, \(activeAlertCount) active"
                                : "Set a price alert for \(ticker)")

            Spacer(minLength: 0)
        }
    }

    private func toggleWatch() {
        guard !isUpdatingWatchlist else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let wasWatching = isWatching
        isUpdatingWatchlist = true
        Task {
            do {
                if wasWatching {
                    if let item = watchlist.items.first(where: { $0.symbol == ticker }) {
                        try await watchlist.remove(item)
                    }
                } else {
                    try await watchlist.add(symbol: ticker, assetType: model.assetType)
                }
            } catch {
                watchlistError = error.localizedDescription
            }
            isUpdatingWatchlist = false
        }
    }

    private func openPriceAlert() {
        // The sheet reads the current price from the store, to prefill the target
        if case .loaded(let quote) = model.quotePhase {
            watchlist.mergeQuotes([ticker: quote])
        }
        alertItem = watchlist.items.first(where: { $0.symbol == ticker })
            ?? WatchlistItem(symbol: ticker, assetType: model.assetType, addedAt: Date())
    }

    // MARK: - Sentiment meter

    private var sentimentCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sentiment")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if case .loaded(let summary?) = model.sentimentPhase {
                    Text("\(summary.taggedCount) \(summary.taggedCount == 1 ? "person" : "people") tagged it, of \(summary.postsConsidered) recent posts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            switch model.sentimentPhase {
            case .loading:
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    SentimentMeterBar(bullishPercent: 50)
                    HStack {
                        Text("50% Bullish")
                        Spacer()
                        Text("50% Bearish")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .redacted(reason: .placeholder)
                .accessibilityLabel("Loading sentiment")

            case .loaded(let summary?):
                let split = TickerFormat.splitPercents(bullishPercent: summary.bullishPercent)
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    SentimentMeterBar(bullishPercent: summary.bullishPercent)
                    HStack {
                        Label("\(split.bullish)% Bullish", systemImage: PostSentiment.bullish.systemImage)
                            .foregroundStyle(PostSentiment.bullish.color)
                        Spacer(minLength: DS.Spacing.s)
                        Label("\(split.bearish)% Bearish", systemImage: PostSentiment.bearish.systemImage)
                            .foregroundStyle(PostSentiment.bearish.color)
                            .labelStyle(TrailingIconLabelStyle())
                    }
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(split.bullish) percent bullish, \(split.bearish) percent bearish, from \(summary.taggedCount) people's tags")

            case .loaded(nil):
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    SentimentMeterBar(bullishPercent: nil)
                    Text("Not enough tags yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text("Tag your post Bullish or Bearish when you mention $\(ticker) to add to the meter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .failed(let message):
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Posts

    @ViewBuilder
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Posts")
                .padding(.top, DS.Spacing.xs)

            if let refreshError = model.refreshError {
                Label(refreshError, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch model.feedPhase {
            case .loading:
                VStack(spacing: DS.Spacing.m) {
                    ProgressView()
                    Text("Loading posts…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)

            case .failed(let message):
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn't load posts",
                    message: message,
                    actionTitle: "Try again"
                ) {
                    Task { await model.refresh() }
                }

            case .loaded:
                TickerPostsList(model: model, ticker: ticker)
            }
        }
    }
}

// MARK: - Posts list

/// Observes PostStore and BlockStore too, so deletes, reports and blocks redraw the list.
private struct TickerPostsList: View {
    @ObservedObject var model: TickerPageModel
    @ObservedObject private var store = PostStore.shared
    @ObservedObject private var blockStore = BlockStore.shared
    let ticker: String

    var body: some View {
        let posts = store.visible(model.posts)

        if posts.isEmpty && !model.hasMore && !model.isLoadingMore {
            EmptyStateView(
                systemImage: "text.bubble",
                title: "No posts about $\(ticker) yet — be the first",
                message: "Write a post that mentions $\(ticker) and it will show up here."
            )
        } else {
            LazyVStack(spacing: DS.Spacing.m) {
                ForEach(posts, id: \.id) { post in
                    UserPostCard(post: post)
                        .environmentObject(FirebaseAuthService.shared)
                }
                footer
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if model.isLoadingMore {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.l)
        } else if let error = model.loadMoreError {
            VStack(spacing: DS.Spacing.s) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try again") {
                    Task { await model.loadMore() }
                }
                .buttonStyle(PillButtonStyle(kind: .neutral))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.l)
        } else if model.hasMore {
            // Loads the next page when the end of the list comes into view
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.l)
                .task(id: model.pagesLoaded) {
                    await model.loadMore()
                }
        }
    }
}

// MARK: - Label style

/// Text first, icon after: "38% Bearish ↘".
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

#Preview {
    NavigationStack {
        TickerPageView(ticker: "AAPL")
    }
    .environmentObject(FirebaseAuthService.shared)
}
