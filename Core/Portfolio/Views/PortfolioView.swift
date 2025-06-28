// File: Core/Portfolio/Views/PortfolioView.swift
// Replace your existing PortfolioView with this minimal version to avoid conflicts

import SwiftUI

struct PortfolioView: View {
    @State private var showAddTrade = false
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Portfolio Value
                    VStack(spacing: 16) {
                        Text(portfolioViewModel.portfolio?.totalValue.asCurrency ?? "$0.00")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: dayChangeIcon)
                                .font(.caption)
                                .foregroundColor(dayChangeColor)
                            
                            Text(portfolioViewModel.portfolio?.dayProfitLoss.asCurrencyWithSign ?? "$0.00")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(dayChangeColor)
                            
                            Text("(\(String(format: "%.1f", portfolioViewModel.portfolio?.dayProfitLossPercentage ?? 0))%)")
                                .font(.subheadline)
                                .foregroundColor(dayChangeColor)
                            
                            Text("today")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Stats Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        StatCard(
                            title: "Win Rate",
                            value: "\(String(format: "%.0f", portfolioViewModel.portfolio?.winRate ?? 0))%",
                            icon: "target",
                            color: .arkadGold
                        )
                        
                        StatCard(
                            title: "Open Positions",
                            value: "\(portfolioViewModel.trades.filter { $0.isOpen }.count)",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .arkadGold
                        )
                        
                        StatCard(
                            title: "Total Trades",
                            value: "\(portfolioViewModel.trades.count)",
                            icon: "chart.bar.fill",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Best Trade",
                            value: bestTradeValue,
                            icon: "crown.fill",
                            color: .marketGreen
                        )
                    }
                    
                    // Recent Trades
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Trades")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                        }
                        
                        if portfolioViewModel.trades.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "chart.line.uptrend.xyaxis.circle")
                                    .font(.system(size: 32))
                                    .foregroundColor(.arkadGold.opacity(0.6))
                                
                                VStack(spacing: 8) {
                                    Text("Start Trading")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray)
                                    
                                    Text("Add your first trade to track your portfolio performance")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(32)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .gray.opacity(0.05), radius: 4, x: 0, y: 2)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(portfolioViewModel.trades.prefix(3), id: \.id) { trade in
                                    Button(action: {}) {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(statusColor(for: trade))
                                                .frame(width: 8, height: 8)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack {
                                                    Text(trade.ticker)
                                                        .font(.headline)
                                                        .fontWeight(.semibold)
                                                    
                                                    if trade.isOpen {
                                                        Text("OPEN")
                                                            .font(.caption2)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.arkadGold)
                                                            .padding(.horizontal, 4)
                                                            .padding(.vertical, 1)
                                                            .background(Color.arkadGold.opacity(0.2))
                                                            .cornerRadius(3)
                                                    }
                                                    
                                                    Spacer()
                                                }
                                                
                                                Text("\(trade.quantity) shares @ $\(String(format: "%.2f", trade.entryPrice))")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 2) {
                                                if trade.isOpen {
                                                    Text("$\(String(format: "%.0f", trade.currentValue))")
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.arkadGold)
                                                } else {
                                                    Text(trade.profitLoss >= 0 ? "+$\(String(format: "%.0f", trade.profitLoss))" : "-$\(String(format: "%.0f", abs(trade.profitLoss)))")
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                                                }
                                            }
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: .gray.opacity(0.05), radius: 4, x: 0, y: 2)
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationBarHidden(true)
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showAddTrade = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle()
                                        .fill(Color.arkadGold)
                                        .shadow(color: .arkadGold.opacity(0.3), radius: 8, x: 0, y: 4)
                                )
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100)
                    }
                }
            )
        }
        .sheet(isPresented: $showAddTrade) {
            AddTradeView()
                .environmentObject(portfolioViewModel)
                .environmentObject(authViewModel)
        }
        .refreshable {
            portfolioViewModel.loadPortfolioData()
        }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
        }
    }
    
    private var dayChangeColor: Color {
        let change = portfolioViewModel.portfolio?.dayProfitLoss ?? 0
        return change >= 0 ? .marketGreen : .marketRed
    }
    
    private var dayChangeIcon: String {
        let change = portfolioViewModel.portfolio?.dayProfitLoss ?? 0
        return change >= 0 ? "arrow.up.right" : "arrow.down.right"
    }
    
    private var bestTradeValue: String {
        let bestTrade = portfolioViewModel.trades
            .filter { !$0.isOpen }
            .max(by: { $0.profitLoss < $1.profitLoss })
        
        guard let trade = bestTrade, trade.profitLoss > 0 else { return "$0" }
        return "+$\(String(format: "%.0f", trade.profitLoss))"
    }
    
    private func statusColor(for trade: Trade) -> Color {
        if trade.isOpen {
            return .arkadGold
        } else {
            return trade.profitLoss >= 0 ? .marketGreen : .marketRed
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                HStack {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    PortfolioView()
        .environmentObject(AuthViewModel())
}
