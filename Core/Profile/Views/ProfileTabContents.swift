// File: Core/Profile/Views/ProfileTabContents.swift
// Fixed ProfileTab contents - uses centralized TradeFilter from TradingEnums.swift

import SwiftUI

// MARK: - Profile Overview Tab
struct ProfileOverviewTab: View {
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Quick Stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                simpleStatCard(
                    title: "Open Positions",
                    value: "\(portfolioViewModel.portfolio?.openPositions ?? 0)",
                    icon: "clock.fill",
                    color: .blue
                )
                
                simpleStatCard(
                    title: "Closed Trades",
                    value: "\(portfolioViewModel.trades.filter { !$0.isOpen }.count)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                simpleStatCard(
                    title: "Best Trade",
                    value: portfolioViewModel.portfolioAnalytics?.bestTrade?.profitLoss.asCurrency ?? "$0",
                    icon: "trophy.fill",
                    color: .yellow
                )
                
                simpleStatCard(
                    title: "Profit Factor",
                    value: String(format: "%.2f", portfolioViewModel.portfolioAnalytics?.profitFactor ?? 0),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )
            }
            .padding(.horizontal)
            
            // Recent Trades
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Recent Trades")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    NavigationLink(destination: PortfolioView().environmentObject(portfolioViewModel)) {
                        Text("View All")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                if portfolioViewModel.trades.isEmpty {
                    EmptyTradesView()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(portfolioViewModel.trades.prefix(5)), id: \.id) { trade in
                                RecentTradeCard(trade: trade)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Spacer(minLength: 50)
        }
        .padding(.top, 20)
    }
    
    // Simple stat card (inline component)
    private func simpleStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Profile Trades Tab
struct ProfileTradesTab: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @State private var selectedFilter: TradeFilter = .all
    @State private var searchText = ""
    
    var filteredTrades: [Trade] {
        var trades = portfolioViewModel.trades
        
        // Apply search filter
        if !searchText.isEmpty {
            trades = trades.filter { trade in
                trade.ticker.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .open:
            trades = trades.filter { $0.isOpen }
        case .closed:
            trades = trades.filter { !$0.isOpen }
        case .profitable:
            trades = trades.filter { !$0.isOpen && $0.profitLoss > 0 }
        case .losses:
            trades = trades.filter { !$0.isOpen && $0.profitLoss < 0 }
        }
        
        return trades.sorted { $0.entryDate > $1.entryDate }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Search and Filter Controls
            VStack(spacing: 12) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search trades...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(TradeFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
            
            // Trades List
            if filteredTrades.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text(searchText.isEmpty ? "No trades yet" : "No trades match your search")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    if searchText.isEmpty {
                        NavigationLink(destination: PortfolioView().environmentObject(portfolioViewModel)) {
                            Text("Add Your First Trade")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.top, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTrades, id: \.id) { trade in
                            ProfileTradeCard(trade: trade)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer(minLength: 50)
        }
        .padding(.top, 20)
    }
}

// MARK: - Profile Analytics Tab
struct ProfileAnalyticsTab: View {
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let analytics = portfolioViewModel.portfolioAnalytics {
                    // Performance Metrics
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Performance Metrics")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            simpleAnalyticsCard(title: "Total Return", value: analytics.totalReturn.asCurrencyWithSign, color: analytics.totalReturn >= 0 ? .green : .red)
                            simpleAnalyticsCard(title: "Return %", value: analytics.totalReturnPercentage.asPercentageWithSign, color: analytics.totalReturnPercentage >= 0 ? .green : .red)
                            simpleAnalyticsCard(title: "Avg Hold Time", value: "\(Int(analytics.averageHoldTime)) days", color: .blue)
                            simpleAnalyticsCard(title: "Avg Trade Size", value: analytics.averageTradeSize.asCurrency, color: .blue)
                            simpleAnalyticsCard(title: "Sharpe Ratio", value: String(format: "%.2f", analytics.sharpeRatio), color: .blue)
                            simpleAnalyticsCard(title: "Max Drawdown", value: String(format: "%.1f%%", analytics.maxDrawdown), color: .red)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Best & Worst Trades
                    if let bestTrade = analytics.bestTrade {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Best Trade")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            TradeHighlightCard(trade: bestTrade, type: .best)
                                .padding(.horizontal)
                        }
                    }
                    
                    if let worstTrade = analytics.worstTrade {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Worst Trade")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            TradeHighlightCard(trade: worstTrade, type: .worst)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    Text("No analytics available yet")
                        .foregroundColor(.gray)
                        .padding(.top, 50)
                }
                
                Spacer(minLength: 50)
            }
        }
        .padding(.top, 20)
    }
    
    // Simple analytics card (inline component)
    private func simpleAnalyticsCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Profile Achievements Tab
