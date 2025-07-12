// File: Core/Portfolio/ViewModels/PortfolioViewModel.swift
// Enhanced Portfolio ViewModel with Correct Portfolio Math

import Foundation
import SwiftUI

// MARK: - TimeFrame Enum

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
    
    @Published var showDepositWithdrawSheet = false
    @Published var showStartingCapitalPrompt = false

    // Real-time sync
    @Published var lastUpdated: Date = Date()
    private var updateTimer: Timer?
    
    private let authService = FirebaseAuthService.shared
    
    // MARK: - Initialization
    init() {
        setupRealtimeUpdates()
        loadPortfolioData()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    // MARK: - Real-time Updates
    private func setupRealtimeUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updateCurrentPrices()
        }
    }
    
    // Remove mock price updates
    private func updateCurrentPrices() {
        // REMOVED: No more simulated price movements
        // Only update prices when real market data is available
        // This method can be used later for real API price updates
        
        // For now, do nothing - prices will stay at entry price until real data is available
        return
    }
    func depositFunds(_ amount: Double) {
        guard let currentCapital = getUserStartingCapital() else { return }
        setUserStartingCapital(currentCapital + amount)
    }

    func withdrawFunds(_ amount: Double) {
        guard let currentCapital = getUserStartingCapital() else { return }
        let newAmount = max(0, currentCapital - amount) // Don't allow negative
        setUserStartingCapital(newAmount)
    }
    // MARK: - Portfolio Data Loading
    func loadPortfolioData() {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
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
    
    // MARK: - FIXED Portfolio Calculations
    private func calculatePortfolioMetrics() {
        guard let userId = authService.currentUser?.id else { return }
        
        let openTrades = trades.filter { $0.isOpen }
        let closedTrades = trades.filter { !$0.isOpen }
        
        // Get user's starting capital (or prompt for it)
        guard let startingCapital = getUserStartingCapital() else {
            checkForStartingCapitalPrompt()
            // Use temporary calculation until starting capital is set
            let totalPL = closedTrades.reduce(0) { $0 + $1.profitLoss }
            let currentValue = openTrades.reduce(0) { $0 + $1.currentValue }
            
            var newPortfolio = Portfolio(userId: userId)
            newPortfolio.totalValue = currentValue
            newPortfolio.totalProfitLoss = totalPL
            newPortfolio.totalTrades = trades.count
            newPortfolio.openPositions = openTrades.count
            newPortfolio.winRate = closedTrades.count > 0 ? Double(closedTrades.filter { $0.profitLoss > 0 }.count) / Double(closedTrades.count) * 100 : 0
            newPortfolio.lastUpdated = Date()
            self.portfolio = newPortfolio
            return
        }
        
        // CORRECT CALCULATION with user's starting capital
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
        
        let dayPL = calculateRealisticDayProfitLoss()
        
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
    
    private func generatePortfolioAnalytics() {
        let closedTrades = trades.filter { !$0.isOpen }
        let openTrades = trades.filter { $0.isOpen }
        
        // Generate realistic analytics
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
        
        // Update performance arrays
        self.topPerformingTrades = Array(closedTrades.sorted { $0.profitLoss > $1.profitLoss }.prefix(5))
        self.worstPerformingTrades = Array(closedTrades.sorted { $0.profitLoss < $1.profitLoss }.prefix(5))
        
        // Generate realistic performance data
        self.recentPerformance = generateRealisticPerformance()
    }
    
    // MARK: - Realistic Data Generation
    private func calculateRealisticDayProfitLoss() -> Double {
        // REMOVED: No more random daily changes
        // Return actual day change based on real price movements only
        
        let openTrades = trades.filter { $0.isOpen }
        guard !openTrades.isEmpty else { return 0 }
        
        // Only calculate real day P&L if we have actual price updates
        // For now, return 0 until real price data is available
        return 0.0
    }
    
    private func generateRealisticPerformance() -> [DailyPerformance] {
        // REMOVED: No more fake 30-day performance history
        // Only generate performance based on actual trade dates
        
        var performances: [DailyPerformance] = []
        let calendar = Calendar.current
        
        // Only show performance for days where actual trades occurred
        let tradeDates = trades.map { calendar.startOfDay(for: $0.entryDate) }
        let uniqueDates = Array(Set(tradeDates)).sorted()
        
        for date in uniqueDates {
            let tradesOnDate = trades.filter {
                calendar.isDate($0.entryDate, inSameDayAs: date)
            }
            
            // Calculate actual portfolio value change on this date
            let valueChangeOnDate = tradesOnDate.reduce(0.0) { total, trade in
                return total + (trade.isOpen ? 0 : trade.profitLoss)
            }
            
            let performance = DailyPerformance(
                date: date,
                portfolioValue: portfolio?.totalValue ?? 0,
                dailyChange: valueChangeOnDate,
                dailyChangePercentage: 0 // Calculate actual percentage later if needed
            )
            performances.append(performance)
        }
        
        return performances
    }
    
    // MARK: - Trade Management
    func closeTrade(_ trade: Trade, exitPrice: Double) {
        guard let index = trades.firstIndex(where: { $0.id == trade.id }) else { return }
        
        trades[index].exitPrice = exitPrice
        trades[index].exitDate = Date()
        trades[index].isOpen = false
        trades[index].currentPrice = nil
        
        // Update in Firebase
        Task {
            do {
                try await authService.updateTrade(trades[index])
                // Recalculate portfolio metrics
                calculatePortfolioMetrics()
                generatePortfolioAnalytics()
            } catch {
                errorMessage = "Failed to close trade: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateTrade(_ updatedTrade: Trade) async throws {
        do {
            // Update in Firebase first
            try await authService.updateTrade(updatedTrade)
            
            // Update local trades array
            if let index = trades.firstIndex(where: { $0.id == updatedTrade.id }) {
                trades[index] = updatedTrade
                
                // Recalculate portfolio metrics with updated data
                calculatePortfolioMetrics()
                generatePortfolioAnalytics()
            }
        } catch {
            errorMessage = "Failed to update trade: \(error.localizedDescription)"
            showError = true
            throw error
        }
    }
    
    // MARK: - Reopen Trade
    func reopenTrade(_ trade: Trade) async throws {
        guard !trade.isOpen else {
            throw PortfolioError.tradeAlreadyOpen
        }
        
        do {
            // Create reopened trade
            var reopenedTrade = trade
            reopenedTrade.isOpen = true
            reopenedTrade.exitPrice = nil
            reopenedTrade.exitDate = nil
            reopenedTrade.currentPrice = trade.entryPrice // Reset to entry price as starting point
            
            // Update in Firebase
            try await authService.updateTrade(reopenedTrade)
            
            // Update local trades array
            if let index = trades.firstIndex(where: { $0.id == trade.id }) {
                trades[index] = reopenedTrade
                
                // Recalculate portfolio metrics
                calculatePortfolioMetrics()
                generatePortfolioAnalytics()
            }
        } catch {
            errorMessage = "Failed to reopen trade: \(error.localizedDescription)"
            showError = true
            throw error
        }
    }
    
    // MARK: - Delete Trade
    func deleteTrade(_ trade: Trade) async throws {
        do {
            // Delete from Firebase first (method expects tradeId as String)
            try await authService.deleteTrade(tradeId: trade.id)
            
            // Remove from local trades array
            trades.removeAll { $0.id == trade.id }
            
            // Recalculate portfolio metrics
            calculatePortfolioMetrics()
            generatePortfolioAnalytics()
        } catch {
            errorMessage = "Failed to delete trade: \(error.localizedDescription)"
            showError = true
            throw error
        }
    }
    
    // MARK: - Helper Calculations
    private func calculateTotalReturnPercentage() -> Double {
        let totalCapitalDeployed = trades.reduce(0) { $0 + ($1.entryPrice * Double($1.quantity)) }
        guard totalCapitalDeployed > 0 else { return 0 }
        let totalPL = portfolio?.totalProfitLoss ?? 0
        return (totalPL / totalCapitalDeployed) * 100
    }
    
    private func calculateAverageHoldTime() -> Double {
        let closedTrades = trades.filter { !$0.isOpen && $0.exitDate != nil }
        guard !closedTrades.isEmpty else { return 0 }
        
        let totalDays = closedTrades.reduce(0) { total, trade in
            guard let exitDate = trade.exitDate else { return total }
            let days = Calendar.current.dateComponents([.day], from: trade.entryDate, to: exitDate).day ?? 0
            return total + days
        }
        
        return Double(totalDays) / Double(closedTrades.count)
    }
    
    private func calculateAverageTradeSize() -> Double {
        guard !trades.isEmpty else { return 0 }
        let totalValue = trades.reduce(0) { $0 + ($1.entryPrice * Double($1.quantity)) }
        return totalValue / Double(trades.count)
    }
    
    private func calculateAverageWin() -> Double {
        let winningTrades = trades.filter { !$0.isOpen && $0.profitLoss > 0 }
        guard !winningTrades.isEmpty else { return 0 }
        return winningTrades.reduce(0) { $0 + $1.profitLoss } / Double(winningTrades.count)
    }
    
    private func calculateAverageLoss() -> Double {
        let losingTrades = trades.filter { !$0.isOpen && $0.profitLoss < 0 }
        guard !losingTrades.isEmpty else { return 0 }
        return losingTrades.reduce(0) { $0 + $1.profitLoss } / Double(losingTrades.count)
    }
    
    private func calculateProfitFactor() -> Double {
        let totalWins = trades.filter { !$0.isOpen && $0.profitLoss > 0 }.reduce(0) { $0 + $1.profitLoss }
        let totalLosses = abs(trades.filter { !$0.isOpen && $0.profitLoss < 0 }.reduce(0) { $0 + $1.profitLoss })
        guard totalLosses > 0 else { return totalWins > 0 ? Double.infinity : 0 }
        return totalWins / totalLosses
    }
    
    private func calculateSharpeRatio() -> Double {
        let returns = trades.filter { !$0.isOpen }.map { $0.profitLossPercentage / 100 }
        guard returns.count > 1 else { return 0 }
        
        let avgReturn = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - avgReturn, 2) }.reduce(0, +) / Double(returns.count - 1)
        let stdDev = sqrt(variance)
        
        guard stdDev > 0 else { return 0 }
        return avgReturn / stdDev
    }
    
    private func calculateMaxDrawdown() -> Double {
        let closedTrades = trades.filter { !$0.isOpen }.sorted { $0.exitDate ?? Date() < $1.exitDate ?? Date() }
        var peak: Double = 0
        var maxDrawdown: Double = 0
        var runningTotal: Double = 0
        
        for trade in closedTrades {
            runningTotal += trade.profitLoss
            if runningTotal > peak {
                peak = runningTotal
            } else {
                let drawdown = (peak - runningTotal) / peak * 100
                maxDrawdown = max(maxDrawdown, drawdown)
            }
        }
        
        return maxDrawdown
    }
    
    // MARK: - User Profile Stats Update
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
                errorMessage = "Failed to update stats: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Public Methods
    func refreshPortfolio() {
        loadPortfolioData()
    }
    
    private func getUserStartingCapital() -> Double? {
        let savedCapital = UserDefaults.standard.double(forKey: "starting_capital_\(authService.currentUser?.id ?? "")")
        return savedCapital > 0 ? savedCapital : nil
    }

    func setUserStartingCapital(_ amount: Double) {
        UserDefaults.standard.set(amount, forKey: "starting_capital_\(authService.currentUser?.id ?? "")")
        calculatePortfolioMetrics() // Recalculate with new starting capital
    }

    private func checkForStartingCapitalPrompt() {
        // Show prompt if user has trades but no starting capital set
        if !trades.isEmpty && getUserStartingCapital() == nil {
            showStartingCapitalPrompt = true
        }
    }
    
    func getTradesFor(timeframe: TimeFrame) -> [Trade] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch timeframe {
        case .daily:
            startDate = calendar.startOfDay(for: now)
        case .weekly:
            startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case .monthly:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .allTime:
            return trades
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

struct DepositWithdrawSheet: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedAction: FundAction = .deposit
    @State private var amountInput = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
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
                    
                    Text("\(selectedAction.title) Funds")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Adjust your account balance for deposits or withdrawals")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
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
                            .foregroundColor(selectedAction == action ? .white : action.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedAction == action ? action.color : action.color.opacity(0.1))
                        }
                    }
                }
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Amount Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Amount")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Enter amount", text: $amountInput)
                        .keyboardType(.numberPad)
                        .font(.title2)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            HStack {
                                Text("$")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 16)
                                Spacer()
                            }
                        )
                }
                .padding(.horizontal)
                
                // Quick Amount Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Select")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        quickAmountButton("$100", amount: 100)
                        quickAmountButton("$250", amount: 250)
                        quickAmountButton("$500", amount: 500)
                        quickAmountButton("$1000", amount: 1000)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Action Button
                Button(action: performAction) {
                    Text("\(selectedAction.title) \(amountInput.isEmpty ? "" : "$\(amountInput)")")
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
            .navigationTitle("\(selectedAction.title) Funds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.arkadGold.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private var isValidAmount: Bool {
        guard let amount = Double(amountInput.replacingOccurrences(of: ",", with: "")) else { return false }
        return amount > 0
    }
    
    private func performAction() {
        guard let amount = Double(amountInput.replacingOccurrences(of: ",", with: "")) else { return }
        
        switch selectedAction {
        case .deposit:
            portfolioViewModel.depositFunds(amount)
            alertMessage = "Successfully deposited \(amount.asCurrency) to your account."
        case .withdraw:
            portfolioViewModel.withdrawFunds(amount)
            alertMessage = "Successfully withdrew \(amount.asCurrency) from your account."
        }
        
        showAlert = true
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

