// File: Core/Portfolio/Views/PortfolioView.swift
// Enhanced Portfolio View with improved data visualization and better UX

import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    
    @State private var showAddTrade = false
    @State private var showTradeDetail = false
    @State private var selectedTrade: Trade?
    @State private var selectedFilter: TradeFilter = .all
    @State private var searchText = ""
    @State private var showPortfolioStats = true
    @State private var animatePortfolioValues = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.gray.opacity(0.05)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        // Enhanced Portfolio Summary
                        enhancedPortfolioSummary
                        
                        // Quick Actions Section
                        quickActionsSection
                            .padding(.top, 20)
                        
                        // Portfolio Analytics Charts (Placeholder for future)
                        if !filteredTrades.isEmpty {
                            portfolioInsightsSection
                                .padding(.top, 20)
                        }
                        
                        // Search and Filter Section
                        searchAndFilterSection
                            .padding(.top, 20)
                        
                        // Trades Section
                        tradesSection
                            .padding(.top, 16)
                    }
                    .padding(.bottom, 100) // Space for floating button
                }
                .refreshable {
                    portfolioViewModel.loadPortfolioData()
                }
                
                // Enhanced Floating Action Button
                enhancedFloatingActionButton
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showAddTrade = true }) {
                            Label("Add Trade", systemImage: "plus.circle")
                        }
                        
                        Button(action: { togglePortfolioStats() }) {
                            Label(showPortfolioStats ? "Hide Stats" : "Show Stats",
                                  systemImage: showPortfolioStats ? "eye.slash" : "eye")
                        }
                        
                        Button(action: { sharePortfolio() }) {
                            Label("Share Portfolio", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.arkadGold)
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTrade) {
            EnhancedAddTradeView()
                .environmentObject(authService)
                .environmentObject(portfolioViewModel)
        }
        .sheet(isPresented: $showTradeDetail) {
            if let trade = selectedTrade {
                TradeDetailSheet(trade: trade)
                    .environmentObject(portfolioViewModel)
            }
        }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
            withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
                animatePortfolioValues = true
            }
        }
    }
    
    // MARK: - Enhanced Portfolio Summary
    private var enhancedPortfolioSummary: some View {
        VStack(spacing: 20) {
            // Main Portfolio Card
            VStack(spacing: 16) {
                // Portfolio Value with Animation
                VStack(spacing: 8) {
                    Text("Portfolio Value")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        if animatePortfolioValues {
                            AnimatedCounterView(
                                value: portfolioViewModel.portfolio?.totalValue ?? 0,
                                format: .currency
                            )
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        } else {
                            Text("$0.00")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        
                        if let portfolio = portfolioViewModel.portfolio {
                            Image(systemName: portfolio.totalProfitLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundColor(portfolio.totalProfitLoss >= 0 ? .green : .red)
                                .font(.title3)
                        }
                    }
                }
                
                // P&L Summary with Enhanced Design
                HStack(spacing: 32) {
                    portfolioMetric(
                        title: "Total P&L",
                        value: portfolioViewModel.portfolio?.totalProfitLoss.asCurrencyWithSign ?? "$0.00",
                        color: profitLossColor,
                        icon: portfolioViewModel.portfolio?.totalProfitLoss ?? 0 >= 0 ? "plus.circle.fill" : "minus.circle.fill"
                    )
                    
                    portfolioMetric(
                        title: "Win Rate",
                        value: "\(String(format: "%.1f", portfolioViewModel.portfolio?.winRate ?? 0))%",
                        color: winRateColor,
                        icon: "target"
                    )
                    
                    portfolioMetric(
                        title: "Today's P&L",
                        value: portfolioViewModel.portfolio?.dayProfitLoss.asCurrencyWithSign ?? "$0.00",
                        color: dayPLColor,
                        icon: "calendar"
                    )
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.arkadGold.opacity(0.3), Color.arkadGold.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            
            // Enhanced Stats Cards
            if showPortfolioStats {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    enhancedStatCard(
                        title: "Open Positions",
                        value: "\(portfolioViewModel.portfolio?.openPositions ?? 0)",
                        icon: "clock.fill",
                        color: .blue,
                        trend: nil
                    )
                    
                    enhancedStatCard(
                        title: "Total Trades",
                        value: "\(portfolioViewModel.portfolio?.totalTrades ?? 0)",
                        icon: "chart.bar.fill",
                        color: .purple,
                        trend: nil
                    )
                    
                    enhancedStatCard(
                        title: "Best Trade",
                        value: portfolioViewModel.portfolioAnalytics?.bestTrade?.profitLoss.asCurrency ?? "$0",
                        icon: "trophy.fill",
                        color: .yellow,
                        trend: .up
                    )
                    
                    enhancedStatCard(
                        title: "Avg Trade Size",
                        value: (portfolioViewModel.portfolioAnalytics?.averageTradeSize ?? 0).asCurrency,
                        icon: "dollarsign.circle.fill",
                        color: .green,
                        trend: nil
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.6), value: showPortfolioStats)
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    quickActionCard(
                        title: "Add Trade",
                        icon: "plus.circle.fill",
                        color: .arkadGold,
                        action: { showAddTrade = true }
                    )
                    
                    quickActionCard(
                        title: "Analytics",
                        icon: "chart.pie.fill",
                        color: .blue,
                        action: { /* Navigate to analytics */ }
                    )
                    
                    quickActionCard(
                        title: "Export Data",
                        icon: "square.and.arrow.up.fill",
                        color: .green,
                        action: { sharePortfolio() }
                    )
                    
                    quickActionCard(
                        title: "Settings",
                        icon: "gear.circle.fill",
                        color: .gray,
                        action: { /* Navigate to settings */ }
                    )
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Portfolio Insights Section
    private var portfolioInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Portfolio Insights")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to detailed analytics
                }
                .font(.caption)
                .foregroundColor(.arkadGold)
            }
            .padding(.horizontal, 16)
            
            // Insights Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    insightCard(
                        title: "Performance Trend",
                        value: "↗️ Improving",
                        description: "Your win rate has increased by 5% this month",
                        color: .green
                    )
                    
                    insightCard(
                        title: "Risk Level",
                        value: "🟡 Moderate",
                        description: "Your average position size is balanced",
                        color: .orange
                    )
                    
                    insightCard(
                        title: "Next Goal",
                        value: "🎯 $5,000",
                        description: "You're 73% towards your monthly target",
                        color: .blue
                    )
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Enhanced Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.title3)
                
                TextField("Search trades by ticker, notes...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Enhanced Filter Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TradeFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedFilter = filter
                            }
                        }) {
                            HStack(spacing: 6) {
                                if selectedFilter == filter {
                                    Image(systemName: filterIcon(for: filter))
                                        .font(.caption)
                                }
                                
                                Text(filter.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(selectedFilter == filter ? .white : .gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? Color.arkadGold : Color.gray.opacity(0.1))
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Trades Section
    private var tradesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Your Trades")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(filteredTrades.count) trades")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            
            // Trades List or Empty State
            if filteredTrades.isEmpty {
                enhancedEmptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredTrades, id: \.id) { trade in
                        EnhancedTradeCard(trade: trade) {
                            selectedTrade = trade
                            showTradeDetail = true
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: filteredTrades.count)
    }
    
    // MARK: - Enhanced Empty State
    private var enhancedEmptyState: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty ? "chart.line.uptrend.xyaxis" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text(searchText.isEmpty ? "No Trades Yet" : "No Matching Trades")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty ?
                     "Start your trading journey by adding your first trade" :
                     "Try adjusting your search or filter")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            if searchText.isEmpty {
                Button(action: { showAddTrade = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Your First Trade")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadBlack)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.arkadGold)
                    .cornerRadius(25)
                    .shadow(color: .arkadGold.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Enhanced Floating Action Button
    private var enhancedFloatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showAddTrade = true
                    }
                    
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Add Trade")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.arkadBlack)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.arkadGold, Color.arkadGold.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .arkadGold.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100) // Account for tab bar
            }
        }
    }
    
    // MARK: - Helper Views
    private func portfolioMetric(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
    
    private func enhancedStatCard(title: String, value: String, icon: String, color: Color, trend: TrendDirection?) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                if let trend = trend {
                    Image(systemName: trend == .up ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(trend == .up ? .green : .red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func quickActionCard(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(width: 80, height: 80)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
    
    private func insightCard(title: String, value: String, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .frame(width: 180)
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Computed Properties
    private var filteredTrades: [Trade] {
        var trades = portfolioViewModel.trades
        
        // Apply search filter
        if !searchText.isEmpty {
            trades = trades.filter { trade in
                trade.ticker.localizedCaseInsensitiveContains(searchText) ||
                (trade.notes?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (trade.strategy?.localizedCaseInsensitiveContains(searchText) ?? false)
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
    
    private var profitLossColor: Color {
        let pl = portfolioViewModel.portfolio?.totalProfitLoss ?? 0
        return pl >= 0 ? .green : .red
    }
    
    private var dayPLColor: Color {
        let dayPL = portfolioViewModel.portfolio?.dayProfitLoss ?? 0
        return dayPL >= 0 ? .green : .red
    }
    
    private var winRateColor: Color {
        let winRate = portfolioViewModel.portfolio?.winRate ?? 0
        if winRate >= 70 { return .green }
        else if winRate >= 50 { return .orange }
        else { return .red }
    }
    
    // MARK: - Helper Methods
    private func filterIcon(for filter: TradeFilter) -> String {
        switch filter {
        case .all: return "list.bullet"
        case .open: return "clock"
        case .closed: return "checkmark.circle"
        case .profitable: return "arrow.up.circle"
        case .losses: return "arrow.down.circle"
        }
    }
    
    private func togglePortfolioStats() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showPortfolioStats.toggle()
        }
    }
    
    private func sharePortfolio() {
        // Implement portfolio sharing functionality
        let portfolioSummary = """
        📊 My ArkadTrader Portfolio
        
        💰 Total Value: \(portfolioViewModel.portfolio?.totalValue.asCurrency ?? "$0")
        📈 Total P&L: \(portfolioViewModel.portfolio?.totalProfitLoss.asCurrencyWithSign ?? "$0")
        🎯 Win Rate: \(String(format: "%.1f", portfolioViewModel.portfolio?.winRate ?? 0))%
        📋 Total Trades: \(portfolioViewModel.portfolio?.totalTrades ?? 0)
        
        Join me on ArkadTrader!
        """
        
        UIPasteboard.general.string = portfolioSummary
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Supporting Types
enum TrendDirection {
    case up, down
}

// MARK: - Animated Counter View
struct AnimatedCounterView: View {
    let value: Double
    let format: NumberFormat
    
    @State private var animatedValue: Double = 0
    
    enum NumberFormat {
        case currency, percentage, number
    }
    
    var body: some View {
        Text(formattedValue)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5)) {
                    animatedValue = value
                }
            }
    }
    
    private var formattedValue: String {
        switch format {
        case .currency:
            return animatedValue.asCurrency
        case .percentage:
            return "\(String(format: "%.1f", animatedValue))%"
        case .number:
            return String(format: "%.0f", animatedValue)
        }
    }
}

#Preview {
    PortfolioView()
        .environmentObject(FirebaseAuthService.shared)
}
