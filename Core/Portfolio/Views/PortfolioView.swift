// File: Core/Portfolio/Views/PortfolioView.swift
// Simplified Portfolio View

import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var trades: [Trade] = []
    @State private var showAddTrade = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Portfolio Summary
                VStack(spacing: 10) {
                    Text("Total Value")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("$\(String(format: "%.2f", totalValue))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("P&L: $\(String(format: "%.2f", totalProfitLoss))")
                            .foregroundColor(totalProfitLoss >= 0 ? .green : .red)
                        
                        Text("Win Rate: \(String(format: "%.1f", winRate))%")
                            .foregroundColor(.gray)
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding()
                
                // Trades List
                if trades.isEmpty {
                    VStack {
                        Text("No trades yet")
                            .foregroundColor(.gray)
                        Button("Add Your First Trade") {
                            showAddTrade = true
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.top, 50)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(trades) { trade in
                                TradeRow(trade: trade)
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Portfolio")
            .navigationBarItems(trailing: Button("Add Trade") { showAddTrade = true })
            .sheet(isPresented: $showAddTrade) {
                AddTradeView()
            }
            .onAppear {
                loadTrades()
            }
        }
    }
    
    private var totalValue: Double {
        trades.reduce(0) { $0 + $1.currentValue }
    }
    
    private var totalProfitLoss: Double {
        trades.filter { !$0.isOpen }.reduce(0) { $0 + $1.profitLoss }
    }
    
    private var winRate: Double {
        let closedTrades = trades.filter { !$0.isOpen }
        guard !closedTrades.isEmpty else { return 0 }
        let wins = closedTrades.filter { $0.profitLoss > 0 }.count
        return Double(wins) / Double(closedTrades.count) * 100
    }
    
    private func loadTrades() {
        guard let userId = authService.currentUser?.id else { return }
        
        authService.listenToUserTrades(userId: userId) { trades in
            self.trades = trades
        }
    }
}

struct TradeRow: View {
    let trade: Trade
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(trade.ticker)
                    .font(.headline)
                Text("\(trade.quantity) shares @ $\(String(format: "%.2f", trade.entryPrice))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                if trade.isOpen {
                    Text("OPEN")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("$\(String(format: "%.2f", trade.profitLoss))")
                        .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    PortfolioView()
        .environmentObject(FirebaseAuthService.shared)
}
