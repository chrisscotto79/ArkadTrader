// File: Core/Portfolio/Views/PortfolioView.swift
// Complete Redesign - Modern Fintech Portfolio Interface

import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    
    @State private var showAddTrade = false
    @State private var showTradeDetail = false
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
        .sheet(isPresented: $showTradeDetail) {
            if let trade = selectedTrade {
                TradeDetailView(trade: trade)
                    .environmentObject(portfolioViewModel)
            }
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
            
            // Portfolio Value Section
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
                }
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
            let maxValue = data.max() ?? 10000
            let minValue = data.min() ?? 10000
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
                
                if range > 0 {
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
                                Color.arkadGold.opacity(0.2),
                                Color.arkadGold.opacity(0.05),
                                Color.arkadGold.opacity(0.01)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Main line with glow effect
                    Path { path in
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
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.arkadGold.opacity(0.3), radius: 4, x: 0, y: 0)
                    
                    // Current value point
                    if let lastValue = data.last {
                        let x = width
                        let y = height - (height * CGFloat((lastValue - minValue) / range))
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.arkadGold, lineWidth: 3)
                            )
                            .position(x: x, y: y)
                            .shadow(color: Color.arkadGold.opacity(0.4), radius: 8, x: 0, y: 2)
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Insights Bar
    private var quickInsightsBar: some View {
        HStack(spacing: 16) {
            quickInsightItem(
                title: "Win Rate",
                value: "\(String(format: "%.0f", winRate))%",
                color: winRate >= 60 ? .green : (winRate >= 40 ? .orange : .red),
                icon: "target"
            )
            
            quickInsightItem(
                title: "Total Trades",
                value: "\(portfolioViewModel.trades.count)",
                color: .arkadGold,
                icon: "chart.bar.fill"
            )
            
            quickInsightItem(
                title: "Open Positions",
                value: "\(openPositions.count)",
                color: .blue,
                icon: "clock.fill"
            )
            
            quickInsightItem(
                title: "Best Trade",
                value: bestTradeValue,
                color: .green,
                icon: "trophy.fill"
            )
        }
        .padding(.horizontal, 4)
    }
    
    private func quickInsightItem(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                )
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 4)
        )
        .opacity(animateContent ? 1 : 0)
        .scaleEffect(animateContent ? 1 : 0.9)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: animateContent)
    }
    
    // MARK: - Main Content Section
    private var mainContentSection: some View {
        VStack(spacing: 24) {
            // Current Positions
            if !openPositions.isEmpty {
                currentPositionsCard
            }
            
            // Recent Activity
            if !portfolioViewModel.trades.isEmpty {
                recentActivityCard
            } else {
                emptyStateCard
            }
        }
    }
    
    // MARK: - Current Positions Card
    private var currentPositionsCard: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Positions")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(openPositions.count) active positions")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button("View All") {
                    // Navigate to all positions
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.arkadGold)
            }
            
            // Positions List
            VStack(spacing: 12) {
                ForEach(openPositions.prefix(4), id: \.id) { trade in
                    modernPositionRow(trade: trade)
                }
            }
            
            if openPositions.count > 4 {
                Button("Show \(openPositions.count - 4) more positions") {
                    // Show more
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.arkadGold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.arkadGold.opacity(0.05))
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 20, x: 0, y: 8)
        )
    }
    
    // MARK: - Recent Activity Card
    private var recentActivityCard: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Activity")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Latest trades and updates")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                NavigationLink(destination: AllTradesView().environmentObject(portfolioViewModel)) {
                    Text("View All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.arkadGold)
                }
            }
            
            // Activity List
            VStack(spacing: 16) {
                ForEach(recentTrades.prefix(5), id: \.id) { trade in
                    modernActivityRow(trade: trade)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 20, x: 0, y: 8)
        )
    }
    
    // MARK: - Empty State Card
    private var emptyStateCard: some View {
        VStack(spacing: 24) {
            // Illustration
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.arkadGold.opacity(0.1),
                            Color.arkadGold.opacity(0.03)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.arkadGold)
                )
            
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Start Your Trading Journey")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Track your investments, analyze performance, and make informed decisions with detailed insights.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: { showAddTrade = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Add Your First Trade")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.arkadBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.arkadGold, Color.arkadGold.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.arkadGold.opacity(0.3), radius: 12, x: 0, y: 6)
                    }
                    
                    Button("Learn About Portfolio Tracking") {
                        // Show tutorial or info
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.arkadGold)
                }
            }
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
            showTradeDetail = true
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
                    Text(timeAgo(from: trade.entryDate))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(trade.quantity) shares @ \(trade.entryPrice.asCurrency)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTrade = trade
            showTradeDetail = true
        }
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: { showAddTrade = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("Add Trade")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.arkadBlack)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.arkadGold, Color.arkadGold.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.arkadGold.opacity(0.4), radius: 20, x: 0, y: 10)
                    )
                }
                .scaleEffect(animateContent ? 1 : 0.8)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: animateContent)
                .padding(.trailing, 20)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Computed Properties
    private var portfolioValue: Double {
        let initialCapital = 10000.0
        let totalInvested = openPositions.reduce(0) { $0 + ($1.entryPrice * Double($1.quantity)) }
        let currentValue = openPositions.reduce(0) { $0 + $1.currentValue }
        let realizedPL = closedTrades.reduce(0) { $0 + $1.profitLoss }
        let cash = initialCapital - totalInvested + realizedPL
        
        return currentValue + cash
    }
    
    private var totalProfitLoss: Double {
        return portfolioValue - 10000.0
    }
    
    private var returnPercentage: Double {
        return (totalProfitLoss / 10000.0) * 100
    }
    
    private var winRate: Double {
        guard !closedTrades.isEmpty else { return 0 }
        let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
        return Double(winningTrades) / Double(closedTrades.count) * 100
    }
    
    private var openPositions: [Trade] {
        portfolioViewModel.trades.filter { $0.isOpen }
    }
    
    private var closedTrades: [Trade] {
        portfolioViewModel.trades.filter { !$0.isOpen }
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
    private func generateChartData() -> [Double] {
        var data: [Double] = []
        let baseValue = 10000.0
        var currentValue = baseValue
        
        let days = selectedTimeframe == .weekly ? 7 : (selectedTimeframe == .monthly ? 30 : 90)
        
        for _ in 0..<days {
            let change = Double.random(in: -0.02...0.025)
            currentValue *= (1 + change)
            data.append(currentValue)
        }
        
        // End with current portfolio value
        if !data.isEmpty {
            data[data.count - 1] = portfolioValue
        }
        
        return data
    }
    
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

// MARK: - Trade Detail View
struct TradeDetailView: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Trade header with large symbol
                    VStack(spacing: 16) {
                        Circle()
                            .fill(trade.tradeType.color.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(trade.ticker)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(trade.tradeType.color)
                            )
                        
                        VStack(spacing: 8) {
                            Text(trade.ticker)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(trade.tradeType.displayName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Trade details in cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        detailCard(title: "Quantity", value: "\(trade.quantity) shares")
                        detailCard(title: "Entry Price", value: trade.entryPrice.asCurrency)
                        detailCard(title: "Current Value", value: trade.currentValue.asCurrency)
                        detailCard(title: "Unrealized P&L", value: trade.unrealizedPL.asCurrencyWithSign)
                    }
                    
                    if let notes = trade.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(notes)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.gray)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.05))
                                )
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(24)
            }
            .navigationTitle("Trade Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                }
            }
        }
    }
    
    private func detailCard(title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 4)
        )
    }
}

#Preview {
    PortfolioView()
        .environmentObject(FirebaseAuthService.shared)
        .environmentObject(PortfolioViewModel())
}
