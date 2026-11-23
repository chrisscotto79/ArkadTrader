// File: Core/Portfolio/Views/PortfolioView.swift
// The Portfolio tab: account value, performance chart, key stats, and your open and closed trades.
// Tap a trade to close, edit or delete it; the gold "+" logs a new one. Linked brokerages add a
// read-only holdings section and Verified imported trades (hidden while AppConfig.brokerageLinkingEnabled is off).
// Every trade row shows its proof label. Win rate, realized P&L, the chart and best trade count only
// price-checked and verified trades; self-reported totals are shown separately, labelled as such.

import SwiftUI
import Charts

struct PortfolioView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    /// Shared with the Profile tab (injected by TabBarView or PortfolioDetailsSheet)
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel

    @State private var showAddTrade = false
    @State private var selectedTrade: Trade?
    @State private var chartRange: ChartRange = .all
    @State private var showAllClosed = false
    @State private var showLinkedAccounts = false

    /// Closed trades shown before "Show all"
    private let closedPreviewCount = 8

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    content
                        .redacted(reason: isFirstLoad ? .placeholder : [])
                        .allowsHitTesting(!isFirstLoad)
                        .padding(.horizontal, DS.pageMargin)
                        .padding(.bottom, DS.Spacing.xxl)
                }
            }
            .screenBackground()
            .statusBarBackground()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await portfolioViewModel.refreshPortfolio() }
            .navigationDestination(isPresented: $showLinkedAccounts) {
                LinkedAccountsView()
            }
        }
        .task { await portfolioViewModel.loadBrokerageHoldings() }
        .onChange(of: showLinkedAccounts) { _, isShowing in
            // Back from Linked brokerages: a sync or disconnect may have changed the holdings
            if !isShowing {
                Task { await portfolioViewModel.loadBrokerageHoldings() }
            }
        }
        .sheet(isPresented: $showAddTrade) {
            AddTradeView()
                .environmentObject(authService)
                .environmentObject(portfolioViewModel)
        }
        .sheet(item: $selectedTrade) { trade in
            TradeActionsSheet(trade: trade)
                .environmentObject(portfolioViewModel)
        }
        .sheet(isPresented: $portfolioViewModel.showStartingCapitalPrompt) {
            StartingCapitalSheet()
                .environmentObject(portfolioViewModel)
        }
        .sheet(isPresented: $portfolioViewModel.showDepositWithdrawSheet) {
            DepositWithdrawSheet()
                .environmentObject(portfolioViewModel)
        }
        .alert("Something went wrong", isPresented: $portfolioViewModel.showError) {
            Button("OK") { portfolioViewModel.showError = false }
        } message: {
            Text(portfolioViewModel.errorMessage)
        }
        .onAppear { portfolioViewModel.loadPortfolioData() }
    }

    /// True until the first batch of trades arrives, so we don't flash empty numbers
    private var isFirstLoad: Bool {
        portfolioViewModel.isLoading && portfolioViewModel.trades.isEmpty && portfolioViewModel.loadError == nil
    }

    // MARK: - Layout

    private var header: some View {
        ScreenHeader(title: "Portfolio") {
            HStack(spacing: DS.Spacing.s) {
                if AppConfig.brokerageLinkingEnabled {
                    IconButton(systemName: "building.columns", accessibilityLabel: "Connect brokerage") {
                        showLinkedAccounts = true
                    }
                }
                IconButton(systemName: "plus", accessibilityLabel: "Add trade", filled: true) {
                    showAddTrade = true
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: DS.Spacing.xl) {
            if let error = portfolioViewModel.loadError {
                loadErrorCard(error)
            }
            heroCard
            if portfolioViewModel.trades.isEmpty && portfolioViewModel.loadError != nil {
                EmptyView()
            } else if portfolioViewModel.trades.isEmpty && !isFirstLoad {
                emptyJournal
                holdingsSection
            } else {
                statsGrid
                openPositionsSection
                holdingsSection
                closedTradesSection
            }
        }
    }

    private func loadErrorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            IconWell(systemName: "exclamationmark.triangle.fill", tint: .marketRed, size: 36)
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Retry") { portfolioViewModel.retryLoading() }
                    .buttonStyle(PillButtonStyle(kind: .neutral))
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            accountValueBlock
            Divider().overlay(Color.hairline)
            chartBlock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    private var accountValueBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(alignment: .center) {
                Text("Account value")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: DS.Spacing.s)
                balanceButton
            }

            Text(portfolioValue.asCurrency)
                .arkadNumber(40)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.snappy, value: portfolioValue)

            VStack(alignment: .leading, spacing: 4) {
                ChangePill(text: totalPLText, isPositive: totalProfitLoss >= 0)
                    .lineLimit(1)
                    .fixedSize()
                Text(accountChangeCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var balanceButton: some View {
        Button {
            if startingCapital == nil {
                portfolioViewModel.showStartingCapitalPrompt = true
            } else {
                portfolioViewModel.showDepositWithdrawSheet = true
            }
        } label: {
            Label(startingCapital == nil ? "Set balance" : "Deposit / Withdraw",
                  systemImage: startingCapital == nil ? "banknote" : "arrow.left.arrow.right")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(PillButtonStyle(kind: .neutral))
    }

    /// The account value is a balance over every logged trade, so say when it includes self-reported ones
    private var accountChangeCaption: String {
        let base = startingCapital == nil ? "Realized" : "All time"
        return selfReported.tradeCount > 0 ? "\(base), including self-reported trades" : base
    }

    private var totalPLText: String {
        if let returnPercentage {
            return "\(totalProfitLoss.asCurrencyWithSign) (\(String(format: "%+.1f%%", returnPercentage)))"
        }
        return totalProfitLoss.asCurrencyWithSign
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartBlock: some View {
        if countedClosedTrades.isEmpty {
            chartEmptyState
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Performance")
                            .font(.headline)
                        Text("Realized P&L, price-checked & verified trades")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let last = pnlSeries.last {
                        Text("\(last.value.asCurrencyWithSign) \(chartRange.caption)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(last.value >= 0 ? Color.marketGreen : Color.marketRed)
                    }
                }

                if pnlSeries.count < 2 {
                    Text("No price-checked trades closed \(chartRange.caption)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    PnLChart(points: pnlSeries)
                        .frame(height: 180)
                        .transition(.opacity)
                }

                rangeChips
            }
        }
    }

    /// Nothing to chart yet: one compact line instead of an empty plot and range picker
    private var chartEmptyState: some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title3)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Performance")
                    .font(.subheadline.weight(.semibold))
                Text(closedTrades.isEmpty
                     ? "Close a price-checked trade to start your chart."
                     : "No price-checked closed trades yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var rangeChips: some View {
        HStack(spacing: DS.Spacing.s) {
            ForEach(ChartRange.allCases) { range in
                Chip(title: range.label, isSelected: chartRange == range) {
                    withAnimation(.snappy(duration: 0.25)) { chartRange = range }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Stats

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.m),
                                GridItem(.flexible(), spacing: DS.Spacing.m)],
                      spacing: DS.Spacing.m) {
                StatTile(
                    title: "Win rate",
                    value: checked.hasClosedTrades ? String(format: "%.0f%%", checked.winRate) : "–",
                    footnote: checked.hasClosedTrades
                        ? "\(checked.winCount) of \(checked.closedCount) won"
                        : "No price-checked trades"
                )
                StatTile(
                    title: "Realized P&L",
                    value: checked.hasClosedTrades ? checked.realizedPL.asCurrencyWithSign : "–",
                    valueColor: checked.hasClosedTrades ? (checked.realizedPL >= 0 ? .marketGreen : .marketRed) : .primary,
                    footnote: checked.hasClosedTrades
                        ? "\(checked.closedTodayPL.asCurrencyWithSign) closed today"
                        : "No price-checked trades"
                )
                StatTile(
                    title: "Open positions",
                    value: "\(openTrades.count)",
                    footnote: openTrades.isEmpty ? "Nothing open" : "\(openCostBasis.asCurrency) at cost"
                )
                StatTile(
                    title: "Best trade",
                    value: bestTrade?.profitLoss.asCurrencyWithSign ?? "–",
                    valueColor: bestTrade.map { $0.profitLoss >= 0 ? Color.marketGreen : Color.marketRed } ?? .primary,
                    footnote: bestTrade?.ticker ?? "No price-checked trades"
                )
            }

            Label("Win rate and P&L count only price-checked and verified trades.", systemImage: "checkmark.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if selfReported.tradeCount > 0 {
                selfReportedCard
            }
        }
    }

    /// Totals for self-reported trades, kept apart from the stats that count
    private var selfReportedCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                TradeProofBadge(proof: .selfReported)
                Spacer()
                Text("Not counted")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                selfReportedMetric("Trades", "\(selfReported.tradeCount)")
                selfReportedMetric(
                    "Realized P&L",
                    selfReported.hasClosedTrades ? selfReported.realizedPL.asCurrencyWithSign : "–"
                )
                selfReportedMetric(
                    "Win rate",
                    selfReported.hasClosedTrades ? String(format: "%.0f%%", selfReported.winRate) : "–"
                )
            }
            Text("Self-reported trades weren't logged at a checked market price, so they stay out of your win rate and P&L.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14, radius: DS.Radius.m)
    }

    private func selfReportedMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .arkadNumber(15, weight: .semibold)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Trade lists

    private var openPositionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Open positions", count: openTrades.count)
            if portfolioViewModel.quotesUnavailable && openTrades.contains(where: { $0.tradeType == .stock }) {
                Label("Live prices are unavailable right now. Pull to refresh in a minute.",
                      systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if openTrades.isEmpty {
                inlineEmpty(
                    icon: "tray",
                    text: "No open positions. Tap + to log a trade, then tap it later to close it."
                )
            } else {
                tradeList(openTrades)
            }
        }
    }

    private var closedTradesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(
                title: "Closed trades",
                count: closedTrades.count,
                actionTitle: closedTrades.count > closedPreviewCount ? (showAllClosed ? "Show less" : "Show all") : nil,
                action: { withAnimation(.snappy) { showAllClosed.toggle() } }
            )
            if closedTrades.isEmpty {
                inlineEmpty(
                    icon: "checkmark.circle",
                    text: "Trades you close show up here with their P&L."
                )
            } else {
                tradeList(showAllClosed ? closedTrades : Array(closedTrades.prefix(closedPreviewCount)))
            }
        }
    }

    private func tradeList(_ list: [Trade]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(list) { trade in
                Button { selectedTrade = trade } label: {
                    PortfolioTradeRow(trade: trade)
                }
                .buttonStyle(PressableStyle())
                if trade.id != list.last?.id {
                    Divider()
                        .overlay(Color.hairline)
                        .padding(.leading, 56)
                }
            }
        }
        .cardStyle(padding: 0)
    }

    private func inlineEmpty(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: icon, tint: .secondary, size: 32)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    @ViewBuilder
    private var holdingsSection: some View {
        if AppConfig.brokerageLinkingEnabled && !portfolioViewModel.brokerageHoldings.isEmpty {
            BrokerageHoldingsSection(holdings: portfolioViewModel.brokerageHoldings) {
                showLinkedAccounts = true
            }
        }
    }

    private var emptyJournal: some View {
        VStack(spacing: 0) {
            EmptyStateView(
                systemImage: "chart.line.uptrend.xyaxis",
                title: "Start your trading journal",
                message: "Log a stock, option, crypto or forex trade to track your P&L and win rate here.",
                actionTitle: "Add a trade",
                action: { showAddTrade = true }
            )
            if AppConfig.brokerageLinkingEnabled {
                Button("Or connect a brokerage") { showLinkedAccounts = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.goldText)
                    .padding(.top, -DS.Spacing.l)
                    .padding(.bottom, DS.Spacing.xl)
            }
        }
        .cardStyle(padding: 0)
    }

    // MARK: - Data

    private var portfolioValue: Double { portfolioViewModel.portfolio?.totalValue ?? 0 }
    /// Change in account value over every logged trade (labelled when that includes self-reported ones)
    private var totalProfitLoss: Double { portfolioViewModel.portfolio?.totalProfitLoss ?? 0 }
    private var startingCapital: Double? { portfolioViewModel.getUserStartingCapital() }
    /// Price-checked and verified trades: the numbers that count
    private var checked: TradeStats { portfolioViewModel.checkedStats }
    private var selfReported: TradeStats { portfolioViewModel.selfReportedStats }

    private var returnPercentage: Double? {
        guard let startingCapital, startingCapital > 0 else { return nil }
        return totalProfitLoss / startingCapital * 100
    }

    private var openTrades: [Trade] {
        portfolioViewModel.trades.filter(\.isOpen).sorted { $0.entryDate > $1.entryDate }
    }

    private var closedTrades: [Trade] {
        portfolioViewModel.trades.filter { !$0.isOpen }
            .sorted { ($0.exitDate ?? $0.entryDate) > ($1.exitDate ?? $1.entryDate) }
    }

    /// Closed price-checked and verified trades
    private var countedClosedTrades: [Trade] { closedTrades.filter(\.countsTowardStats) }
    private var openCostBasis: Double { openTrades.reduce(0) { $0 + $1.totalInvested } }

    private var bestTrade: Trade? {
        countedClosedTrades.max { $0.profitLoss < $1.profitLoss }
    }

    /// Running total of realized P&L from closed price-checked and verified trades, within the chosen range
    private var pnlSeries: [PnLPoint] {
        let closes = countedClosedTrades
            .map { (date: $0.exitDate ?? $0.entryDate, amount: $0.profitLoss) }
            .sorted { $0.date < $1.date }
        let start = chartRange.startDate
        let inRange = closes.filter { start == nil || $0.date >= start! }
        guard !inRange.isEmpty else { return [] }

        var running = closes.filter { start != nil && $0.date < start! }.reduce(0) { $0 + $1.amount }
        var points = [PnLPoint(date: start ?? inRange[0].date.addingTimeInterval(-3600), value: running)]
        for close in inRange {
            running += close.amount
            points.append(PnLPoint(date: close.date, value: running))
        }
        points.append(PnLPoint(date: Date(), value: running))
        return points
    }
}

