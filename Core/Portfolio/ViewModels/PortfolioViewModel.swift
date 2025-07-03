// File: Core/Portfolio/ViewModels/PortfolioViewModel.swift

import Foundation
import SwiftUI

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var trades: [FirebaseTrade] = []
    @Published var portfolio: Portfolio?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let firestoreService = FirestoreService.shared
    private let authService = FirebaseAuthService.shared
    
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
    
    func addTrade(_ trade: FirebaseTrade) {
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
        
        var newTrade = FirebaseTrade(ticker: ticker.uppercased(), tradeType: tradeType, entryPrice: entryPrice, quantity: quantity, userId: userId)
        newTrade.notes = notes
        
        addTrade(newTrade)
    }
    
    func closeTrade(_ trade: FirebaseTrade, exitPrice: Double) {
        var updatedTrade = trade
        updatedTrade.exitPrice = exitPrice
        updatedTrade.exitDate = Date()
        updatedTrade.isOpen = false
        
        Task {
            do {
                try await firestoreService.updateTrade(updatedTrade)
                // The listener will automatically update the trades array
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to close trade: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func deleteTrade(_ trade: FirebaseTrade) {
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
        
        var newPortfolio = Portfolio(userId: UUID(uuidString: userId) ?? UUID())
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
    
    func refreshData() {
        loadPortfolioData()
    }
    
    func getBestPerformingTrade() -> FirebaseTrade? {
        return trades.filter { !$0.isOpen }.max(by: { $0.profitLoss < $1.profitLoss })
    }
    
    func getTotalInvestedAmount() -> Double {
        return trades.reduce(0) { total, trade in
            total + (trade.entryPrice * Double(trade.quantity))
        }
    }
}
