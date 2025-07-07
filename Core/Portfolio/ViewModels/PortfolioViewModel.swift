// File: Core/Portfolio/ViewModels/PortfolioViewModel.swift
// Enhanced Portfolio ViewModel with comprehensive analytics and profile sync

import Foundation
import SwiftUI

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
            }
        }
    }
    
    // MARK: - Portfolio Calculations
    private func calculatePortfolioMetrics() {
        guard let userId = authService.currentUser?.id else { return }
        
        let openTrades = trades.filter { $0.isOpen }
        let closedTrades = trades.filter { !$0.isOpen }
        
        // Calculate portfolio values
        let totalValue = openTrades.reduce(0) { $0 + $1.currentValue }
        let totalInvested = openTrades.reduce(0) { $0 + ($1.entryPrice * Double($1.quantity)) }
        let totalPL = closedTrades.reduce(0) { $0 + $1.profitLoss }
        let unrealizedPL = openTrades.reduce(0) { $0 + (($0 - $1.entryPrice) * Double($1.quantity)) }
        
        // Calculate win rate
        let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
        let winRate = closedTrades.count > 0 ? Double(winningTrades) / Double(closedTrades.count) * 100 : 0
        
        // Calculate today's P&L (mock for now - would need historical price data)
        let dayPL = calculateDayProfitLoss()
        
        // Create portfolio object
        var newPortfolio = Portfolio(userId: userId)
        newPortfolio.totalValue = totalValue
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
        
        // Generate analytics
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
        self.topPerformingTrades = Array(closedTrades.sorted { $0.profitLoss > $1.profitLoss }.prefix(5))
        self.worstPerformingTrades = Array(closedTrades.sorted { $0.profitLoss < $1.profitLoss }.prefix(5))
        
        // Generate recent performance data
        self.recentPerformance = generateRecentPerformance()
    }
    
    // MARK: - Trade Management
    func addTrade(_ trade: Trade) async {
        do {
            try await authService.addTrade(trade)
            // Data will auto-update via listener
        } catch {
            errorMessage = "Failed to add trade: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func closeTrade(_ trade: Trade, exitPrice: Double) {
        var updatedTrade = trade
        updatedTrade.exitPrice = exitPrice
        updatedTrade.exitDate = Date()
        updatedTrade.isOpen = false
        
        Task {
            do {
                try await authService.updateTrade(updatedTrade)
                // Data will auto-update via listener
            } catch {
                errorMessage = "Failed to close trade: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func deleteTrade(_ trade: Trade) async {
        do {
            try await authService.deleteTrade(tradeId: trade.id)
            // Data will auto-update via listener
        } catch {
            errorMessage = "Failed to delete trade: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // MARK: - Profile Sync
    private func updateUserProfileStats() {
        guard let userId = authService.currentUser?.id,
              let portfolio = portfolio else { return }
        
        Task {
            do {
                try await authService.updateUserStats(
                    userId: userId,
                    totalProfitLoss: portfolio.totalProfitLoss,
                    winRate: portfolio.winRate
                )
            } catch {
                print("Failed to update user stats: \(error)")
            }
        }
    }
    
    // MARK: - Real-time Updates
    private func setupRealtimeUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            // Update portfolio metrics every minute
            self?.calculatePortfolioMetrics()
            self?.generatePortfolioAnalytics()
        }
    }
    
    // MARK: - Analytics Calculations
    private func calculateTotalReturnPercentage() -> Double {
        let totalInvested = trades.filter { !$0.isOpen }.reduce(0) { $0 + ($1.entryPrice * Double($1.quantity)) }
        guard totalInvested > 0 else { return 0 }
        return (portfolio?.totalProfitLoss ?? 0) / totalInvested * 100
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
        // Simplified Sharpe ratio calculation
        let returns = trades.filter { !$0.isOpen }.map { $0.profitLossPercentage / 100 }
        guard returns.count > 1 else { return 0 }
        
        let avgReturn = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - avgReturn, 2) }.reduce(0, +) / Double(returns.count - 1)
        let stdDev = sqrt(variance)
        
        guard stdDev > 0 else { return 0 }
        return avgReturn / stdDev
    }
    
    private func calculateMaxDrawdown() -> Double {
        // Simplified max drawdown calculation
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
    
    private func calculateDayProfitLoss() -> Double {
        // Mock calculation - in reality you'd need real-time price data
        // For now, return a random value between -5% and +5% of open positions
        let openPositionsValue = trades.filter { $0.isOpen }.reduce(0) { $0 + $1.currentValue }
        let randomPercentage = Double.random(in: -0.05...0.05)
        return openPositionsValue * randomPercentage
    }
    
    private func generateRecentPerformance() -> [DailyPerformance] {
        // Generate mock daily performance data for the last 30 days
        var performances: [DailyPerformance] = []
        let calendar = Calendar.current
        
        for i in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            
            let baseValue = 10000.0 + Double(30 - i) * 100 // Trending upward
            let dailyChange = Double.random(in: -200...300) // Random daily fluctuation
            
            performances.append(DailyPerformance(
                date: date,
                portfolioValue: baseValue + dailyChange,
                dailyChange: dailyChange,
                dailyChangePercentage: (dailyChange / baseValue) * 100
            ))
        }
        
        return performances.reversed() // Chronological order
    }
    
    // MARK: - Public Methods
    func refreshPortfolio() {
        loadPortfolioData()
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
