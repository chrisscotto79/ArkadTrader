// File: Core/Tickers/TrendingTickersSection.swift
// Discover's "Trending tickers": the most-mentioned tickers in recent posts, with post count,
// the Bullish/Bearish split and the day's price change. Also TickerLink, a tappable "$AAPL".

import SwiftUI

struct TrendingTickersSection: View {
    private let onSelect: (String) -> Void
    private let refreshID: Int

    @State private var phase: Phase = .loading
    @State private var quotes: [String: WatchlistQuote] = [:]
    @State private var lastRefreshID: Int?

    private enum Phase: Equatable {
        case loading
        case loaded([TrendingTicker])
        case failed(String)
    }

    /// - Parameters:
    ///   - refreshID: change it (e.g. from Discover's pull to refresh) to skip the 5-minute cache.
    ///   - onSelect: called with the symbol ("AAPL") when a ticker is tapped.
    init(refreshID: Int = 0, onSelect: @escaping (String) -> Void) {
        self.refreshID = refreshID
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                SectionHeader(title: "Trending tickers")
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.pageMargin)

            content
        }
        .task(id: refreshID) {
            let force = lastRefreshID != nil && lastRefreshID != refreshID
            lastRefreshID = refreshID
            await load(forceRefresh: force)
        }
    }

    private var subtitle: String? {
        guard case .loaded(let tickers) = phase, let window = tickers.first?.window else { return nil }
        return "Most mentioned in the last \(TickerFormat.windowText(window))"
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.m) {
                    ForEach(0..<3, id: \.self) { _ in placeholderTile }
                }
            }
            .contentMargins(.horizontal, DS.pageMargin, for: .scrollContent)
            .scrollDisabled(true)
            .redacted(reason: .placeholder)
            .accessibilityLabel("Loading trending tickers")

        case .loaded(let tickers) where tickers.isEmpty:
            messageCard(
                systemImage: "number",
                title: "No trending tickers yet",
                message: "Mention a ticker like $AAPL in a post and it will show up here."
            )

        case .loaded(let tickers):
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.m) {
                    ForEach(Array(tickers.enumerated()), id: \.element.id) { index, ticker in
                        tile(ticker, rank: index + 1)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, DS.pageMargin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)

        case .failed(let message):
            messageCard(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load trending tickers",
                message: message,
                actionTitle: "Try again"
            ) {
                Task { await load(forceRefresh: true) }
            }
        }
    }

    private func messageCard(systemImage: String, title: String, message: String,
                             actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            IconWell(systemName: systemImage, size: 40)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(PillButtonStyle(kind: .neutral))
                        .padding(.top, DS.Spacing.xs)
                }
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: 14)
        .padding(.horizontal, DS.pageMargin)
    }

    // MARK: - Tiles

    private let tileWidth: CGFloat = 156

    private func tile(_ ticker: TrendingTicker, rank: Int) -> some View {
        let quote = quotes[ticker.symbol]

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            onSelect(ticker.symbol)
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text("$" + ticker.symbol)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: DS.Spacing.xs)
                    Text("#\(rank)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                if WatchlistQuotes.isConfigured {
                    priceRow(quote)
                }

                SentimentMeterBar(bullishPercent: ticker.bullishPercent, height: 6)

                HStack(spacing: DS.Spacing.xs) {
                    Text(postCountText(ticker.mentionCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    sentimentText(ticker)
                }
            }
            .frame(width: tileWidth, alignment: .leading)
            .cardStyle(padding: 14, radius: DS.Radius.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(ticker, quote: quote))
        .accessibilityHint("Opens the $\(ticker.symbol) page")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func priceRow(_ quote: WatchlistQuote?) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            if let quote {
                Text(quote.price.formatted(.currency(code: "USD")))
                    .arkadNumber(15, weight: .semibold)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if let percent = quote.changePercent {
                    ChangePill(text: TickerFormat.percentChange(percent), isPositive: percent >= 0)
                }
            } else {
                Text("No live quote")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 24)
    }

    /// The bigger side of the split: "62% bullish" in green, "70% bearish" in red.
    @ViewBuilder
    private func sentimentText(_ ticker: TrendingTicker) -> some View {
        if let bullish = ticker.bullishPercent {
            let split = TickerFormat.splitPercents(bullishPercent: bullish)
            let leansBullish = split.bullish >= split.bearish
            Text(leansBullish ? "\(split.bullish)% bull" : "\(split.bearish)% bear")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(leansBullish ? PostSentiment.bullish.color : PostSentiment.bearish.color)
                .lineLimit(1)
        } else {
            Text("No tags")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private var placeholderTile: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("$AAPL").font(.headline)
            Text("$000.00").arkadNumber(15, weight: .semibold)
            SentimentMeterBar(bullishPercent: nil, height: 6)
            Text("00 posts").font(.caption)
        }
        .frame(width: tileWidth, alignment: .leading)
        .cardStyle(padding: 14, radius: DS.Radius.m)
    }

    private func postCountText(_ count: Int) -> String {
        "\(count.formatted(.number.notation(.compactName))) post\(count == 1 ? "" : "s")"
    }

    private func accessibilityText(_ ticker: TrendingTicker, quote: WatchlistQuote?) -> String {
        var parts = ["$\(ticker.symbol)", postCountText(ticker.mentionCount)]
        if let bullish = ticker.bullishPercent {
            let split = TickerFormat.splitPercents(bullishPercent: bullish)
            parts.append("\(split.bullish) percent bullish")
        }
        if let quote {
            parts.append(quote.price.formatted(.currency(code: "USD")))
            if let percent = quote.changePercent {
                parts.append("\(TickerFormat.percentChange(percent)) today")
            }
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Loading

    private func load(forceRefresh: Bool) async {
        let service = TickerFeedService.shared
        if forceRefresh { service.clearCaches() }
        // Keep showing the current list while it refreshes
        if case .loaded = phase {} else { phase = .loading }

        do {
            let tickers = try await service.trendingTickers()
            phase = .loaded(tickers)
            if !tickers.isEmpty, WatchlistQuotes.isConfigured {
                quotes = await service.quotes(for: tickers.map(\.symbol))
            }
        } catch is CancellationError {
            return
        } catch {
            if case .loaded = phase { return }
            phase = .failed(TickerFeedError.friendlyMessage(for: error, feature: "Trending tickers"))
        }
    }
}

// MARK: - Ticker link

/// A tappable "$AAPL" chip that pushes the ticker's page. Destination-based, so it works inside
/// lazy stacks; it needs a NavigationStack above it (without one it does nothing).
struct TickerLink: View {
    let symbol: String

    init(symbol: String) {
        self.symbol = TickerFeedService.normalize(symbol)
    }

    var body: some View {
        NavigationLink {
            TickerPageView(ticker: symbol)
        } label: {
            Tag(text: "$" + symbol)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("$\(symbol)")
        .accessibilityHint("Opens the $\(symbol) page")
    }
}

extension TickerLink {
    /// Links in `linkedText` look like arkad://ticker/AAPL.
    static func url(for symbol: String) -> URL? {
        URL(string: "arkad://ticker/\(TickerFeedService.normalize(symbol))")
    }

    /// The symbol from a `url(for:)` link, or nil for any other URL.
    static func symbol(from url: URL) -> String? {
        guard url.scheme == "arkad", url.host == "ticker" else { return nil }
        let symbol = TickerFeedService.normalize(url.lastPathComponent)
        return TickerFeedService.isTickerSymbol(symbol) ? symbol : nil
    }

    /// `text` with every "$AAPL" cashtag turned into a gold `url(for:)` link. Handle taps with
    /// `.environment(\.openURL, OpenURLAction { url in ... symbol(from: url) ... })`.
    static func linkedText(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard let regex = try? NSRegularExpression(pattern: #"\$([A-Za-z]{1,5})\b"#) else { return attributed }
        let ns = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let range = Range(match.range, in: text),
                  let attributedRange = Range(range, in: attributed),
                  let url = url(for: ns.substring(with: match.range(at: 1))) else { continue }
            attributed[attributedRange].link = url
            attributed[attributedRange].foregroundColor = Color.goldText
            attributed[attributedRange].font = Font.body.weight(.semibold)
        }
        return attributed
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TrendingTickersSection { symbol in print("Open \(symbol)") }
                HStack {
                    TickerLink(symbol: "AAPL")
                    TickerLink(symbol: "tsla")
                }
                .padding(.horizontal)
                Text(TickerLink.linkedText("Loading up on $NVDA and $amd into earnings"))
                    .padding(.horizontal)
            }
        }
        .screenBackground()
    }
    .environmentObject(FirebaseAuthService.shared)
}
