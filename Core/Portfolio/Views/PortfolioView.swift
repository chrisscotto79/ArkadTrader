// File: Core/Portfolio/Views/PortfolioView.swift

import SwiftUI

struct PortfolioView: View {
    @State private var showAddTrade = false
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                // Portfolio Summary Card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Portfolio Value")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(portfolioViewModel.portfolio?.totalValue.asCurrency ?? "$0.00")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Total P&L")
                                .font(.caption)
                                .foregroundColor(.gray)
                            HStack(spacing: 4) {
                                Text(portfolioViewModel.portfolio?.totalProfitLoss.asCurrencyWithSign ?? "$0.00")
                                    .font(.headline)
                                    .foregroundColor((portfolioViewModel.portfolio?.totalProfitLoss ?? 0) >= 0 ? .marketGreen : .marketRed)
                                if let portfolio = portfolioViewModel.portfolio, portfolio.totalTrades > 0 {
                                    Text("(\(portfolio.totalProfitLossPercentage.asPercentageWithSign))")
                                        .font(.caption)
                                        .foregroundColor((portfolio.totalProfitLoss) >= 0 ? .marketGreen : .marketRed)
                                }
                            }
                        }
                    }
                    
                    HStack {
                        StatCard(
                            title: "Win Rate",
                            value: portfolioViewModel.portfolio?.winRate.asPercentage ?? "0%",
                            color: .arkadGold
                        )
                        StatCard(
                            title: "Total Trades",
                            value: "\(portfolioViewModel.portfolio?.totalTrades ?? 0)",
                            color: .arkadGold
                        )
                        StatCard(
                            title: "Open Positions",
                            value: "\(portfolioViewModel.portfolio?.openPositions ?? 0)",
                            color: .arkadGold
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Trades List
                VStack(alignment: .leading) {
                    HStack {
                        Text("Recent Trades")
                            .font(.headline)
                        Spacer()
                        if !portfolioViewModel.trades.isEmpty {
                            NavigationLink("View All") {
                                AllTradesView()
                                    .environmentObject(portfolioViewModel)
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if portfolioViewModel.trades.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray.opacity(0.5))
                                    
                                    Text("No trades yet")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    Text("Add your first trade to start tracking your portfolio!")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    
                                    Button("Add First Trade") {
                                        showAddTrade = true
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.arkadBlack)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.arkadGold)
                                    .cornerRadius(8)
                                }
                                .padding(.vertical, 40)
                            } else {
                                ForEach(portfolioViewModel.trades.prefix(5)) { trade in
                                    TradeRowView(trade: trade)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddTrade = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.arkadGold)
                    }
                }
            }
            .sheet(isPresented: $showAddTrade) {
                AddTradeView()
                    .environmentObject(portfolioViewModel)
                    .environmentObject(authViewModel)
            }
        }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
        }
    }
}

// MARK: - All Trades View
struct AllTradesView: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(portfolioViewModel.trades.sorted(by: { $0.entryDate > $1.entryDate })) { trade in
                    TradeRowView(trade: trade)
                }
            }
            .padding()
        }
        .navigationTitle("All Trades")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PortfolioView()
        .environmentObject(AuthViewModel())
}