struct ProfileAchievementsTab: View {
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(generateAchievements(), id: \.id) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        }
        .padding(.top, 20)
    }
    
    private func generateAchievements() -> [Achievement] {
        let totalTrades = portfolioViewModel.trades.count
        let totalPL = portfolioViewModel.portfolio?.totalProfitLoss ?? 0
        let winRate = portfolioViewModel.portfolio?.winRate ?? 0
        let openPositions = portfolioViewModel.portfolio?.openPositions ?? 0
        
        return [
            Achievement(id: "first_trade", title: "First Trade", description: "Made your first trade", icon: "star.fill", isUnlocked: totalTrades > 0),
            Achievement(id: "profit_maker", title: "Profit Maker", description: "Earned $1000 in profits", icon: "dollarsign.circle.fill", isUnlocked: totalPL >= 1000),
            Achievement(id: "active_trader", title: "Active Trader", description: "Complete 10 trades", icon: "chart.line.uptrend.xyaxis", isUnlocked: totalTrades >= 10),
            Achievement(id: "consistent_winner", title: "Consistent Winner", description: "Achieve 70% win rate", icon: "trophy.fill", isUnlocked: winRate >= 70.0 && totalTrades >= 5),
            Achievement(id: "portfolio_builder", title: "Portfolio Builder", description: "Have 5 open positions", icon: "building.columns.fill", isUnlocked: openPositions >= 5),
            Achievement(id: "big_winner", title: "Big Winner", description: "Earn $10,000 in profits", icon: "crown.fill", isUnlocked: totalPL >= 10000)
        ]
    }
}

// MARK: - Supporting Views

struct RecentTradeCard: View {
    let trade: Trade
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(trade.ticker)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if trade.isOpen {
                    Text("OPEN")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Text("\(trade.quantity) shares")
                .font(.caption)
                .foregroundColor(.gray)
            
            if trade.isOpen {
                Text("Entry: \(trade.entryPrice.asCurrency)")
                    .font(.caption)
                    .foregroundColor(.blue)
            } else {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
            }
        }
        .padding()
        .frame(width: 120, height: 80)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

struct ProfileTradeCard: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.ticker)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(trade.tradeType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    
                    if trade.isOpen {
                        Text("OPEN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text("\(trade.quantity) shares @ \(trade.entryPrice.asCurrency)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(formatDate(trade.entryDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if trade.isOpen {
                    Text(trade.currentValue.asCurrency)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text(trade.profitLoss.asCurrencyWithSign)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                    
                    Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.1f", trade.profitLossPercentage))%")
                        .font(.caption)
                        .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var statusColor: Color {
        if trade.isOpen {
            return .blue
        } else {
            return trade.profitLoss >= 0 ? .green : .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct EmptyTradesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No trades yet")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            NavigationLink(destination: PortfolioView()) {
                Text("Add Your First Trade")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct TradeHighlightCard: View {
    let trade: Trade
    let type: TradeHighlightType
    
    enum TradeHighlightType {
        case best, worst
        
        var color: Color {
            switch self {
            case .best: return .green
            case .worst: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .best: return "arrow.up.circle.fill"
            case .worst: return "arrow.down.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(type.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trade.ticker)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(trade.quantity) shares")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(type.color)
                
                Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.1f", trade.profitLossPercentage))%")
                    .font(.caption)
                    .foregroundColor(type.color)
            }
        }
        .padding()
        .background(type.color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.largeTitle)
                .foregroundColor(achievement.isUnlocked ? .blue : .gray)
            
            VStack(spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(achievement.isUnlocked ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(achievement.isUnlocked ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
}

#Preview {
    ProfileOverviewTab(portfolioViewModel: PortfolioViewModel())
}
