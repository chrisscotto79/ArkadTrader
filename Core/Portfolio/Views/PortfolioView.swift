// File: Core/Portfolio/Views/PortfolioView.swift
// The Portfolio tab: account value with a line chart, linked brokerage holdings, your trading record,
// and your open and closed trades. Tap a trade to close, edit or delete it; the gold "+" logs a new one.
// With a linked brokerage (AppConfig.brokerageLinkingEnabled), the account value and chart are the
// brokerage's own; otherwise they're your starting balance plus logged trades.
// Every trade row shows its proof label. Win rate, realized P&L and best trade count only
// price-checked and verified trades; self-reported totals sit on one line underneath, labelled.

import SwiftUI
import Charts

struct PortfolioView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    /// Shared with the Profile tab (injected by TabBarView or PortfolioDetailsSheet)
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel

    @State private var showAddTrade = false
    @State private var selectedTrade: Trade?
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
            valueCard
            if portfolioViewModel.trades.isEmpty && portfolioViewModel.loadError != nil {
                EmptyView()
            } else if portfolioViewModel.trades.isEmpty && !isFirstLoad {
                holdingsSection
                emptyJournal
            } else {
                holdingsSection
                recordCard
                openPositionsSection
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

    // MARK: - Account value & chart

    private var valueCard: some View {
        AccountValueCard(
            currentValue: portfolioViewModel.accountValue,
            points: portfolioViewModel.accountValueSeries,
            source: valueSource,
            emptyChartMessage: emptyChartMessage
        ) {
            if let linked = portfolioViewModel.linkedAccount {
                Button {
                    showLinkedAccounts = true
                } label: {
                    Label(linked.title, systemImage: "building.columns")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .buttonStyle(PillButtonStyle(kind: .neutral))
                .accessibilityHint("Manage linked brokerages")
            } else {
                balanceButton
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

    /// Where the account value comes from, in one line under the chart
    private var valueSource: String {
        if let linked = portfolioViewModel.linkedAccount {
            var parts = ["From \(linked.title)"]
            if linked.cash != 0 { parts.append("\(linked.cash.asCurrency) cash") }
            if linked.syncPending {
                parts.append("still importing")
            } else if let synced = linked.lastSyncAt {
                parts.append("synced \(synced.formatted(.relative(presentation: .named)))")
            }
            return parts.joined(separator: " · ")
        }
        if startingCapital == nil { return "Open trades at today's prices" }
        return selfReported.tradeCount > 0
            ? "Your balance plus logged trades, including self-reported ones"
            : "Your balance plus logged trades"
    }

    /// Why there's no line yet
    private var emptyChartMessage: String {
        if let linked = portfolioViewModel.linkedAccount {
            return "Your chart starts today. Arkad adds a point each day \(linked.title) syncs."
        }
        if startingCapital == nil { return "Set a starting balance to chart your account value." }
        return "Log a trade to start your chart."
    }

    // MARK: - Trading record

    /// Win rate, realized P&L and best trade from price-checked and verified trades, with
    /// self-reported totals on one line underneath
    private var recordCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Trading record")
                    .font(.headline)
                Spacer(minLength: DS.Spacing.s)
                Label("Price-checked & verified", systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if checked.hasClosedTrades {
                HStack(alignment: .top, spacing: DS.Spacing.m) {
                    recordMetric(
                        "Win rate",
                        String(format: "%.0f%%", checked.winRate),
                        detail: "\(checked.winCount) of \(checked.closedCount) won"
                    )
                    recordMetric(
                        "Realized P&L",
                        checked.realizedPL.asCurrencyWithSign,
                        color: checked.realizedPL >= 0 ? .marketGreen : .marketRed,
                        detail: "\(checked.closedTodayPL.asCurrencyWithSign) today"
                    )
                    recordMetric(
                        "Best trade",
                        bestTrade?.profitLoss.asCurrencyWithSign ?? "–",
                        color: bestTrade.map { $0.profitLoss >= 0 ? Color.marketGreen : Color.marketRed } ?? .primary,
                        detail: bestTrade?.ticker ?? " "
                    )
                }
            } else {
                Text("Close a price-checked trade to see your win rate and P&L.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if selfReported.tradeCount > 0 {
                Divider().overlay(Color.hairline)
                HStack(spacing: DS.Spacing.s) {
                    TradeProofBadge(proof: .selfReported, compact: true)
                    Text(selfReportedSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// "2 trades · +$24.00 realized · not counted"
    private var selfReportedSummary: String {
        var parts = ["\(selfReported.tradeCount) \(selfReported.tradeCount == 1 ? "trade" : "trades")"]
        if selfReported.hasClosedTrades {
            parts.append("\(selfReported.realizedPL.asCurrencyWithSign) realized")
        }
        parts.append("not counted")
        return parts.joined(separator: " · ")
    }

    private func recordMetric(_ title: String, _ value: String, color: Color = .primary, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .arkadNumber(18, weight: .semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Trade lists

    private var openPositionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Open trades", count: openTrades.count)
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
                    text: "No open trades. Tap + to log one, then tap it later to close it."
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
        if AppConfig.brokerageLinkingEnabled,
           !portfolioViewModel.brokerageHoldings.isEmpty || portfolioViewModel.linkedAccount != nil {
            BrokerageHoldingsSection(
                holdings: portfolioViewModel.brokerageHoldings,
                title: portfolioViewModel.linkedAccount.map { "\($0.title) holdings" } ?? "Brokerage holdings",
                emptyMessage: holdingsEmptyMessage
            ) {
                showLinkedAccounts = true
            }
        }
    }

    /// Shown in the holdings section when a linked brokerage has no positions
    private var holdingsEmptyMessage: String {
        guard let linked = portfolioViewModel.linkedAccount else { return "No holdings." }
        if linked.syncPending {
            return "\(linked.title) is still sending your holdings. Pull to refresh in a few minutes."
        }
        return "No stocks, ETFs, options or crypto in your \(linked.title) account."
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
            if AppConfig.brokerageLinkingEnabled && portfolioViewModel.linkedAccount == nil {
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

    private var startingCapital: Double? { portfolioViewModel.getUserStartingCapital() }
    /// Price-checked and verified trades: the numbers that count
    private var checked: TradeStats { portfolioViewModel.checkedStats }
    private var selfReported: TradeStats { portfolioViewModel.selfReportedStats }

    private var openTrades: [Trade] {
        portfolioViewModel.trades.filter(\.isOpen).sorted { $0.entryDate > $1.entryDate }
    }

    private var closedTrades: [Trade] {
        portfolioViewModel.trades.filter { !$0.isOpen }
            .sorted { ($0.exitDate ?? $0.entryDate) > ($1.exitDate ?? $1.entryDate) }
    }

    private var bestTrade: Trade? {
        closedTrades.filter(\.countsTowardStats).max { $0.profitLoss < $1.profitLoss }
    }
}

// MARK: - Account value card

/// The top of Portfolio: account value, its change over the chosen range, and a line chart.
/// Drag across the chart to read the value on any day; the big number follows your finger.
private struct AccountValueCard<Accessory: View>: View {
    let currentValue: Double
    /// Oldest first, ending now
    let points: [AccountValuePoint]
    let source: String
    let emptyChartMessage: String
    @ViewBuilder let accessory: () -> Accessory

    @State private var range: ChartRange = .month
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .center) {
                Text("Account value")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: DS.Spacing.s)
                accessory()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(displayedValue.asCurrency)
                    .arkadNumber(44)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: displayedValue)

                if hasChart {
                    changeLine
                }
            }

            if hasChart {
                chart
                    .frame(height: 180)
                    .padding(.horizontal, -4)
                rangePicker
            } else {
                Label(emptyChartMessage, systemImage: "chart.xyaxis.line")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, DS.Spacing.s)
            }

            Text(source)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    // MARK: Header numbers

    /// "▲ +$12.40 (+1.3%) Past month", or the scrubbed day
    private var changeLine: some View {
        let change = displayedValue - baseline
        let isUp = change >= 0
        return HStack(spacing: 4) {
            Image(systemName: isUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 9))
            Text(changeText(change))
                .monospacedDigit()
            Text(selectedPoint.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? range.caption)
                .foregroundStyle(Color.secondary)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isUp ? Color.marketGreen : Color.marketRed)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .combine)
    }

    private func changeText(_ change: Double) -> String {
        guard baseline != 0 else { return change.asCurrencyWithSign }
        return "\(change.asCurrencyWithSign) (\(String(format: "%+.1f%%", change / abs(baseline) * 100)))"
    }

    private var displayedValue: Double { selectedPoint?.value ?? currentValue }

    // MARK: Chart

    private var chart: some View {
        let color = (currentValue - baseline) >= 0 ? Color.marketGreen : Color.marketRed
        return Chart {
            ForEach(Array(plotted.enumerated()), id: \.offset) { _, point in
                AreaMark(x: .value("Date", point.date), yStart: .value("Floor", yDomain.lowerBound), yEnd: .value("Value", point.value))
                    .foregroundStyle(
                        LinearGradient(colors: [color.opacity(0.18), color.opacity(0)], startPoint: .top, endPoint: .bottom)
                    )
                LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            // Where the range started, so up and down read at a glance
            RuleMark(y: .value("Start", baseline))
                .foregroundStyle(Color.secondary.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
            if let selectedPoint {
                RuleMark(x: .value("Selected", selectedPoint.date))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Date", selectedPoint.date), y: .value("Value", selectedPoint.value))
                    .symbolSize(70)
                    .foregroundStyle(color)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: xLabelFormat)
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartXSelection(value: $selectedDate)
        .sensoryFeedback(.selection, trigger: selectedPoint?.date)
        .accessibilityLabel("Account value, \(range.caption.lowercased())")
        .accessibilityValue("From \(baseline.asCurrency) to \(currentValue.asCurrency)")
    }

    private var rangePicker: some View {
        HStack(spacing: DS.Spacing.s) {
            ForEach(ChartRange.allCases) { option in
                Chip(title: option.label, isSelected: range == option) {
                    withAnimation(.snappy(duration: 0.25)) {
                        range = option
                        selectedDate = nil
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Data

    /// A line needs two different days
    private var hasChart: Bool {
        guard let first = points.first, let last = points.last else { return false }
        return !Calendar.current.isDate(first.date, inSameDayAs: last.date)
    }

    private var rangeStart: Date {
        range.startDate.map { max($0, points.first?.date ?? $0) } ?? (points.first?.date ?? Date())
    }

    /// The value when the range began: the last value on or before its start
    private var baseline: Double {
        points.last(where: { $0.date <= rangeStart })?.value ?? points.first?.value ?? currentValue
    }

    /// Points inside the range, starting with the baseline at the range's first moment
    private var plotted: [AccountValuePoint] {
        let inside = points.filter { $0.date > rangeStart }
        return [AccountValuePoint(date: rangeStart, value: baseline)] + inside
    }

    private var xDomain: ClosedRange<Date> {
        let end = max(plotted.last?.date ?? Date(), rangeStart.addingTimeInterval(60))
        return rangeStart...end
    }

    /// Padded so a flat line sits in the middle instead of on an edge
    private var yDomain: ClosedRange<Double> {
        let values = plotted.map(\.value) + [baseline]
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let pad = max((high - low) * 0.12, max(abs(high) * 0.01, 1))
        return (low - pad)...(high + pad)
    }

    /// The value at the scrubbed date: the last recorded value on or before it
    private var selectedPoint: AccountValuePoint? {
        guard let selectedDate else { return nil }
        return plotted.last(where: { $0.date <= selectedDate }) ?? plotted.first
    }

    private var xLabelFormat: Date.FormatStyle {
        switch range {
        case .week, .month, .threeMonths: return .dateTime.month(.abbreviated).day()
        case .year, .all: return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }
}

// MARK: - Supporting types

private enum ChartRange: String, CaseIterable, Identifiable {
    case week, month, threeMonths, year, all
    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: return "1W"
        case .month: return "1M"
        case .threeMonths: return "3M"
        case .year: return "1Y"
        case .all: return "All"
        }
    }

    var caption: String {
        switch self {
        case .week: return "Past week"
        case .month: return "Past month"
        case .threeMonths: return "Past 3 months"
        case .year: return "Past year"
        case .all: return "All time"
        }
    }

    var startDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .week: return calendar.date(byAdding: .day, value: -7, to: Date())
        case .month: return calendar.date(byAdding: .month, value: -1, to: Date())
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: Date())
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
