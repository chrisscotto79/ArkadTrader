// File: Core/Portfolio/ViewModels/PortfolioViewModel.swift
// Portfolio state: the user's trades, account value and stats, plus live stock quotes.
// One instance for the whole app: TabBarView creates it and injects it as an environment object,
// so Portfolio and Profile share one trades listener and one quote timer.
// Only stock positions are priced live; options, crypto and forex are valued at entry price until closed.
// Proof labels: win rate, P&L and performance count only price-checked and verified trades
// (`checkedStats`). Self-reported trades still appear in the portfolio and in the account value,
// and their totals are kept apart in `selfReportedStats`. The public numbers on the user's
// profile document come from `TradeStats.publicRecord` (public, closed, counted, realized only).

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class PortfolioViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var trades: [Trade] = []
    @Published private(set) var portfolio: Portfolio?
    @Published private(set) var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    /// Set when the trades listener failed. The Portfolio shows it with a Retry button.
    @Published private(set) var loadError: String?
    /// True when the last quote refresh got no prices because Finnhub was rate limited or offline
    @Published private(set) var quotesUnavailable = false

    // UI State
    @Published var showDepositWithdrawSheet = false
    @Published var showStartingCapitalPrompt = false
    @Published private(set) var lastUpdated: Date = Date()

    /// Holdings synced from linked brokerages (read-only, written by the server)
    @Published var brokerageHoldings: [BrokerageHolding] = []
    /// Linked brokerages. When any has synced, the account value is theirs instead of the
    /// manual balance (`linkedAccount`).
    @Published private(set) var brokerageConnections: [BrokerageConnection] = []

    /// The linked brokerages' total, or nil when none is linked (or none has synced yet)
    var linkedAccount: LinkedAccountSummary? {
        guard AppConfig.brokerageLinkingEnabled else { return nil }
        return LinkedAccountSummary(connections: brokerageConnections)
    }

    /// The account value shown at the top of Portfolio: the linked brokerages' total, or the
    /// manual balance plus logged trades
    var accountValue: Double {
        linkedAccount?.totalValue ?? portfolio?.totalValue ?? 0
    }

    /// Account value over time for the Portfolio chart, oldest first, ending now.
    /// - Linked brokerage: the daily values the Worker records on each sync.
    /// - Manual: the starting balance plus each closed trade's P&L as of its close date (open
    ///   trades count at cost until today's point). Deposits and withdrawals aren't dated, so
    ///   the current balance is used throughout. Empty without a starting balance.
    var accountValueSeries: [AccountValuePoint] {
        if let linked = linkedAccount {
            var points = linked.history
            if let last = points.last, Calendar.current.isDateInToday(last.date) {
                points.removeLast()
            }
            points.append(AccountValuePoint(date: Date(), value: linked.totalValue))
            return points
        }
        guard let startingCapital, let firstEntry = trades.map(\.entryDate).min() else { return [] }
        let closes = trades.filter { !$0.isOpen }
            .map { (date: $0.exitDate ?? $0.entryDate, amount: $0.profitLoss) }
            .sorted { $0.date < $1.date }
        var running = startingCapital
        var points = [AccountValuePoint(date: min(firstEntry, closes.first?.date ?? firstEntry), value: running)]
        for close in closes {
            running += close.amount
            points.append(AccountValuePoint(date: close.date, value: running))
        }
        points.append(AccountValuePoint(date: max(Date(), points.last?.date ?? Date()), value: accountValue))
        return points
    }

    /// Win rate and P&L from price-checked and verified trades: the numbers that count
    @Published private(set) var checkedStats = TradeStats(trades: [])
    /// The same totals for self-reported trades, shown separately and labelled "Self-reported"
    @Published private(set) var selfReportedStats = TradeStats(trades: [])

    /// The account's starting balance (owner-only users/{uid}/private/profile), nil until set
    @Published private(set) var startingCapital: Double?

    // Private Properties
    let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var tradesListener: ListenerRegistration?
    /// The user the listener (and everything above) belongs to
    private var listeningUserId: String?
    private var hasLoadedStartingCapital = false
    private var quoteTimer: Timer?
    /// Latest market price per symbol, kept in memory only (never written to Firestore)
    private var latestQuotes: [String: Double] = [:]
    /// The public stats last written to the user document, to skip writes that change nothing
    private var publishedStats: (profitLoss: Double, winRate: Double)?

    /// How often open stock positions are re-priced while the app is open
    private static let quoteRefreshInterval: TimeInterval = 60

    // MARK: - Initialization
    init() {
        observeUserChanges()
        loadPortfolioData()
        quoteTimer = Timer.scheduledTimer(withTimeInterval: Self.quoteRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshQuotes() }
        }
    }

    deinit {
        quoteTimer?.invalidate()
        tradesListener?.remove()
    }

    /// Follows sign-in, sign-out and account switches. Profile edits only recompute the numbers.
    private func observeUserChanges() {
        authService.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] userId in
                guard let self else { return }
                if userId != self.listeningUserId {
                    self.resetForUserChange()
                    self.loadPortfolioData()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Loading

    /// Starts listening to the signed-in user's trades. Safe to call repeatedly: it does nothing
    /// while a listener for the same user is running.
    func loadPortfolioData() {
        guard let userId = authService.currentUser?.id else {
            resetForUserChange()
            return
        }
        guard tradesListener == nil || listeningUserId != userId else { return }

        stopListening()
        listeningUserId = userId
        isLoading = true
        loadError = nil
        loadStartingCapital(userId: userId)

        tradesListener = FirebaseServices.shared.listenToUserTrades(userId: userId) { [weak self] result in
            Task { @MainActor in self?.handleTrades(result, userId: userId) }
        }
    }

    /// Retry after the trades listener failed.
    func retryLoading() {
        stopListening()
        loadPortfolioData()
    }

    private func handleTrades(_ result: Result<[Trade], Error>, userId: String) {
        guard userId == listeningUserId else { return }
        switch result {
        case .success(let newTrades):
            trades = newTrades
            loadError = nil
            isLoading = false
            applyLatestQuotes()
            recalculate()
            updateUserProfileStats()
            lastUpdated = Date()
            checkForStartingCapitalPrompt()
            Task { await refreshQuotes(onlyMissing: true) }
        case .failure:
            // A failed listener is finished: drop it so Retry can start a new one
            tradesListener?.remove()
            tradesListener = nil
            isLoading = false
            loadError = "Couldn't load your trades. Check your connection and try again."
        }
    }

    private func stopListening() {
        tradesListener?.remove()
        tradesListener = nil
    }

    /// Sign-out or another account: forget everything that belonged to the previous user.
    private func resetForUserChange() {
        stopListening()
        listeningUserId = nil
        trades = []
        portfolio = nil
        isLoading = false
        loadError = nil
        quotesUnavailable = false
        startingCapital = nil
        hasLoadedStartingCapital = false
        latestQuotes = [:]
        publishedStats = nil
        brokerageHoldings = []
        brokerageConnections = []
        showStartingCapitalPrompt = false
        showDepositWithdrawSheet = false
        checkedStats = TradeStats(trades: [])
        selfReportedStats = TradeStats(trades: [])
    }

    /// Pull to refresh: the trades are live already, so this re-prices open positions (and restarts
    /// the listener if it had failed). Returns when the quotes are in.
    func refreshPortfolio() async {
        if loadError != nil { retryLoading() }
        await refreshQuotes()
        await loadBrokerageHoldings()
    }

    // MARK: - Starting Capital

    func getUserStartingCapital() -> Double? { startingCapital }

    /// Reads users/{uid}/private/profile.startingCapital, falling back to the old public
    /// users/{uid}.startingCapital for accounts not moved yet, then legacy UserDefaults.
    private func loadStartingCapital(userId: String) {
        hasLoadedStartingCapital = false
        Task {
            var value: Double?
            let privateProfile = try? await FirebaseServices.shared.db
                .collection("users").document(userId)
                .collection("private").document("profile")
                .getDocument()
            if let stored = (privateProfile?.data()?["startingCapital"] as? NSNumber)?.doubleValue, stored > 0 {
                value = stored
            } else if let legacy = authService.currentUser?.startingCapital, legacy > 0 {
                value = legacy
            }
            guard userId == listeningUserId else { return }
            if value == nil, let legacy = migrateLegacyStartingCapital(userId: userId) {
                value = legacy
            }
            startingCapital = value
            hasLoadedStartingCapital = true
            recalculate()
            checkForStartingCapitalPrompt()
        }
    }

    /// Very old builds kept the balance in UserDefaults. Saves it to the account once.
    private func migrateLegacyStartingCapital(userId: String) -> Double? {
        let key = "starting_capital_\(userId)"
        guard let legacy = UserDefaults.standard.object(forKey: key) as? Double, legacy > 0 else { return nil }
        Task {
            if (try? await authService.updateCurrentUserStartingCapital(legacy)) != nil {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        return legacy
    }

    /// Asks for a starting balance once per user, after their first trade. Skipping is remembered.
    private func checkForStartingCapitalPrompt() {
        guard let userId = listeningUserId, hasLoadedStartingCapital,
              startingCapital == nil, !trades.isEmpty else { return }
        let key = "starting_capital_prompted_\(userId)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        showStartingCapitalPrompt = true
    }

    // MARK: - Account Value Management (Deposit/Withdraw)

    func depositFunds(_ amount: Double) {
        guard let currentCapital = startingCapital else {
            setUserStartingCapital(amount)
            return
        }
        updateStartingCapital(currentCapital + amount, actionDescription: "deposit")
    }

    func withdrawFunds(_ amount: Double) {
        guard let currentCapital = startingCapital else {
            showErrorMessage("Set your starting balance first.")
            return
        }
        guard amount <= currentCapital else {
            showErrorMessage("You can withdraw up to \(currentCapital.asCurrency).")
            return
        }
        updateStartingCapital(max(0, currentCapital - amount), actionDescription: "withdraw")
    }

    func setUserStartingCapital(_ amount: Double) {
        updateStartingCapital(amount, actionDescription: "set your balance") { [weak self] in
            self?.showStartingCapitalPrompt = false
        }
    }

    private func updateStartingCapital(_ newAmount: Double, actionDescription: String,
                                       onSuccess: (() -> Void)? = nil) {
        guard newAmount.isFinite, newAmount >= 0 else { return }
        Task {
            do {
                try await authService.updateCurrentUserStartingCapital(newAmount)
                startingCapital = newAmount > 0 ? newAmount : nil
                recalculate()
                showDepositWithdrawSheet = false
                onSuccess?()
            } catch {
                showErrorMessage("Couldn't \(actionDescription). \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Portfolio Calculations

    private func recalculate() {
        checkedStats = TradeStats(counted: trades)
        selfReportedStats = TradeStats(selfReported: trades)
        calculatePortfolioMetrics()
    }

    private func calculatePortfolioMetrics() {
        guard let userId = listeningUserId else {
            portfolio = nil
            return
        }
        let openTrades = trades.filter(\.isOpen)
        let closedTrades = trades.filter { !$0.isOpen }
        let realizedPL = closedTrades.reduce(0) { $0 + $1.profitLoss }
        let openValue = openTrades.reduce(0) { $0 + $1.currentValue }

        var newPortfolio = Portfolio(userId: userId)
        if let startingCapital {
            // Cash = starting balance + realized P&L - money in open positions
            let invested = openTrades.reduce(0) { $0 + $1.totalInvested }
            let cash = startingCapital + realizedPL - invested
            newPortfolio.totalValue = cash + openValue
            newPortfolio.totalProfitLoss = newPortfolio.totalValue - startingCapital
        } else {
            newPortfolio.totalValue = openValue
            newPortfolio.totalProfitLoss = realizedPL
        }
        newPortfolio.dayProfitLoss = checkedStats.closedTodayPL
        newPortfolio.totalTrades = trades.count
        newPortfolio.openPositions = openTrades.count
        newPortfolio.winRate = checkedStats.winRate
        newPortfolio.lastUpdated = Date()
        portfolio = newPortfolio
    }

    /// The P&L and win rate on the user's profile document (shown to others, used by search and
    /// leaderboards): `TradeStats.publicRecord`, so public, closed, price-checked or verified trades,
    /// realized P&L only. Writes only when a value actually changed.
    private func updateUserProfileStats() {
        guard let user = authService.currentUser, user.id == listeningUserId else { return }
        let stats = TradeStats.publicRecord(trades)
        let profitLoss = (stats.realizedPL * 100).rounded() / 100
        let winRate = (stats.winRate * 100).rounded() / 100
        let previous = publishedStats ?? (user.totalProfitLoss, user.winRate)
        guard abs(previous.profitLoss - profitLoss) >= 0.005 || abs(previous.winRate - winRate) >= 0.005 else {
            publishedStats = previous
            return
        }
        publishedStats = (profitLoss, winRate)
        Task {
            do {
                try await authService.updateUserStats(userId: user.id, totalProfitLoss: profitLoss, winRate: winRate)
            } catch {
                // Try again on the next change
                publishedStats = nil
            }
        }
    }

    // MARK: - Trade Management

    /// Logs a new trade. The listener picks it up, so nothing else needs reloading.
    func addTrade(_ trade: Trade) async throws {
        try await FirebaseServices.shared.addTrade(trade)
    }

    /// Closes an open trade. The exit gets its own proof (`exitOutcome`: price-checked only when
    /// closed just now within 1% of the live price). The trade's `proof` never changes: a
    /// price-checked trade with an unchecked exit keeps counting and is flagged "Exit not checked".
    /// The exit is final: the rules don't let a closed trade's exit change, or the trade reopen.
    @discardableResult
    func closeTrade(_ trade: Trade, exitPrice: Double, exitDate: Date,
                    exitOutcome: PriceCheckOutcome, notes: String?) async throws -> Trade {
        guard trade.isOpen else { throw PortfolioError.tradeAlreadyClosed }

        var closed = trade
        closed.close(at: exitPrice, on: exitDate)
        closed.exitProof = exitOutcome.proof == .priceChecked ? .priceChecked : .selfReported
        closed.notes = notes
        closed.exitLoggedAt = nil  // set by the server

        do {
            try await FirebaseServices.shared.closeTrade(closed)
        } catch {
            showErrorMessage("Couldn't close the trade. \(error.localizedDescription)")
            throw error
        }

        if let index = trades.firstIndex(where: { $0.id == closed.id }) {
            trades[index] = closed
        }
        recalculate()
        updateUserProfileStats()
        return closed
    }

    /// Saves the parts of a trade that may change after logging: notes, strategy, tags, stop,
    /// target, sector and visibility. Ticker, type, side, entry price, quantity and dates are locked.
    func updateTrade(_ updatedTrade: Trade) async throws {
        do {
            try await FirebaseServices.shared.updateTrade(updatedTrade)
        } catch {
            showErrorMessage("Couldn't update the trade. \(error.localizedDescription)")
            throw error
        }
        if let index = trades.firstIndex(where: { $0.id == updatedTrade.id }) {
            var saved = updatedTrade
            saved.currentPrice = trades[index].currentPrice
            trades[index] = saved
            recalculate()
            updateUserProfileStats()
        }
    }

    /// Price-checked trades can be deleted only within 15 minutes of logging (`Trade.canDelete`).
    func deleteTrade(_ trade: Trade) async throws {
        guard trade.canDelete() else {
            throw PortfolioError.deleteWindowPassed
        }
        do {
            try await FirebaseServices.shared.deleteTrade(tradeId: trade.id)
        } catch {
            showErrorMessage("Couldn't delete the trade. \(error.localizedDescription)")
            throw error
        }
        trades.removeAll { $0.id == trade.id }
        recalculate()
        updateUserProfileStats()
    }

    /// The latest copy of a trade (the trade sheet uses it to stay in sync with the listener).
    func trade(withId id: String) -> Trade? {
        trades.first { $0.id == id }
    }

    // MARK: - Quotes

    /// Re-prices open stock positions through QuoteClient (shared Finnhub budget, 30 s cache).
    /// `onlyMissing` asks only for symbols without a price yet (after the trades change).
    func refreshQuotes(onlyMissing: Bool = false) async {
        var symbols = Set(trades.filter { $0.isOpen && $0.tradeType == .stock }
            .map { TradePriceCheckRules.symbol(for: $0.ticker) })
        if onlyMissing { symbols.subtract(latestQuotes.keys) }
        guard !symbols.isEmpty, QuoteClient.isConfigured else {
            if !onlyMissing { quotesUnavailable = false }
            return
        }
        let results = await QuoteClient.shared.quotes(for: symbols)
        var changed = false
        for (symbol, result) in results {
            if let quote = result.quote {
                latestQuotes[symbol] = quote.current
                changed = true
            }
        }
        quotesUnavailable = results.allTemporarilyUnavailable
        if changed {
            applyLatestQuotes()
            recalculate()
            lastUpdated = Date()
        }
    }

    /// Applies cached quotes to open stock positions. Other asset types have no quote source,
    /// so any stored price is cleared and they're valued at entry price (no unrealized P&L).
    private func applyLatestQuotes() {
        for index in trades.indices where trades[index].isOpen {
            guard trades[index].tradeType == .stock else {
                trades[index].currentPrice = nil
                continue
            }
            if let price = latestQuotes[TradePriceCheckRules.symbol(for: trades[index].ticker)] {
                trades[index].currentPrice = price
            }
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Brokerage

    /// Reads users/{uid}/brokerageConnections and brokerageHoldings. Once a linked brokerage has
    /// synced, the Portfolio's account value comes from it (`linkedAccount`).
    /// Does nothing while brokerage linking is off (free mode).
    func loadBrokerageHoldings() async {
        guard AppConfig.brokerageLinkingEnabled, let userId = authService.currentUser?.id else {
            brokerageHoldings = []
            brokerageConnections = []
            return
        }
        // Keep what we have if a read fails (offline); there's nothing the user can fix here
        async let holdings = try? BrokerageService.holdings(userId: userId)
        async let connections = try? BrokerageService.connections(userId: userId)
        if let holdings = await holdings { brokerageHoldings = holdings }
        if let connections = await connections { brokerageConnections = connections }
    }

    // MARK: - Profile

    /// Profile numbers. P&L, today's P&L, win rate and the top performer come from price-checked
    /// and verified trades only, realized P&L only; counts and recent trades include everything
    /// (each row is labelled).
    func getPortfolioSummaryForProfile() -> PortfolioSummary {
        let stats = checkedStats
        return PortfolioSummary(
            totalValue: portfolio?.totalValue ?? 0,
            totalProfitLoss: stats.realizedPL,
            dayProfitLoss: stats.closedTodayPL,
            winRate: stats.winRate,
            totalTrades: trades.count,
            openPositions: trades.filter(\.isOpen).count,
            recentTrades: Array(trades.prefix(5)),
            topPerformer: trades.filter { !$0.isOpen && $0.countsTowardStats }.max { $0.profitLoss < $1.profitLoss },
            lastUpdated: lastUpdated,
            countedClosedTrades: stats.closedCount,
            selfReportedTrades: selfReportedStats.tradeCount
        )
    }
}

// MARK: - Supporting Models

struct PortfolioSummary {
    let totalValue: Double
    let totalProfitLoss: Double
    let dayProfitLoss: Double
    let winRate: Double
    let totalTrades: Int
    let openPositions: Int
    let recentTrades: [Trade]
    let topPerformer: Trade?
    let lastUpdated: Date
    /// Closed price-checked / verified trades behind `winRate` (0 means there's no win rate to show)
    var countedClosedTrades: Int = 0
    /// Trades left out of the P&L and win rate because they're self-reported
    var selfReportedTrades: Int = 0
}

// MARK: - Portfolio Error Types
enum PortfolioError: LocalizedError {
    case tradeAlreadyClosed
    case deleteWindowPassed

    var errorDescription: String? {
        switch self {
        case .tradeAlreadyClosed:
            return "This trade is already closed."
        case .deleteWindowPassed:
            return "Price-checked trades can only be deleted within 15 minutes of logging them."
        }
    }
}

// MARK: - Deposit / withdraw sheet

/// Adjusts the account balance used to compute account value and returns.
struct DepositWithdrawSheet: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedAction: FundAction = .deposit
    @State private var amountInput = ""
    @FocusState private var isInputFocused: Bool

    enum FundAction: CaseIterable {
        case deposit, withdraw

        var title: String {
            switch self {
            case .deposit: return "Deposit"
            case .withdraw: return "Withdraw"
            }
        }
    }

    private let quickAmounts: [Double] = [100, 500, 1_000, 5_000, 10_000, 25_000]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    SegmentedPicker(options: FundAction.allCases, selection: $selectedAction) { $0.title }
                    amountCard
                    quickAmountChips
                    Text("This only changes the balance Arkad uses to track your account value and returns. No money is moved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { confirmBar }
            .screenBackground()
            .navigationTitle("Adjust balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.primary)
                }
            }
            .onAppear { isInputFocused = true }
        }
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            if currentBalance > 0 {
                HStack {
                    Text("Current balance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currentBalance.asCurrency)
                        .arkadNumber(17, weight: .semibold)
                }
                Divider().overlay(Color.hairline)
            }
            Text("\(selectedAction.title) amount")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("$")
                    .arkadNumber(34)
                    .foregroundStyle(.secondary)
                TextField("0", text: $amountInput)
                    .keyboardType(.decimalPad)
                    .arkadNumber(34)
                    .focused($isInputFocused)
            }
            if let message = validationMessage {
                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.marketRed)
            } else if let amount = parsedAmount {
                Text("New balance: \(newBalance(after: amount).asCurrency)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var quickAmountChips: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.s), count: 3), spacing: DS.Spacing.s) {
            ForEach(quickAmounts, id: \.self) { amount in
                Button(amount.asCurrency) {
                    UISelectionFeedbackGenerator().selectionChanged()
                    amountInput = String(format: "%.0f", amount)
                }
                .buttonStyle(PillButtonStyle(kind: .neutral))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var confirmBar: some View {
        Button(selectedAction == .deposit ? "Confirm deposit" : "Confirm withdrawal", action: performAction)
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isValidAmount)
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.m)
            .padding(.bottom, DS.Spacing.s)
            .background(
                Color.appBackground
                    .overlay(alignment: .top) { Divider().overlay(Color.hairline) }
                    .ignoresSafeArea()
            )
    }

    private var currentBalance: Double {
        portfolioViewModel.startingCapital ?? 0
    }

    private var parsedAmount: Double? {
        guard let amount = AssetTerms.parseNumber(amountInput), amount > 0 else { return nil }
        return amount
    }

    private func newBalance(after amount: Double) -> Double {
        selectedAction == .deposit ? currentBalance + amount : currentBalance - amount
    }

    private var validationMessage: String? {
        guard selectedAction == .withdraw, let amount = parsedAmount, amount > currentBalance else { return nil }
        return "You can withdraw up to \(currentBalance.asCurrency)."
    }

    private var isValidAmount: Bool {
        parsedAmount != nil && validationMessage == nil
    }

    private func performAction() {
        guard let amount = parsedAmount, isValidAmount else { return }
        switch selectedAction {
        case .deposit:
            portfolioViewModel.depositFunds(amount)
        case .withdraw:
            portfolioViewModel.withdrawFunds(amount)
        }
        // Errors surface on the Portfolio screen's alert
        dismiss()
    }
}

