//
//  PortfolioViewModel.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Core/Portfolio/ViewModels/PortfolioViewModel.swift

import Foundation

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
    
    func addTrade(_ trade: Trade) {
        trades.append(trade)
        dataService.addTrade(trade)
        calculatePortfolioMetrics()
    }
    
    func closeTrade(_ trade: Trade, exitPrice: Double) {
        if let index = trades.firstIndex(where: { $0.id == trade.id }) {
            trades[index].exitPrice = exitPrice
            trades[index].exitDate = Date()
            trades[index].isOpen = false
            
            dataService.updateTrade(trades[index])
            calculatePortfolioMetrics()
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
        newPortfolio.dayProfitLoss = 245.0 // Mock data for today's P&L
        
        self.portfolio = newPortfolio
    }
}
