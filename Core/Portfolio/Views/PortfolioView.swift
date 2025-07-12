// File: Core/Portfolio/Views/PortfolioView.swift
// Complete Redesign - Modern Fintech Portfolio Interface with Deposit/Withdraw

import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    
    @State private var showAddTrade = false
    @State private var showTradeActions = false
    @State private var selectedTrade: Trade?
    @State private var animateContent = false
    @State private var selectedTimeframe: TimeFrame = .monthly
    
    var body: some View {
        ZStack {
            // Premium background
            RadialGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.0),
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color.white
                ],
                center: .topLeading,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Portfolio Header
                    portfolioHeaderSection
                        .padding(.top, 10)
                    
                    // Performance Chart Card
                    performanceChartCard
                        .padding(.top, 24)
                    
                    // Quick Insights Bar
                    quickInsightsBar
                        .padding(.top, 20)
                    
                    // Main Content
                    mainContentSection
                        .padding(.top, 24)
                    
                    // Bottom spacing for floating button
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, 20)
            }
            
            // Floating Action Button
            floatingActionButton
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddTrade) {
            AddTradeView()
                .environmentObject(authService)
                .environmentObject(portfolioViewModel)
        }
        .sheet(isPresented: $showTradeActions) {
            if let trade = selectedTrade {
                TradeActionsSheet(trade: trade)
                    .environmentObject(portfolioViewModel)
            }
        }
        .sheet(isPresented: $portfolioViewModel.showStartingCapitalPrompt) {
            StartingCapitalSheet()
                .environmentObject(portfolioViewModel)
        }
        .sheet(isPresented: $portfolioViewModel.showDepositWithdrawSheet) {
            DepositWithdrawSheet()
                .environmentObject(portfolioViewModel)
        }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.1)) {
                animateContent = true
            }
        }
    }
    
    // MARK: - Portfolio Header Section
    private var portfolioHeaderSection: some View {
        VStack(spacing: 16) {
            // Greeting & Time
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(authService.currentUser?.fullName.components(separatedBy: " ").first ?? "Trader")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Profile/Settings Button
                Button(action: {}) {
                    Circle()
                        .fill(Color.arkadGold.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(userInitials)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.arkadGold)
                        )
                }
            }
            
            // Portfolio Value Section with Deposit/Withdraw Button
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Portfolio Value")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 8) {
                            Text(portfolioValue.asCurrency)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .opacity(animateContent ? 1 : 0)
                                .scaleEffect(animateContent ? 1 : 0.8)
                                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateContent)
                            
                            if totalProfitLoss != 0 {
                                Image(systemName: totalProfitLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(totalProfitLoss >= 0 ? .green : .red)
                                    .opacity(animateContent ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateContent)
                            }
                        }
                        
                        // Daily change
                        HStack(spacing: 6) {
                            Text(totalProfitLoss.asCurrencyWithSign)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(totalProfitLoss >= 0 ? .green : .red)
                            
                            Text("(\(String(format: "%.2f", returnPercentage))%)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(totalProfitLoss >= 0 ? .green : .red)
                        }
                        .opacity(animateContent ? 1 : 0)
                        .animation(.easeInOut(duration: 0.6).delay(0.3), value: animateContent)
                    }
                    
                    Spacer()
                    
                    // NEW: Deposit/Withdraw Button
                    Button(action: {
                        portfolioViewModel.showDepositWithdrawSheet = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.minus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.arkadGold)
                            
                            Text("Deposit/\nWithdraw")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.arkadGold)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.arkadGold.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .opacity(animateContent ? 1 : 0.8)
                    .scaleEffect(animateContent ? 1 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: animateContent)
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Performance Chart Card
    private var performanceChartCard: some View {
        VStack(spacing: 20) {
            // Chart Header
            HStack {
                Text("Performance")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Time filter
                timeframeSelector
            }
            
            // Chart
            modernPerformanceChart
                .frame(height: 180)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 20, x: 0, y: 8)
        )
    }
    
    // MARK: - Timeframe Selector
    private var timeframeSelector: some View {
        HStack(spacing: 4) {
            ForEach([TimeFrame.weekly, TimeFrame.monthly, TimeFrame.allTime], id: \.self) { timeframe in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTimeframe = timeframe
                    }
                }) {
                    Text(timeframe.shortName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedTimeframe == timeframe ? Color.arkadGold : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.08))
        )
    }
    
    // MARK: - Modern Performance Chart
    private var modernPerformanceChart: some View {
        GeometryReader { geometry in
            let data = generateChartData()
            let maxValue = data.max() ?? portfolioValue
            let minValue = data.min() ?? portfolioValue
            let range = maxValue - minValue
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Background grid (subtle)
                Path { path in
                    for i in 1...3 {
                        let y = height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.06), lineWidth: 1)
                
                if range > 0 && data.count > 1 {
                    // Area fill with gradient
                    Path { path in
                        guard !data.isEmpty else { return }
                        
                        path.move(to: CGPoint(x: 0, y: height))
                        
                        for (index, value) in data.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(data.count - 1)
                            let y = height - (height * CGFloat((value - minValue) / range))
                            
                            if index == 0 {
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                totalProfitLoss >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3),
                                totalProfitLoss >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Line chart
                    Path { path in
                        guard !data.isEmpty else { return }
                        
                        for (index, value) in data.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(data.count - 1)
                            let y = height - (height * CGFloat((value - minValue) / range))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        totalProfitLoss >= 0 ? Color.green : Color.red,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                } else {
                    // Flat line for no data or no range
                    Path { path in
                        let y = height / 2
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                    
                    Text("No performance data yet")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    
    // MARK: - Quick Insights Bar
    private var quickInsightsBar: some View {
        HStack(spacing: 20) {
            insightItem(
                icon: "target",
                title: "Win Rate",
                value: "\(String(format: "%.0f", winRate))%",
                color: winRate >= 50 ? .green : .red
            )
            
            insightItem(
                icon: "chart.bar.fill",
                title: "Total Trades",
                value: "\(allTrades.count)",
                color: .blue
            )
            
            insightItem(
                icon: "clock.fill",
                title: "Open Positions",
                value: "\(openPositions.count)",
                color: .orange
            )
            
            insightItem(
                icon: "trophy.fill",
                title: "Best Trade",
                value: bestTradeValue,
                color: .arkadGold
            )
        }
        .padding(.horizontal, 20)
    }
    
    private func insightItem(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Main Content Section
    private var mainContentSection: some View {
        VStack(spacing: 24) {
            if openPositions.isEmpty && closedTrades.isEmpty {
                emptyStateView
            } else {
                // Current Positions
                if !openPositions.isEmpty {
                    currentPositionsSection
                }
                
                // Recent Activity
                if !recentTrades.isEmpty {
                    recentActivitySection
                }
            }
        }
    }
    
    // MARK: - Current Positions Section
    private var currentPositionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Positions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(openPositions.count) active position\(openPositions.count == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Button("View All") {
                    // Show all positions
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.arkadGold)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(openPositions.prefix(3)), id: \.id) { trade in
                    modernPositionRow(trade: trade)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Activity")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Latest trades and updates")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button("View All") {
                    // Show all activity
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.arkadGold)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(Array(recentTrades.prefix(5)), id: \.id) { trade in
                    modernActivityRow(trade: trade)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("Start Your Trading Journey")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Log your first trade to begin tracking your portfolio performance and building your trading history.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button("Add Your First Trade") {
                    showAddTrade = true
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.arkadGold, Color.arkadGold.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: Color.arkadGold.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            
            Button("Learn About Portfolio Tracking") {
                // Show tutorial or info
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.arkadGold)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 20, x: 0, y: 8)
        )
    }
    
    // MARK: - Position Row
    private func modernPositionRow(trade: Trade) -> some View {
        HStack(spacing: 16) {
            // Company Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                trade.tradeType.color.opacity(0.2),
                                trade.tradeType.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Text(String(trade.ticker.prefix(2)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(trade.tradeType.color)
            }
            
            // Trade Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.ticker)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(trade.currentValue.asCurrency)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("\(trade.quantity) shares")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    let unrealizedPL = trade.unrealizedPL
                    HStack(spacing: 4) {
                        Image(systemName: unrealizedPL >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        
                        Text(unrealizedPL.asCurrencyWithSign)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(unrealizedPL >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTrade = trade
            showTradeActions = true
        }
    }
    
    // MARK: - Activity Row
    private func modernActivityRow(trade: Trade) -> some View {
        HStack(spacing: 16) {
            // Status Indicator
            Circle()
                .fill(trade.isOpen ? Color.blue : (trade.profitLoss >= 0 ? Color.green : Color.red))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            // Activity Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(trade.isOpen ? "Opened" : "Closed") \(trade.ticker)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if trade.isOpen {
                        Text(trade.currentValue.asCurrency)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    } else {
                        Text(trade.profitLoss.asCurrencyWithSign)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                    }
                }
                
                HStack {
                    Text(timeAgo(from: trade.exitDate ?? trade.entryDate))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(trade.quantity) shares @ \(trade.entryPrice.asCurrency)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTrade = trade
            showTradeActions = true
        }
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: {
                    showAddTrade = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("Add Trade")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: Color.arkadGold.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .scaleEffect(animateContent ? 1 : 0.8)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0), value: animateContent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Fixed Chart Data Generation
    private func generateChartData() -> [Double] {
        // If no performance data, show flat line at current portfolio value
        guard !portfolioViewModel.recentPerformance.isEmpty else {
            let currentValue = portfolioValue
            return [currentValue, currentValue]
        }
        
        // Use actual performance data
        return portfolioViewModel.recentPerformance.map { $0.portfolioValue }
    }
    
    // MARK: - Computed Properties
    private var portfolioValue: Double {
        return portfolioViewModel.portfolio?.totalValue ?? 0.0
    }
    
    private var totalProfitLoss: Double {
        return portfolioViewModel.portfolio?.totalProfitLoss ?? 0.0
    }
    
    private var returnPercentage: Double {
        // Calculate percentage based on actual total invested, not hardcoded value
        let totalInvested = allTrades.reduce(0) { $0 + ($1.entryPrice * Double($1.quantity)) }
        guard totalInvested > 0 else { return 0.0 }
        return (totalProfitLoss / totalInvested) * 100
    }
    
    private var winRate: Double {
        return portfolioViewModel.portfolio?.winRate ?? 0.0
    }
    
    private var openPositions: [Trade] {
        portfolioViewModel.trades.filter { $0.isOpen }
    }
    
    private var closedTrades: [Trade] {
        portfolioViewModel.trades.filter { !$0.isOpen }
    }
    
    private var allTrades: [Trade] {
        portfolioViewModel.trades
    }
    
    private var recentTrades: [Trade] {
        portfolioViewModel.trades.sorted { $0.entryDate > $1.entryDate }
    }
    
    private var bestTradeValue: String {
        guard let bestTrade = closedTrades.max(by: { $0.profitLoss < $1.profitLoss }) else {
            return "$0"
        }
        return bestTrade.profitLoss.asCurrency
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
    
    private var userInitials: String {
        let name = authService.currentUser?.fullName ?? "User"
        let components = name.components(separatedBy: " ")
        let firstInitial = String(components.first?.first ?? Character("U"))
        let lastInitial = components.count > 1 ? String(components.last?.first ?? Character("")) : ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
    
    // MARK: - Helper Methods
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let days = Int(interval / 86400)
        let hours = Int(interval / 3600)
        
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - TimeFrame Extension
extension TimeFrame {
    var shortName: String {
        switch self {
        case .weekly: return "1W"
        case .monthly: return "1M"
        case .allTime: return "All"
        default: return "1M"
        }
    }
}
