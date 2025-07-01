// MARK: - Enhanced PortfolioViewModel (Replace your existing one)
// File: Core/Portfolio/ViewModels/PortfolioViewModel.swift

import Foundation
import SwiftUI

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var trades: [Trade] = []
    @Published var portfolio: Portfolio?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let dataService = DataService.shared
    
    init() {
        loadPortfolioData()
    }
    
    func loadPortfolioData() {
        isLoading = true
        
        // Load trades from data service
        self.trades = dataService.trades
        
        // Calculate portfolio metrics
        calculatePortfolioMetrics()
        
        isLoading = false
    }
    
    // MARK: - Enhanced Core Functions
    
    func addTrade(_ trade: Trade) {
        trades.append(trade)
        Task {
            do {
                try await dataService.addTrade(trade)
                calculatePortfolioMetrics()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to add trade: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func addTradeSimple(ticker: String, tradeType: TradeType, entryPrice: Double, quantity: Int, notes: String? = nil) {
        guard let userId = AuthService.shared.currentUser?.id else {
            self.errorMessage = "User not authenticated"
            self.showError = true
            return
        }
        
        // Validate input
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
        if let index = trades.firstIndex(where: { $0.id == trade.id }) {
            trades[index].exitPrice = exitPrice
            trades[index].exitDate = Date()
            trades[index].isOpen = false
            
            Task {
                do {
                    try await dataService.updateTrade(trades[index])
                    await MainActor.run {
                        self.calculatePortfolioMetrics()
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to close trade: \(error.localizedDescription)"
                        self.showError = true
                    }
                }
            }
        }
    }
    
    func deleteTrade(_ trade: Trade) {
        trades.removeAll { $0.id == trade.id }
        Task {
            do {
                try await dataService.deleteTrade(trade)
                await MainActor.run {
                    self.calculatePortfolioMetrics()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete trade: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func updateTrade(_ trade: Trade, ticker: String? = nil, entryPrice: Double? = nil, quantity: Int? = nil, notes: String? = nil) {
        guard let index = trades.firstIndex(where: { $0.id == trade.id }) else {
            self.errorMessage = "Trade not found"
            self.showError = true
            return
        }
        
        if let ticker = ticker, !ticker.isEmpty {
            trades[index].ticker = ticker.uppercased()
        }
        if let entryPrice = entryPrice, entryPrice > 0 {
            trades[index].entryPrice = entryPrice
        }
        if let quantity = quantity, quantity > 0 {
            trades[index].quantity = quantity
        }
        if let notes = notes {
            trades[index].notes = notes
        }
        
        Task {
            do {
                try await dataService.updateTrade(trades[index])
                await MainActor.run {
                    self.calculatePortfolioMetrics()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update trade: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    private func calculatePortfolioMetrics() {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        let totalValue = trades.reduce(0) { $0 + $1.currentValue }
        let totalPL = trades.filter { !$0.isOpen }.reduce(0) { $0 + $1.profitLoss }
        let openPositions = trades.filter { $0.isOpen }.count
        let totalTrades = trades.count
        let winningTrades = trades.filter { !$0.isOpen && $0.profitLoss > 0 }.count
        let winRate = totalTrades > 0 ? Double(winningTrades) / Double(totalTrades) * 100 : 0
        
        var newPortfolio = Portfolio(userId: userId)
        newPortfolio.totalValue = totalValue
        newPortfolio.totalProfitLoss = totalPL
        newPortfolio.openPositions = openPositions
        newPortfolio.totalTrades = totalTrades
        newPortfolio.winRate = winRate
        newPortfolio.dayProfitLoss = 245.0 // Mock data - replace with real calculation
        
        self.portfolio = newPortfolio
    }
    
    // MARK: - Helper Functions
    
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
}
