// File: Core/Portfolio/ViewModels/PortfolioViewModel.swift
// Updated PortfolioViewModel for Firebase integration

import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var trades: [Trade] = []
    @Published var portfolio: Portfolio?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = FirebaseAuthService.shared
    private let firestoreService = FirestoreService.shared
    
    init() {
        setupTradesListener()
    }
    
    deinit {
        firestoreService.removeAllListeners()
    }
    
    func loadPortfolioData() {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                let trades = try await firestoreService.getUserTrades(userId: userId)
                await MainActor.run {
                    self.trades = trades
                    self.calculatePortfolioMetrics()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load portfolio: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func setupTradesListener() {
        guard let userId = authService.currentUser?.id else { return }
        
        firestoreService.listenToUserTrades(userId: userId) { [weak self] trades in
            Task { @MainActor in
                self?.trades = trades
                self?.calculatePortfolioMetrics()
            }
        }
    }
    
    func addTrade(_ trade: Trade) {
        Task {
            do {
                try await firestoreService.addTrade(trade)
                // The listener will automatically update the trades array
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to add trade: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func addTradeSimple(ticker: String, tradeType: TradeType, entryPrice: Double, quantity: Int, notes: String? = nil) {
        guard let userId = authService.currentUser?.id else {
            self.errorMessage = "User not authenticated"
            self.showError = true
            return
        }
        
        guard !ticker.isEmpty, entryPrice > 0, quantity > 0 else {
            self.errorMessage = "Please check your input values"
            self.showError = true
            return
        }
        
        var newTrade = Trade(ticker: ticker.uppercased(), tradeType: tradeType, entryPrice: entryPrice, quantity: quantity, userId: userId)
        newTrade.notes = notes
        
        addTrade(newTrade)
    }
    
    func closeTrade(_ trade: Trade, exitPrice: Double) {
        var updatedTrade = trade
        updatedTrade.exitPrice = exitPrice
        updatedTrade.exitDate = Date()
        updatedTrade.isOpen = false
        
        Task {
            do {
                try await firestoreService.updateTrade(updatedTrade)
                // Update user stats
                await updateUserStats()
                // The listener will automatically update the trades array
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to close trade: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func updateTrade(_ trade: Trade, ticker: String? = nil, entryPrice: Double? = nil, quantity: Int? = nil, notes: String? = nil) {
        var updatedTrade = trade
        
        if let ticker = ticker, !ticker.isEmpty {
            updatedTrade.ticker = ticker.uppercased()
        }
        if let entryPrice = entryPrice, entryPrice > 0 {
            updatedTrade.entryPrice = entryPrice
        }
        if let quantity = quantity, quantity > 0 {
            updatedTrade.quantity = quantity
        }
        if let notes = notes {
            updatedTrade.notes = notes
        }
        
        Task {
            do {
                try await firestoreService.updateTrade(updatedTrade)
                // The listener will automatically update the trades array
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update trade: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func deleteTrade(_ trade: Trade) {
        Task {
            do {
                try await firestoreService.deleteTrade(tradeId: trade.id)
                // The listener will automatically update the trades array
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete trade: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    private func calculatePortfolioMetrics() {
        guard let userId = authService.currentUser?.id else { return }
        
        let totalValue = trades.reduce(0) { $0 + $1.currentValue }
        let totalPL = trades.filter { !$0.isOpen }.reduce(0) { $0 + $1.profitLoss }
        let openPositions = trades.filter { $0.isOpen }.count
        let totalTrades = trades.count
        let closedTrades = trades.filter { !$0.isOpen }
        let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
        let winRate = closedTrades.count > 0 ? Double(winningTrades) / Double(closedTrades.count) * 100 : 0
        
        var newPortfolio = Portfolio(userId: userId)
        newPortfolio.totalValue = totalValue
        newPortfolio.totalProfitLoss = totalPL
        newPortfolio.openPositions = openPositions
        newPortfolio.totalTrades = totalTrades
        newPortfolio.winRate = winRate
        newPortfolio.dayProfitLoss = calculateDayProfitLoss()
        
        self.portfolio = newPortfolio
    }
    
    private func calculateDayProfitLoss() -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        let todaysTrades = trades.filter { trade in
            if let exitDate = trade.exitDate {
                return Calendar.current.isDate(exitDate, inSameDayAs: today)
            }
            return false
        }
        return todaysTrades.reduce(0) { $0 + $1.profitLoss }
    }
    
    private func updateUserStats() async {
        guard let userId = authService.currentUser?.id,
              let portfolio = portfolio else { return }
        
        do {
            try await firestoreService.updateUserStats(
                userId: userId,
                totalProfitLoss: portfolio.totalProfitLoss,
                winRate: portfolio.winRate
            )
        } catch {
            print("Failed to update user stats: \(error)")
        }
    }
    
    func refreshData() {
        loadPortfolioData()
    }
    
    func getBestPerformingTrade() -> Trade? {
        return trades.filter { !$0.isOpen }.max(by: { $0.profitLoss < $1.profitLoss })
    }
    
    func getTotalInvestedAmount() -> Double {
        return trades.reduce(0) { total, trade in
            total + (trade.entryPrice * Double(trade.quantity))
        }
    }
    
    func getOpenPositionsCount() -> Int {
        return trades.filter { $0.isOpen }.count
    }
    
    func getClosedPositionsCount() -> Int {
        return trades.filter { !$0.isOpen }.count
    }
    
    func getWinRate() -> Double {
        let closedTrades = trades.filter { !$0.isOpen }
        guard !closedTrades.isEmpty else { return 0 }
        let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
        return Double(winningTrades) / Double(closedTrades.count) * 100
    }
    
    func getTotalProfitLoss() -> Double {
        return trades.filter { !$0.isOpen }.reduce(0) { $0 + $1.profitLoss }
    }
}