// MARK: - Chart

private struct PnLChart: View {
    let points: [PnLPoint]

    private var lineColor: Color {
        (points.last?.value ?? 0) >= 0 ? .marketGreen : .marketRed
    }

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Date", point.date), y: .value("P&L", point.value))
                .foregroundStyle(lineColor.opacity(0.12))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Date", point.date), y: .value("P&L", point.value))
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(Color.secondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel()
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.hairline)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting types

private struct PnLPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private enum ChartRange: String, CaseIterable, Identifiable {
    case week, month, year, all
    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return "1W"
        case .month: return "1M"
        case .year: return "1Y"
        case .all: return "All"
        }
    }

    var caption: String {
        switch self {
        case .week: return "this week"
        case .month: return "this month"
        case .year: return "this year"
        case .all: return "all time"
        }
    }

    var startDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .week: return calendar.date(byAdding: .day, value: -7, to: Date())
        case .month: return calendar.date(byAdding: .month, value: -1, to: Date())
        case .year: return calendar.date(byAdding: .year, value: -1, to: Date())
        case .all: return nil
        }
    }
}

// MARK: - Trade row

/// One trade in the Portfolio list: ticker badge, size · entry · date on the left; value or P&L on the right
struct PortfolioTradeRow: View {
    let trade: Trade

