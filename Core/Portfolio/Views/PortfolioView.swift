// File: Core/Portfolio/Views/PortfolioView.swift
// The Portfolio tab: account value, realized P&L chart, key stats, and your open and closed trades.
// Tap a trade to close, edit or delete it; "Add Trade" logs a new one.

import SwiftUI
import Charts

struct PortfolioView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var portfolioViewModel = PortfolioViewModel()

    @State private var showAddTrade = false
    @State private var selectedTrade: Trade?
    @State private var chartRange: ChartRange = .all
    @State private var tradeFilter: TradeListFilter = .open

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    chartCard
                    statsRow
                    tradesCard
                }
                .redacted(reason: isFirstLoad ? .placeholder : [])
                .allowsHitTesting(!isFirstLoad)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddTrade = true
                    } label: {
                        Label("Add Trade", systemImage: "plus")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.arkadGold))
                    }
                }
            }
            .refreshable { portfolioViewModel.refreshPortfolio() }
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
        portfolioViewModel.isLoading && portfolioViewModel.trades.isEmpty
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Account value")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    if startingCapital == nil {
                        portfolioViewModel.showStartingCapitalPrompt = true
                    } else {
                        portfolioViewModel.showDepositWithdrawSheet = true
                    }
                } label: {
                    Label(startingCapital == nil ? "Set balance" : "Deposit / Withdraw",
                          systemImage: "arrow.left.arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.arkadGoldDark)
                }
            }

            Text(portfolioValue.asCurrency)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(alignment: .top, spacing: 0) {
                summaryMetric(
                    title: "Total P&L",
                    value: totalProfitLoss.asCurrencyWithSign,
                    detail: returnPercentage.map { String(format: "%+.1f%%", $0) },
                    color: totalProfitLoss >= 0 ? .marketGreen : .marketRed
                )
                Divider().frame(height: 36).padding(.horizontal, 12)
                summaryMetric(
                    title: "Closed today",
                    value: summary.dayProfitLoss.asCurrencyWithSign,
                    detail: nil,
                    color: summary.dayProfitLoss >= 0 ? .marketGreen : .marketRed
                )
                Divider().frame(height: 36).padding(.horizontal, 12)
                summaryMetric(
                    title: "Open",
                    value: "\(openTrades.count)",
                    detail: openTrades.count == 1 ? "position" : "positions",
                    color: .primary
                )
            }
        }
        .padding(18)
        .cardBackground()
    }

    private func summaryMetric(title: String, value: String, detail: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Realized P&L")
                        .font(.headline)
                    if let last = pnlSeries.last {
                        Text(last.value.asCurrencyWithSign + " " + chartRange.caption)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            Picker("Range", selection: $chartRange) {
                ForEach(ChartRange.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            if pnlSeries.count < 2 {
                VStack(spacing: 6) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(closedTrades.isEmpty ? "Close a trade to start your chart" : "No closed trades \(chartRange.caption)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                let positive = (pnlSeries.last?.value ?? 0) >= 0
                let lineColor: Color = positive ? .marketGreen : .marketRed
                Chart(pnlSeries) { point in
                    AreaMark(x: .value("Date", point.date), y: .value("P&L", point.value))
                        .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.25), lineColor.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Date", point.date), y: .value("P&L", point.value))
                        .foregroundStyle(lineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(18)
        .cardBackground()
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(title: "Win rate", value: closedTrades.isEmpty ? "–" : String(format: "%.0f%%", winRate))
            statTile(title: "Closed trades", value: "\(closedTrades.count)")
            statTile(title: "Best trade", value: bestTrade?.profitLoss.asCurrencyWithSign ?? "–")
        }
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardBackground()
    }

    // MARK: - Trades

    private var tradesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trades")
                .font(.headline)

            Picker("Show", selection: $tradeFilter) {
                Text("Open (\(openTrades.count))").tag(TradeListFilter.open)
                Text("Closed (\(closedTrades.count))").tag(TradeListFilter.closed)
            }
            .pickerStyle(.segmented)

            let list = tradeFilter == .open ? openTrades : closedTrades
            if list.isEmpty {
                VStack(spacing: 10) {
                    Text(tradeFilter == .open ? "No open positions" : "No closed trades yet")
                        .font(.subheadline.weight(.semibold))
                    Text(tradeFilter == .open
                         ? "Log a trade to track it here. Tap it later to close it."
                         : "Trades you close show up here with their P&L.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    if tradeFilter == .open {
                        Button("Add Trade") { showAddTrade = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.arkadGold))
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(list) { trade in
                        Button { selectedTrade = trade } label: {
                            PortfolioTradeRow(trade: trade)
                        }
                        .buttonStyle(.plain)
                        if trade.id != list.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(18)
        .cardBackground()
    }

    // MARK: - Data

    private var summary: PortfolioSummary { portfolioViewModel.getPortfolioSummaryForProfile() }
    private var portfolioValue: Double { portfolioViewModel.portfolio?.totalValue ?? 0 }
    private var totalProfitLoss: Double { portfolioViewModel.portfolio?.totalProfitLoss ?? 0 }
    private var winRate: Double { portfolioViewModel.portfolio?.winRate ?? 0 }
    private var startingCapital: Double? { portfolioViewModel.getUserStartingCapital() }

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

    private var bestTrade: Trade? {
        closedTrades.max { $0.profitLoss < $1.profitLoss }
    }

    /// Running total of realized P&L from closed trades, within the chosen range
    private var pnlSeries: [PnLPoint] {
        let closes = closedTrades
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

// MARK: - Supporting types

private struct PnLPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private enum TradeListFilter { case open, closed }

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

/// One trade in the Portfolio list: ticker, size and entry on the left; value or P&L on the right
struct PortfolioTradeRow: View {
    let trade: Trade

    var body: some View {
        HStack(spacing: 12) {
            Text(String(trade.ticker.prefix(4)))
                .font(.caption.weight(.heavy))
                .foregroundColor(.arkadGoldDark)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.arkadGold.opacity(0.15)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(trade.ticker)
                        .font(.subheadline.weight(.bold))
                    if trade.tradeType != .stock {
                        Text(trade.tradeType.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
                Text("\(trade.quantity) @ \(trade.entryPrice.asCurrency) · \(dateText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                if trade.isOpen {
                    Text(trade.currentValue.asCurrency)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    if trade.unrealizedPL != 0 {
                        Text(trade.unrealizedPL.asCurrencyWithSign)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(trade.unrealizedPL >= 0 ? .marketGreen : .marketRed)
                    } else {
                        Text("Tap to close")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(trade.profitLoss.asCurrencyWithSign)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                    Text(String(format: "%+.1f%%", trade.profitLossPercentage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(trade.isOpen ? "Close, edit or delete this trade" : "Edit or delete this trade")
    }

    private var dateText: String {
        let date = trade.exitDate ?? trade.entryDate
        return date.formatted(.relative(presentation: .named))
    }
}

private extension View {
    func cardBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
}

#Preview {
    PortfolioView()
        .environmentObject(FirebaseAuthService.shared)
}
