// File: Core/Profile/Views/ProfileTabContents.swift

import SwiftUI

// MARK: - Overview Tab
struct ProfileOverviewTab: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Performance Dashboard
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Performance")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("All Time")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                // Performance Cards Grid - Real Data
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 12) {
                    PerformanceCard(
                        title: "Total P&L",
                        value: portfolioViewModel.portfolio?.totalProfitLoss.asCurrencyWithSign ?? "$0.00",
                        color: (portfolioViewModel.portfolio?.totalProfitLoss ?? 0) >= 0 ? .marketGreen : .marketRed,
                        icon: "dollarsign.circle"
                    )
                    
                    PerformanceCard(
                        title: "Win Rate",
                        value: portfolioViewModel.portfolio?.winRate.asPercentage ?? "0%",
                        color: .arkadGold,
                        icon: "target"
                    )
                    
                    PerformanceCard(
                        title: "Total Trades",
                        value: "\(portfolioViewModel.trades.count)",
                        color: .arkadGold,
                        icon: "chart.bar"
                    )
                    
                    PerformanceCard(
                        title: "Open Positions",
                        value: "\(portfolioViewModel.trades.filter { $0.isOpen }.count)",
                        color: .marketGreen,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
                .padding(.horizontal)
            }
            
            // Portfolio Allocation - Real Data
            if !portfolioViewModel.trades.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Activity")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        ForEach(portfolioViewModel.trades.prefix(3), id: \.id) { trade in
                            RecentTradeActivityRow(trade: trade)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // Empty State
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("Start Your Trading Journey")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text("Add your first trade to see your performance metrics here")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    NavigationLink(destination: PortfolioView()) {
                        Text("Add First Trade")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.arkadBlack)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.arkadGold)
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 40)
                .padding(.horizontal)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Trades Tab
struct ProfileTradesTab: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            if !portfolioViewModel.trades.isEmpty {
                // Trading Stats Summary - Real Data
                VStack(alignment: .leading, spacing: 16) {
                    Text("Trading Summary")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        TradingStatCard(
                            title: "Total Trades",
                            value: "\(portfolioViewModel.trades.count)",
                            color: .arkadGold
                        )
                        TradingStatCard(
                            title: "Open Positions",
                            value: "\(portfolioViewModel.trades.filter { $0.isOpen }.count)",
                            color: .marketGreen
                        )
                        TradingStatCard(
                            title: "Closed Trades",
                            value: "\(portfolioViewModel.trades.filter { !$0.isOpen }.count)",
                            color: .arkadGold
                        )
                    }
                    .padding(.horizontal)
                }
                
                // All Trades List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("All Trades")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(portfolioViewModel.trades.count) total")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(portfolioViewModel.trades.sorted(by: { $0.entryDate > $1.entryDate }), id: \.id) { trade in
                            TradeHistoryRow(trade: trade)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // Empty State
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Trades Yet")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text("Your trading history will appear here once you start adding trades")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    NavigationLink(destination: PortfolioView()) {
                        Text("Add Your First Trade")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.arkadBlack)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.arkadGold)
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 40)
                .padding(.horizontal)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Posts Tab
struct ProfilePostsTab: View {
    var body: some View {
        VStack(spacing: 24) {
            // Posts Stats - Starting from zero
            HStack(spacing: 0) {
                PostStatCard(title: "Posts", value: "0", color: .arkadGold)
                    .frame(maxWidth: .infinity)
                PostStatCard(title: "Likes", value: "0", color: .marketGreen)
                    .frame(maxWidth: .infinity)
                PostStatCard(title: "Comments", value: "0", color: .arkadGold)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            // Empty State for Posts
            VStack(spacing: 16) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("No Posts Yet")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                Text("Share your trading insights and connect with the community")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    // TODO: Navigate to create post
                }) {
                    Text("Create First Post")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadBlack)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(8)
                }
            }
            .padding(.vertical, 40)
            .padding(.horizontal)
        }
        .padding(.top, 20)
    }
}

// MARK: - Supporting Views
struct PerformanceCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Recent Trade Activity Row
struct RecentTradeActivityRow: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trade.isOpen ? "chart.line.uptrend.xyaxis" : "checkmark.circle.fill")
                .foregroundColor(trade.isOpen ? .arkadGold : .marketGreen)
                .font(.subheadline)
                .frame(width: 24, height: 24)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(trade.isOpen ? "Opened \(trade.ticker) position" : "Closed \(trade.ticker) position")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(timeAgo(from: trade.entryDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if !trade.isOpen, let exitPrice = trade.exitPrice {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(trade.profitLoss >= 0 ? "+$\(trade.profitLoss, specifier: "%.0f")" : "-$\(abs(trade.profitLoss), specifier: "%.0f")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let days = Int(interval / 86400)
        let hours = Int(interval / 3600) % 24
        
        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else {
            return "Now"
        }
    }
}

// MARK: - Trading Stat Card
struct TradingStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Trade History Row
struct TradeHistoryRow: View {
    let trade: Trade
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.ticker)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(trade.isOpen ? "OPEN" : "CLOSED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(trade.isOpen ? Color.arkadGold.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(trade.isOpen ? .arkadGold : .gray)
                        .cornerRadius(4)
                }
                
                Text("\(trade.quantity) shares @ $\(trade.entryPrice, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(formatDate(trade.entryDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if trade.isOpen {
                    Text("$\(trade.currentValue, specifier: "%.0f")")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                    
                    Text("Current Value")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text(trade.profitLoss >= 0 ? "+$\(trade.profitLoss, specifier: "%.0f")" : "-$\(abs(trade.profitLoss), specifier: "%.0f")")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                    
                    Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(trade.profitLossPercentage, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Post Stat Card
struct PostStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}
