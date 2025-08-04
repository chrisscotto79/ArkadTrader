// File: Core/Portfolio/ViewModels/PortfolioViewModel.swift
// Enhanced Portfolio ViewModel with Realistic Performance Analytics - Production Ready
// FIXED: All compilation errors resolved

import Foundation
import SwiftUI
import Combine

@MainActor
class PortfolioViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var trades: [Trade] = []
    @Published var portfolio: Portfolio?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    // Portfolio Analytics
    @Published var portfolioAnalytics: PortfolioAnalytics?
    @Published var recentPerformance: [DailyPerformance] = []
    @Published var topPerformingTrades: [Trade] = []
    @Published var worstPerformingTrades: [Trade] = []
    
    // UI State
    @Published var showDepositWithdrawSheet = false
    @Published var showStartingCapitalPrompt = false
    @Published var lastUpdated: Date = Date()
    
    // Private Properties
    private var updateTimer: Timer?
    let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupRealtimeUpdates()
        loadPortfolioData()
        observeUserChanges()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    // MARK: - Setup Methods
    private func setupRealtimeUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updateCurrentPrices()
        }
    }
    
    private func observeUserChanges() {
        authService.$currentUser
            .sink { [weak self] _ in
                self?.calculatePortfolioMetrics()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Portfolio Data Loading
    func loadPortfolioData() {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        // Check for legacy UserDefaults data and migrate it
        migrateLegacyStartingCapital()
        
        authService.listenToUserTrades(userId: userId) { [weak self] trades in
            DispatchQueue.main.async {
                self?.trades = trades
                self?.calculatePortfolioMetrics()
                self?.generatePortfolioAnalytics()
                self?.updateUserProfileStats()
                self?.lastUpdated = Date()
                self?.isLoading = false
                
                // Check if we need to prompt for starting capital
                self?.checkForStartingCapitalPrompt()
            }
        }
    }
    
    // MARK: - Legacy Data Migration
    private func migrateLegacyStartingCapital() {
        guard let userId = authService.currentUser?.id else { return }
        
        // Check if user already has starting capital in Firebase
        if let firebaseStartingCapital = authService.currentUser?.startingCapital, firebaseStartingCapital > 0 {
            // User already has Firebase starting capital, clean up any UserDefaults
            UserDefaults.standard.removeObject(forKey: "starting_capital_\(userId)")
            return
        }
        
        // Check for legacy UserDefaults data
        let legacyCapitalKey = "starting_capital_\(userId)"
        if let legacyCapital = UserDefaults.standard.object(forKey: legacyCapitalKey) as? Double, legacyCapital > 0 {
            Task {
                do {
                    try await authService.updateCurrentUserStartingCapital(legacyCapital)
                    
                    // Clean up UserDefaults after successful migration
                    UserDefaults.standard.removeObject(forKey: legacyCapitalKey)
                    
                    await MainActor.run {
                        calculatePortfolioMetrics()
                    }
                } catch {
                    print("Failed to migrate legacy starting capital: \(error)")
                }
            }
        }
    }
    
    // MARK: - Starting Capital Management
    func getUserStartingCapital() -> Double? {
        // Use Firebase user's starting capital directly
        guard let startingCapital = authService.currentUser?.startingCapital, startingCapital > 0 else {
            return nil
        }
        return startingCapital
    }
    
    // MARK: - Account Value Management (Deposit/Withdraw)
    func depositFunds(_ amount: Double) {
        guard let currentCapital = getUserStartingCapital() else {
            // If no starting capital is set, set the deposit amount as starting capital
            setUserStartingCapital(amount)
            return
        }
        
        let newCapital = currentCapital + amount
        updateStartingCapital(newCapital, actionDescription: "deposited")
    }
    
    func withdrawFunds(_ amount: Double) {
        guard let currentCapital = getUserStartingCapital() else {
            showErrorMessage("Please set your starting capital first")
            return
        }
        
        let newCapital = max(0, currentCapital - amount)
        
        // Check if withdrawal amount is valid
        if amount > currentCapital {
            showErrorMessage("Insufficient funds. Available balance: \(currentCapital.asCurrency)")
            return
        }
        
        updateStartingCapital(newCapital, actionDescription: "withdrew")
    }
    
    private func updateStartingCapital(_ newAmount: Double, actionDescription: String) {
        Task {
            do {
                try await authService.updateCurrentUserStartingCapital(newAmount)
                
                await MainActor.run {
                    calculatePortfolioMetrics()
                    showDepositWithdrawSheet = false
                }
            } catch {
                await MainActor.run {
                    showErrorMessage("Failed to \(actionDescription) funds: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func setUserStartingCapital(_ amount: Double) {
        Task {
            do {
                try await authService.updateCurrentUserStartingCapital(amount)
                
                await MainActor.run {
                    calculatePortfolioMetrics()
                    showStartingCapitalPrompt = false
                }
            } catch {
                await MainActor.run {
                    showErrorMessage("Failed to set starting capital: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Portfolio Calculations
    private func calculatePortfolioMetrics() {
        guard let userId = authService.currentUser?.id else { return }
        
        let openTrades = trades.filter { $0.isOpen }
        let closedTrades = trades.filter { !$0.isOpen }
        
        // Get user's starting capital
        guard let startingCapital = getUserStartingCapital() else {
            if !trades.isEmpty {
                checkForStartingCapitalPrompt()
            }
            createTemporaryPortfolio(userId: userId, openTrades: openTrades, closedTrades: closedTrades)
            return
        }
        
        // Calculate portfolio values
        let currentValueOfOpenPositions = openTrades.reduce(0) { $0 + $1.currentValue }
        let totalInvestedInOpenPositions = openTrades.reduce(0) { $0 + ($1.entryPrice * Double($1.quantity)) }
        let realizedPL = closedTrades.reduce(0) { $0 + $1.profitLoss }
        let unrealizedPL = currentValueOfOpenPositions - totalInvestedInOpenPositions
        
        // Available Cash = Starting Capital + Realized P&L - Money Currently Invested
        let availableCash = startingCapital + realizedPL - totalInvestedInOpenPositions
        
        // Total Portfolio = Available Cash + Current Value of Open Positions
        let totalAccountValue = availableCash + currentValueOfOpenPositions
        
        // Total P&L = Portfolio Value - Starting Capital
        let totalPL = totalAccountValue - startingCapital
        
        // Calculate win rate
        let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
        let winRate = closedTrades.count > 0 ? Double(winningTrades) / Double(closedTrades.count) * 100 : 0
        
        let dayPL = calculateDayProfitLoss()
        
        // Create portfolio object
        var newPortfolio = Portfolio(userId: userId)
        newPortfolio.totalValue = totalAccountValue
        newPortfolio.totalProfitLoss = totalPL
        newPortfolio.dayProfitLoss = dayPL
        newPortfolio.totalTrades = trades.count
        newPortfolio.openPositions = openTrades.count
        newPortfolio.winRate = winRate
        newPortfolio.lastUpdated = Date()
        
        self.portfolio = newPortfolio
    }
    
    private func createTemporaryPortfolio(userId: String, openTrades: [Trade], closedTrades: [Trade]) {
        let totalPL = closedTrades.reduce(0) { $0 + $1.profitLoss }
        let currentValue = openTrades.reduce(0) { $0 + $1.currentValue }
        
        var newPortfolio = Portfolio(userId: userId)
        newPortfolio.totalValue = currentValue
        newPortfolio.totalProfitLoss = totalPL
        newPortfolio.totalTrades = trades.count
        newPortfolio.openPositions = openTrades.count
        newPortfolio.winRate = closedTrades.count > 0 ?
            Double(closedTrades.filter { $0.profitLoss > 0 }.count) / Double(closedTrades.count) * 100 : 0
        newPortfolio.lastUpdated = Date()
        
        self.portfolio = newPortfolio
    }
    
    private func calculateDayProfitLoss() -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        
        let yesterdayValue = calculatePortfolioValueForDate(yesterday)
        let todayValue = calculatePortfolioValueForDate(today)
        
        return todayValue - yesterdayValue
    }
    
    func calculatePortfolioValueForDate(_ date: Date) -> Double {
        guard let startingCapital = getUserStartingCapital() else { return 0 }
        let calendar = Calendar.current
        
        // Get trades that were entered before or on this date
        let tradesEnteredByDate = trades.filter {
            calendar.startOfDay(for: $0.entryDate) <= calendar.startOfDay(for: date)
        }
        
        // Get trades that were closed before or on this date
        let tradesClosedByDate = tradesEnteredByDate.filter { trade in
            guard !trade.isOpen else { return false }
            let exitDate = trade.exitDate ?? trade.entryDate
            return calendar.startOfDay(for: exitDate) <= calendar.startOfDay(for: date)
        }
        
        // Calculate realized P&L from closed trades
        let realizedPL = tradesClosedByDate.reduce(0.0) { $0 + $1.profitLoss }
        
        // Calculate money invested in open positions on this date
        let openTradesOnDate = tradesEnteredByDate.filter { trade in
            if trade.isOpen {
                return true
            } else {
                let exitDate = trade.exitDate ?? trade.entryDate
                return calendar.startOfDay(for: exitDate) > calendar.startOfDay(for: date)
            }
        }
        
        let investedInOpenPositions = openTradesOnDate.reduce(0.0) {
            $0 + ($1.entryPrice * Double($1.quantity))
        }
        
        // Available cash = Starting Capital + Realized P&L - Money in Open Positions
        let availableCash = startingCapital + realizedPL - investedInOpenPositions
        
        // Current value of open positions
        let currentValueOfOpenPositions = openTradesOnDate.reduce(0.0) {
            $0 + ($1.entryPrice * Double($1.quantity))
        }
        
        // Total Portfolio Value = Available Cash + Current Value of Open Positions
        return availableCash + currentValueOfOpenPositions
    }
    
    // MARK: - Analytics Generation
    private func generatePortfolioAnalytics() {
        let closedTrades = trades.filter { !$0.isOpen }
        let openTrades = trades.filter { $0.isOpen }
        
        let analytics = PortfolioAnalytics(
            totalReturn: portfolio?.totalProfitLoss ?? 0,
            totalReturnPercentage: calculateTotalReturnPercentage(),
            bestTrade: closedTrades.max(by: { $0.profitLoss < $1.profitLoss }),
            worstTrade: closedTrades.min(by: { $0.profitLoss < $1.profitLoss }),
            averageHoldTime: calculateAverageHoldTime(),
            averageTradeSize: calculateAverageTradeSize(),
            largestPosition: openTrades.max(by: { $0.currentValue < $1.currentValue }),
            profitableTrades: closedTrades.filter { $0.profitLoss > 0 }.count,
            losingTrades: closedTrades.filter { $0.profitLoss < 0 }.count,
            winRate: portfolio?.winRate ?? 0,
            averageWin: calculateAverageWin(),
            averageLoss: calculateAverageLoss(),
            profitFactor: calculateProfitFactor(),
            sharpeRatio: calculateSharpeRatio(),
            maxDrawdown: calculateMaxDrawdown()
        )
        
        self.portfolioAnalytics = analytics
        
        // Update top/worst performing trades
        self.topPerformingTrades = Array(closedTrades
            .sorted(by: { $0.profitLoss > $1.profitLoss })
            .prefix(5))
        
        self.worstPerformingTrades = Array(closedTrades
            .sorted(by: { $0.profitLoss < $1.profitLoss })
            .prefix(5))
    }
    
    // MARK: - Calculation Helpers
    private func calculateTotalReturnPercentage() -> Double {
        guard let startingCapital = getUserStartingCapital(), startingCapital > 0 else { return 0 }
        let totalPL = portfolio?.totalProfitLoss ?? 0
        return (totalPL / startingCapital) * 100
    }
    
    private func calculateAverageHoldTime() -> Double {
        let closedTrades = trades.filter { !$0.isOpen }
        guard !closedTrades.isEmpty else { return 0 }
        
        let totalHoldTime = closedTrades.reduce(0.0) { total, trade in
            let exitDate = trade.exitDate ?? Date()
            let holdTime = exitDate.timeIntervalSince(trade.entryDate) / 86400 // Days
            return total + holdTime
        }
        
        return totalHoldTime / Double(closedTrades.count)
    }
    
    private func calculateAverageTradeSize() -> Double {
        guard !trades.isEmpty else { return 0 }
        let totalSize = trades.reduce(0.0) { $0 + ($1.entryPrice * Double($1.quantity)) }
        return totalSize / Double(trades.count)
    }
    
    private func calculateAverageWin() -> Double {
        let winningTrades = trades.filter { !$0.isOpen && $0.profitLoss > 0 }
        guard !winningTrades.isEmpty else { return 0 }
        return winningTrades.reduce(0.0) { $0 + $1.profitLoss } / Double(winningTrades.count)
    }
    
    private func calculateAverageLoss() -> Double {
        let losingTrades = trades.filter { !$0.isOpen && $0.profitLoss < 0 }
        guard !losingTrades.isEmpty else { return 0 }
        return abs(losingTrades.reduce(0.0) { $0 + $1.profitLoss } / Double(losingTrades.count))
    }
    
    private func calculateProfitFactor() -> Double {
        let grossProfit = trades.filter { !$0.isOpen && $0.profitLoss > 0 }
            .reduce(0.0) { $0 + $1.profitLoss }
        let grossLoss = abs(trades.filter { !$0.isOpen && $0.profitLoss < 0 }
            .reduce(0.0) { $0 + $1.profitLoss })
        
        return grossLoss > 0 ? grossProfit / grossLoss : 0
    }
    
    private func calculateSharpeRatio() -> Double {
        let closedTrades = trades.filter { !$0.isOpen }
        guard closedTrades.count > 1 else { return 0 }
        
        let returns = closedTrades.map { $0.profitLossPercentage / 100 }
        let avgReturn = returns.reduce(0, +) / Double(returns.count)
        
        let variance = returns.reduce(0) { $0 + pow($1 - avgReturn, 2) } / Double(returns.count - 1)
        let stdDev = sqrt(variance)
        
        let riskFreeRate = 0.04 / 252 // 4% annual risk-free rate, daily
        
        return stdDev > 0 ? (avgReturn - riskFreeRate) / stdDev * sqrt(252) : 0
    }
    
    private func calculateMaxDrawdown() -> Double {
        let closedTrades = trades.filter { !$0.isOpen }.sorted {
            $0.exitDate ?? Date() < $1.exitDate ?? Date()
        }
        
        var peak: Double = 0
        var maxDrawdown: Double = 0
        var runningTotal: Double = 0
        
        for trade in closedTrades {
            runningTotal += trade.profitLoss
            if runningTotal > peak {
                peak = runningTotal
            } else if peak > 0 {
                let drawdown = (peak - runningTotal) / peak * 100
                maxDrawdown = max(maxDrawdown, drawdown)
            }
        }
        
        return maxDrawdown
    }
    
    // MARK: - Trade Management
    func closeTrade(_ trade: Trade, exitPrice: Double) {
        guard let index = trades.firstIndex(where: { $0.id == trade.id }) else { return }
        
        trades[index].exitPrice = exitPrice
        trades[index].exitDate = Date()
        trades[index].isOpen = false
        trades[index].currentPrice = nil
        
        Task {
            do {
                try await authService.updateTrade(trades[index])
                await MainActor.run {
                    calculatePortfolioMetrics()
                    generatePortfolioAnalytics()
                }
            } catch {
                await MainActor.run {
                    showErrorMessage("Failed to close trade: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func updateTrade(_ updatedTrade: Trade) async throws {
        do {
            try await authService.updateTrade(updatedTrade)
            
            if let index = trades.firstIndex(where: { $0.id == updatedTrade.id }) {
                trades[index] = updatedTrade
                
                await MainActor.run {
                    calculatePortfolioMetrics()
                    generatePortfolioAnalytics()
                }
            }
        } catch {
            await MainActor.run {
                showErrorMessage("Failed to update trade: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    func reopenTrade(_ trade: Trade) async throws {
        guard !trade.isOpen else {
            throw PortfolioError.tradeAlreadyOpen
        }
        
        var reopenedTrade = trade
        reopenedTrade.isOpen = true
        reopenedTrade.exitPrice = nil
        reopenedTrade.exitDate = nil
        reopenedTrade.currentPrice = trade.entryPrice
        
        try await updateTrade(reopenedTrade)
    }
    
    func deleteTrade(_ trade: Trade) async throws {
        do {
            try await authService.deleteTrade(tradeId: trade.id)
            
            trades.removeAll { $0.id == trade.id }
            
            await MainActor.run {
                calculatePortfolioMetrics()
                generatePortfolioAnalytics()
            }
        } catch {
            await MainActor.run {
                showErrorMessage("Failed to delete trade: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    // MARK: - Helper Methods
    private func checkForStartingCapitalPrompt() {
        if !trades.isEmpty && getUserStartingCapital() == nil {
            showStartingCapitalPrompt = true
        }
    }
    
    private func updateUserProfileStats() {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            do {
                try await authService.updateUserStats(
                    userId: userId,
                    totalProfitLoss: portfolio?.totalProfitLoss ?? 0,
                    winRate: portfolio?.winRate ?? 0
                )
            } catch {
                print("Failed to update user stats: \(error)")
            }
        }
    }
    
    private func updateCurrentPrices() {
        // Placeholder for real-time price updates
        // Will be implemented when market data API is integrated
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Public Methods
    func refreshPortfolio() {
        loadPortfolioData()
    }
    
    // MARK: - Enhanced Performance Analytics (PRODUCTION READY - FIXED)
    
    // FIXED: Correct date interval calculation and type conversions
    func getEnhancedPerformanceForTimeframe(_ timeframe: TimeFrame) -> [DailyPerformance] {
        guard !trades.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        let dataPoints: Int
        
        switch timeframe {
        case .weekly:
            startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            dataPoints = 7
        case .monthly:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            dataPoints = 15
        case .allTime:
            let earliestTradeDate = trades.min(by: { $0.entryDate < $1.entryDate })?.entryDate ?? now
            // FIXED: Use DateInterval instead of calendar.dateInterval(from:to:)
            let dateInterval = DateInterval(start: earliestTradeDate, end: now)
            let maxDaysBack = Int(dateInterval.duration / (24 * 60 * 60)) // Convert seconds to days
            let daysBack = min(maxDaysBack, 30) // Max 30 days for performance
            startDate = calendar.date(byAdding: .day, value: -daysBack, to: now) ?? now
            dataPoints = min(daysBack, 30)
        default:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            dataPoints = 15
        }
        
        guard startDate < now else { return [] }
        
        var performances: [DailyPerformance] = []
        let dateInterval = now.timeIntervalSince(startDate) / Double(max(dataPoints - 1, 1))
        
        for i in 0..<dataPoints {
            let currentDate = Date(timeIntervalSince1970: startDate.timeIntervalSince1970 + (dateInterval * Double(i)))
            let portfolioValue = calculatePortfolioValueForDate(currentDate)
            
            let previousDate = Date(timeIntervalSince1970: currentDate.timeIntervalSince1970 - dateInterval)
            let previousValue = calculatePortfolioValueForDate(previousDate)
            
            let dailyChange = portfolioValue - previousValue
            let dailyChangePercentage = previousValue > 0 ? (dailyChange / previousValue) * 100 : 0
            
            performances.append(DailyPerformance(
                date: currentDate,
                portfolioValue: portfolioValue,
                dailyChange: dailyChange,
                dailyChangePercentage: dailyChangePercentage
            ))
        }
        
        return performances
    }
    
    // ORIGINAL: Keep for backward compatibility
    func getPerformanceForTimeframe(_ timeframe: TimeFrame) -> [DailyPerformance] {
        return getEnhancedPerformanceForTimeframe(timeframe)
    }
    
    func getTradesForTimeframe(_ timeframe: TimeFrame) -> [Trade] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch timeframe {
        case .weekly:
            startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case .monthly:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .allTime:
            return trades
        default:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        }
        
        return trades.filter { $0.entryDate >= startDate }
    }
    
    func getPortfolioSummaryForProfile() -> PortfolioSummary {
        return PortfolioSummary(
            totalValue: portfolio?.totalValue ?? 0,
            totalProfitLoss: portfolio?.totalProfitLoss ?? 0,
            dayProfitLoss: portfolio?.dayProfitLoss ?? 0,
            winRate: portfolio?.winRate ?? 0,
            totalTrades: trades.count,
            openPositions: trades.filter { $0.isOpen }.count,
            recentTrades: Array(trades.prefix(5)),
            topPerformer: topPerformingTrades.first,
            lastUpdated: lastUpdated
        )
    }
}

// MARK: - Supporting Models
struct PortfolioAnalytics {
    let totalReturn: Double
    let totalReturnPercentage: Double
    let bestTrade: Trade?
    let worstTrade: Trade?
    let averageHoldTime: Double
    let averageTradeSize: Double
    let largestPosition: Trade?
    let profitableTrades: Int
    let losingTrades: Int
    let winRate: Double
    let averageWin: Double
    let averageLoss: Double
    let profitFactor: Double
    let sharpeRatio: Double
    let maxDrawdown: Double
}

struct DailyPerformance: Identifiable {
    let id = UUID()
    let date: Date
    let portfolioValue: Double
    let dailyChange: Double
    let dailyChangePercentage: Double
}

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
}

// MARK: - Portfolio Error Types
enum PortfolioError: LocalizedError {
    case tradeAlreadyOpen
    case tradeAlreadyClosed
    case invalidTradeData
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .tradeAlreadyOpen:
            return "This trade is already open"
        case .tradeAlreadyClosed:
            return "This trade is already closed"
        case .invalidTradeData:
            return "Invalid trade data provided"
        case .networkError:
            return "Network connection error"
        }
    }
}

// MARK: - DepositWithdrawSheet View (PRODUCTION READY)
struct DepositWithdrawSheet: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedAction: FundAction = .deposit
    @State private var amountInput = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @FocusState private var isInputFocused: Bool
    
    enum FundAction: CaseIterable {
        case deposit, withdraw
        
        var title: String {
            switch self {
            case .deposit: return "Deposit"
            case .withdraw: return "Withdraw"
            }
        }
        
        var icon: String {
            switch self {
            case .deposit: return "plus.circle.fill"
            case .withdraw: return "minus.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .deposit: return .green
            case .withdraw: return .red
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: selectedAction.icon)
                        .font(.system(size: 48))
                        .foregroundColor(selectedAction.color)
                    
                    Text("Adjust Account Value")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Adjust your account balance for deposits or withdrawals")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Current Balance Display
                if let currentBalance = portfolioViewModel.authService.currentUser?.startingCapital, currentBalance > 0 {
                    VStack(spacing: 8) {
                        Text("Current Balance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(currentBalance.asCurrency)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Action Selector
                HStack(spacing: 0) {
                    ForEach(FundAction.allCases, id: \.self) { action in
                        Button(action: { selectedAction = action }) {
                            HStack(spacing: 8) {
                                Image(systemName: action.icon)
                                Text(action.title)
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedAction == action ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedAction == action ? action.color : Color.clear)
                        }
                    }
                }
                .background(Color(.systemGray5))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Amount Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Amount")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        TextField("0.00", text: $amountInput)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .focused($isInputFocused)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Quick Amount Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Select")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        quickAmountButton("$100", amount: 100)
                        quickAmountButton("$500", amount: 500)
                        quickAmountButton("$1,000", amount: 1000)
                        quickAmountButton("$5,000", amount: 5000)
                        quickAmountButton("$10,000", amount: 10000)
                        quickAmountButton("$25,000", amount: 25000)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Action Button
                Button(action: performAction) {
                    Text("Confirm Adjustment")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidAmount ? selectedAction.color : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!isValidAmount)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Adjust Account Value")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                isInputFocused = true
            }
        }
        .alert("Transaction Complete", isPresented: $showAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func quickAmountButton(_ title: String, amount: Double) -> some View {
        Button(action: {
            amountInput = String(format: "%.0f", amount)
        }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.arkadGold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.arkadGold.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private var isValidAmount: Bool {
        guard let amount = Double(amountInput.replacingOccurrences(of: ",", with: "")) else { return false }
        
        if selectedAction == .withdraw {
            let currentBalance = portfolioViewModel.authService.currentUser?.startingCapital ?? 0
            return amount > 0 && amount <= currentBalance
        }
        
        return amount > 0
    }
    
    private func performAction() {
        guard let amount = Double(amountInput.replacingOccurrences(of: ",", with: "")) else { return }
        
        switch selectedAction {
        case .deposit:
            portfolioViewModel.depositFunds(amount)
            alertMessage = "Successfully added \(amount.asCurrency) to your account."
        case .withdraw:
            portfolioViewModel.withdrawFunds(amount)
            alertMessage = "Successfully withdrew \(amount.asCurrency) from your account."
        }
        
        showAlert = true
    }
}