    private var terms: AssetTerms { AssetTerms(trade.tradeType) }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            AssetTickerBadge(symbol: trade.ticker, type: trade.tradeType)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(trade.ticker)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    if trade.side == .short {
                        Text("Short")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.marketRed)
                    }
                    if trade.tradeType != .stock {
                        Text(trade.tradeType.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(terms.tint)
                    }
                    TradeProofBadge(proof: trade.proof, compact: true)
                    if trade.exitNotChecked {
                        Text("Exit not checked")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .layoutPriority(1)

            Spacer(minLength: DS.Spacing.s)

            trailing
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityHint: String {
        if trade.isImported { return "View this imported trade" }
        return trade.isOpen ? "Close, edit or delete this trade" : "Edit or delete this trade"
    }

    private var detailLine: String {
        let date = trade.exitDate ?? trade.entryDate
        return "\(terms.quantityText(trade.quantity, symbol: trade.ticker)) · \(terms.price(trade.entryPrice)) · \(AssetTerms.shortDate(date))"
    }

    @ViewBuilder
    private var trailing: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if trade.isOpen {
                Text(trade.currentValue.asCurrency)
                    .arkadNumber(15, weight: .semibold)
                    .foregroundStyle(Color.primary)
                if hasLivePrice {
                    Text(trade.unrealizedPL.asCurrencyWithSign)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(trade.unrealizedPL >= 0 ? Color.marketGreen : Color.marketRed)
                } else {
                    Text("At cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .arkadNumber(15, weight: .semibold)
                    .foregroundStyle(trade.profitLoss >= 0 ? Color.marketGreen : Color.marketRed)
                Text(String(format: "%+.1f%%", trade.profitLossPercentage))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Only stocks get live quotes; everything else is valued at entry price until closed
    private var hasLivePrice: Bool {
        guard terms.usesLiveQuotes, let current = trade.currentPrice, current > 0 else { return false }
        return current != trade.entryPrice
    }
}

/// Green "Verified" mark for trades imported from a linked brokerage.
/// Trade rows now use TradeProofBadge, which covers Verified too; kept for other callers.
struct VerifiedTradeBadge: View {
    /// Compact draws just the seal and a short label for list rows
    var compact = false

    var body: some View {
        if compact {
            HStack(spacing: 2) {
                Image(systemName: "checkmark.seal.fill")
                Text("Verified")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.marketGreen)
            .accessibilityElement(children: .combine)
        } else {
            Tag(text: "Verified", systemImage: "checkmark.seal.fill", tint: .marketGreen)
        }
    }
}

/// Rounded square with the symbol, tinted by asset type
struct AssetTickerBadge: View {
    let symbol: String
    let type: TradeType
    var size: CGFloat = 40

    var body: some View {
        let tint = AssetTerms(type).tint
        Text(AssetTerms.badgeText(for: symbol))
            .font(.system(size: size * 0.27, weight: .heavy, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 3)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Asset wording & formatting

/// Per-asset-type wording, input rules and formatting shared by the Portfolio screens.
struct AssetTerms {
    let type: TradeType

    init(_ type: TradeType) { self.type = type }

    // MARK: Appearance

    var tint: Color {
        switch type {
        case .stock: return .blue
        case .option: return .purple
        case .crypto: return .orange
        case .forex: return .teal
        }
    }

    var shortDescription: String {
        switch type {
        case .stock: return "Shares & ETFs"
        case .option: return "Calls & puts"
        case .crypto: return "Coins & tokens"
        case .forex: return "Currency pairs"
        }
    }

    /// Only stocks are priced live (Finnhub stock quotes)
    var usesLiveQuotes: Bool { type == .stock }

    // MARK: Symbol

    var symbolTitle: String {
        switch type {
        case .stock: return "Symbol"
        case .option: return "Underlying symbol"
        case .crypto: return "Coin"
        case .forex: return "Currency pair"
        }
    }

    var symbolPlaceholder: String {
        switch type {
        case .stock, .option: return "AAPL"
        case .crypto: return "BTC"
        case .forex: return "EUR/USD"
        }
    }

    // MARK: Quantity

    var quantityTitle: String {
        switch type {
        case .stock: return "Shares"
        case .option: return "Contracts"
        case .crypto: return "Amount"
        case .forex: return "Units"
        }
    }

    var quantityPlaceholder: String {
        switch type {
        case .stock: return "10"
        case .option: return "1"
        case .crypto: return "0.5"
        case .forex: return "10000"
        }
    }

    var allowsFractionalQuantity: Bool { type != .option }

    var quantityKeyboard: UIKeyboardType { allowsFractionalQuantity ? .decimalPad : .numberPad }

    /// "10 shares", "1 contract", "0.5 BTC", "10,000 units"
    func quantityText(_ quantity: Double, symbol: String) -> String {
        let amount = quantity.quantityString
        let isOne = quantity == 1
        switch type {
        case .stock: return "\(amount) \(isOne ? "share" : "shares")"
        case .option: return "\(amount) \(isOne ? "contract" : "contracts")"
        case .crypto: return symbol.isEmpty ? "\(amount) coins" : "\(amount) \(symbol.uppercased())"
        case .forex: return "\(amount) \(isOne ? "unit" : "units")"
        }
    }

    /// Parses quantity input; options must be whole contracts.
    func parseQuantity(_ text: String) -> Double? {
        guard let value = AssetTerms.parseNumber(text), value > 0 else { return nil }
        if !allowsFractionalQuantity && value.rounded() != value { return nil }
        return value
    }

    // MARK: Price

    var entryPriceTitle: String {
        switch type {
        case .stock: return "Price per share"
        case .option: return "Cost per contract"
        case .crypto: return "Price per coin"
        case .forex: return "Entry rate"
        }
    }

    var exitPriceTitle: String {
        switch type {
        case .stock: return "Exit price per share"
        case .option: return "Exit value per contract"
        case .crypto: return "Exit price per coin"
        case .forex: return "Exit rate"
        }
    }

    var pricePlaceholder: String {
        switch type {
        case .stock: return "150.00"
        case .option: return "550.00"
        case .crypto: return "65000"
        case .forex: return "1.0850"
        }
    }

    /// Forex rates are quoted in the pair's quote currency, so no "$"
    var pricePrefix: String? { type == .forex ? nil : "$" }

    /// Price with enough precision for the asset: $150.25, $0.000123, 1.0845
    func price(_ value: Double) -> String {
        if type == .forex {
            return value.formatted(.number.precision(.fractionLength(2...5)))
        }
        let maxDigits = abs(value) < 1 && value != 0 ? 6 : 2
        return value.formatted(.currency(code: "USD").precision(.fractionLength(2...maxDigits)))
    }

    // MARK: Validation copy

    var missingSymbolMessage: String {
        switch type {
        case .stock: return "Enter a symbol, like AAPL."
        case .option: return "Enter the underlying symbol, like AAPL."
        case .crypto: return "Enter a coin, like BTC."
        case .forex: return "Enter a currency pair, like EUR/USD."
        }
    }

    var missingQuantityMessage: String {
        switch type {
        case .stock: return "Enter the number of shares."
        case .option: return "Enter the number of contracts."
        case .crypto: return "Enter the amount you bought."
        case .forex: return "Enter the number of units."
        }
    }

    var invalidQuantityMessage: String {
        switch type {
        case .stock: return "Shares must be a number above 0."
        case .option: return "Contracts must be a whole number above 0."
        case .crypto: return "Amount must be a number above 0."
        case .forex: return "Units must be a number above 0."
        }
    }

    var missingPriceMessage: String {
        switch type {
        case .stock, .crypto: return "Enter the entry price."
        case .option: return "Enter the cost per contract."
        case .forex: return "Enter the entry rate."
        }
    }

    var invalidPriceMessage: String {
        type == .forex ? "Rate must be a number above 0." : "Price must be a number above 0."
    }

    // MARK: Shared helpers

    /// Up to four characters for a badge: "AAPL", "BTC", "EUR" (from EUR/USD)
    static func badgeText(for symbol: String) -> String {
        let base = symbol.split(separator: "/").first.map(String.init) ?? symbol
        return String(base.prefix(4)).uppercased()
    }

    /// The largest amount a typed number may have (prices, quantities, balances).
    static let maxTypedNumber: Double = 1_000_000_000_000

    /// Parses a typed number: digits with an optional leading "-", one decimal separator and
    /// optional grouping. Works with either "." or "," as the decimal mark (decimal pads type ","
    /// in many locales): when both appear the last one is the decimal mark; a lone mark is a
    /// thousands separator only when exactly three digits follow it and it isn't the device's
    /// decimal separator. Rejects anything else ("inf", "nan", "1e308", "12abc") and values
    /// above `maxTypedNumber`. Used by trade forms and callout sheets.
    static func parseNumber(_ text: String) -> Double? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isWhitespace && $0 != "\u{00A0}" && $0 != "\u{202F}" && $0 != "'" }
        var isNegative = false
        if cleaned.hasPrefix("-") || cleaned.hasPrefix("\u{2212}") {
            isNegative = true
            cleaned.removeFirst()
        }
        guard !cleaned.isEmpty, cleaned.count <= 24,
              cleaned.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "." || $0 == ",") }),
              cleaned.contains(where: \.isNumber) else { return nil }

        let localeDecimal: Character = Locale.current.decimalSeparator == "," ? "," : "."
        let marks = cleaned.filter { $0 == "." || $0 == "," }
        var decimalMark: Character?
        if Set(marks).count == 2 {
            decimalMark = marks.last
        } else if let mark = marks.first {
            if marks.count > 1 {
                decimalMark = nil  // "1,000,000": grouping only
            } else if mark == localeDecimal {
                decimalMark = mark
            } else {
                let digitsAfter = cleaned.split(separator: mark, omittingEmptySubsequences: false).last?.count ?? 0
                decimalMark = digitsAfter == 3 ? nil : mark
            }
        }

        // Grouping must look like real grouping: 1-3 digits, then groups of exactly 3
        // ("1,234,567"), only before the decimal mark. "1.2.3" or "12.34.5" is a typo, not 123.
        if let groupMark = marks.first(where: { $0 != decimalMark }) {
            let integerPart = decimalMark.flatMap { mark in cleaned.split(separator: mark, maxSplits: 1, omittingEmptySubsequences: false).first }
                .map(String.init) ?? cleaned
            let groups = integerPart.split(separator: groupMark, omittingEmptySubsequences: false)
            guard let first = groups.first, (1...3).contains(first.count),
                  groups.dropFirst().allSatisfy({ $0.count == 3 }) else { return nil }
        }

        var normalized = ""
        var seenDecimal = false
        for character in cleaned {
            if character == decimalMark {
                guard !seenDecimal else { return nil }
                seenDecimal = true
                normalized.append(".")
            } else if character.isNumber {
                normalized.append(character)
            } else if seenDecimal {
                return nil  // a grouping mark after the decimal mark
            }
            // anything else left is a grouping mark: dropped
        }
        if normalized.hasPrefix(".") { normalized = "0" + normalized }
        guard let value = Double(normalized), value.isFinite, value <= maxTypedNumber else { return nil }
        return isNegative ? -value : value
    }

    /// A number as the user would type it (no grouping, local decimal separator, no trailing zeros)
    static func inputString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "Mar 3", or "3/3/24" for other years (short enough for one-line trade rows)
    static func shortDate(_ date: Date) -> String {
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(.dateTime.month(.defaultDigits).day().year(.twoDigits))
    }
}

#Preview {
    PortfolioView()
        .environmentObject(FirebaseAuthService.shared)
        .environmentObject(PortfolioViewModel())
}
