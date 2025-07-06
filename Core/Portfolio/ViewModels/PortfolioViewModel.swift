// File: Core/Portfolio/ViewModels/PortfolioViewModel.swift
// Simplified Portfolio ViewModel

import Foundation
import SwiftUI

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var trades: [Trade] = []
    @Published var portfolio: Portfolio?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = FirebaseAuthService.shared
    
    init() {
        loadPortfolioData()
    }
    
    func loadPortfolioData() {
        guard let userId = authService.currentUser?.id else { return }
        
        authService.listenToUserTrades(userId: userId) { trades in
            self.trades = trades
            self.calculatePortfolioMetrics()
        }
    }
    
    func addTrade(_ trade: Trade) {
        Task {
            do {
                try await authService.addTrade(trade)
            } catch {
                errorMessage = "Failed to add trade: \(error.localizedDescription)"
                showError = true
            }
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
            } catch {
                errorMessage = "Failed to close trade: \(error.localizedDescription)"
                showError = true
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
        
        self.portfolio = newPortfolio
    }
}
