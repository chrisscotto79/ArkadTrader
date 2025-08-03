// File: Core/Portfolio/Views/PortfolioView.swift
// Clean Modern Portfolio Interface with Integrated Profile Image Support

import SwiftUI

struct PortfolioView: View {
    // MARK: - Environment Objects
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    
    // MARK: - State Variables
    @State private var showAddTrade = false
    @State private var showTradeActions = false
    @State private var selectedTrade: Trade?
    @State private var animateContent = false
    @State private var selectedTimeframe: TimeFrame = .monthly
    @State private var showProfileSettings = false
    
    // Interactive chart state
    @State private var selectedDataPoint: (index: Int, value: Double)?
    @State private var showingChartValue = false
    
    // MARK: - Main Body
    var body: some View {
        ZStack {
            // Modern background gradient
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) {
                    // Header Section with Profile Image
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    
                    // Portfolio Value Card
                    portfolioValueCard
                        .padding(.horizontal, 20)
                    
                    // Performance Chart Card
                    performanceChartCard
                        .padding(.horizontal, 20)
                    
                    // Quick Stats Grid
                    quickStatsGrid
                        .padding(.horizontal, 20)
                    
                    // Recent Activity Section
                    recentActivitySection
                        .padding(.horizontal, 20)
                    
                    // Bottom padding for floating button
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 100)
                }
                .padding(.bottom, 20)
            }
            .refreshable {
                portfolioViewModel.refreshPortfolio()
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
        .sheet(isPresented: $showProfileSettings) {
            ProfileView()
                .environmentObject(authService)
        }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1)) {
                animateContent = true
            }
        }
    }
}

// MARK: - Header Section
extension PortfolioView {
    private var headerSection: some View {
        HStack(alignment: .top) {
            // Greeting and user name
            VStack(alignment: .leading, spacing: 8) {
                Text(greetingText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6).delay(0.1), value: animateContent)
                
                Text(firstName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .opacity(animateContent ? 1 : 0)
                    .scaleEffect(animateContent ? 1 : 0.9)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateContent)
            }
            
            Spacer()
            
            // Profile Image Button - USING EXACT PROFILE IMAGE PATTERN
            profileImageButton
        }
    }
    
    private var profileImageButton: some View {
        Button(action: { showProfileSettings = true }) {
            Group {
                // EXACT SAME PATTERN AS YOUR ORIGINAL CODE
                if let imageUrl = authService.currentUser?.profileImageUrl,
                   !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.arkadGold.opacity(0.2), Color.arkadGold.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .arkadGold))
                                    .scaleEffect(0.8)
                            )
                    }
                } else {
                    // Fallback to initials circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.arkadGold.opacity(0.2), Color.arkadGold.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(userInitials)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.arkadGold)
                        )
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.arkadGold.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(animateContent ? 1 : 0.8)
        .opacity(animateContent ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)
    }
}

// MARK: - Portfolio Value Card
extension PortfolioView {
    private var portfolioValueCard: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top) {
                // Main portfolio info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Portfolio Value")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Text(portfolioValue.asCurrency)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .opacity(animateContent ? 1 : 0)
                            .scaleEffect(animateContent ? 1 : 0.8)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4), value: animateContent)
                        
                        if totalProfitLoss != 0 {
                            performanceIndicator
                        }
                    }
                    
                    profitLossDisplay
                }
                
                Spacer()
                
                // Account adjustment button
                accountAdjustmentButton
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
                .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
        )
        .opacity(animateContent ? 1 : 0)
        .scaleEffect(animateContent ? 1 : 0.95)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: animateContent)
    }
    
    private var performanceIndicator: some View {
        VStack(spacing: 2) {
            Image(systemName: totalProfitLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(totalProfitLoss >= 0 ? .green : .red)
            
            Text(String(format: "%.1f%%", abs(returnPercentage)))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(totalProfitLoss >= 0 ? .green : .red)
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.6), value: animateContent)
    }
    
    private var profitLossDisplay: some View {
        HStack(spacing: 8) {
            Text(totalProfitLoss.asCurrencyWithSign)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(totalProfitLoss >= 0 ? .green : .red)
            
            Text("today")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.5), value: animateContent)
    }
    
    private var accountAdjustmentButton: some View {
        Button(action: {
            portfolioViewModel.showDepositWithdrawSheet = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 18, weight: .medium))
                
                Text("Adjust")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.arkadGold)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.arkadGold.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(animateContent ? 1 : 0.85)
        .opacity(animateContent ? 1 : 0)
        .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.7), value: animateContent)
    }
}

// MARK: - Performance Chart Card
extension PortfolioView {
    private var performanceChartCard: some View {
        VStack(spacing: 24) {
            // Chart header
            HStack {
                Text("Performance")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                timeframeSelector
            }
            
            // Chart area
            chartArea
                .frame(height: 200)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
                .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
        )
        .opacity(animateContent ? 1 : 0)
        .scaleEffect(animateContent ? 1 : 0.95)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: animateContent)
    }
    
    private var timeframeSelector: some View {
        HStack(spacing: 0) {
            ForEach([TimeFrame.weekly, TimeFrame.monthly, TimeFrame.allTime], id: \.self) { timeframe in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimeframe = timeframe
                    }
                }) {
                    Text(timeframe.shortName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .secondary)
                        .frame(minWidth: 40)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTimeframe == timeframe ? Color.arkadGold : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    private var chartArea: some View {
        GeometryReader { geometry in
            let data = generateChartData()
            
            if data.count < 2 {
                emptyChartView
            } else {
                interactiveChart(data: data, geometry: geometry)
            }
        }
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("Not enough data")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Add some trades to see your performance")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func interactiveChart(data: [Double], geometry: GeometryProxy) -> some View {
        let chartWidth = geometry.size.width - 20
        let chartHeight = geometry.size.height - 40
        
        let maxValue = data.max() ?? 0
        let minValue = data.min() ?? 0
        let range = maxValue - minValue
        let adjustedRange = range < 1 ? 100.0 : range
        let adjustedMin = range < 1 ? minValue - 50.0 : minValue
        let adjustedMax = range < 1 ? maxValue + 50.0 : maxValue
        let finalRange = adjustedMax - adjustedMin
        
        return ZStack {
            // Chart background grid
            chartBackground(width: chartWidth, height: chartHeight)
            
            // Chart content
            chartContent(
                data: data,
                width: chartWidth,
                height: chartHeight,
                adjustedMin: adjustedMin,
                finalRange: finalRange
            )
            
            // Interactive layer
            chartInteractiveLayer(
                data: data,
                width: chartWidth,
                height: chartHeight,
                adjustedMin: adjustedMin,
                finalRange: finalRange
            )
        }
        .frame(width: chartWidth, height: chartHeight)
        .offset(x: 10, y: 10)
    }
}

// MARK: - Chart Components
extension PortfolioView {
    private func chartBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Vertical grid lines
            Path { path in
                for i in 1..<5 {
                    let x = width * CGFloat(i) / 5
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
            }
            .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
            
            // Horizontal grid lines
            Path { path in
                for i in 1..<4 {
                    let y = height * CGFloat(i) / 4
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.secondary.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
        }
    }
    
    private func chartContent(data: [Double], width: CGFloat, height: CGFloat, adjustedMin: Double, finalRange: Double) -> some View {
        let points = createChartPoints(data: data, width: width, height: height, adjustedMin: adjustedMin, finalRange: finalRange)
        
        return ZStack {
            // Area fill
            Path { path in
                path.move(to: CGPoint(x: 0, y: height))
                
                for (index, point) in points.enumerated() {
                    if index == 0 {
                        path.addLine(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        (totalProfitLoss >= 0 ? Color.green : Color.red).opacity(0.3),
                        (totalProfitLoss >= 0 ? Color.green : Color.red).opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Line
            Path { path in
                for (index, point) in points.enumerated() {
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(
                totalProfitLoss >= 0 ? Color.green : Color.red,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
        }
    }
    
    private func chartInteractiveLayer(data: [Double], width: CGFloat, height: CGFloat, adjustedMin: Double, finalRange: Double) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = value.location.x
                            if x >= 0 && x <= width {
                                let progress = x / width
                                let index = Int(progress * Double(data.count - 1))
                                let clampedIndex = max(0, min(index, data.count - 1))
                                
                                selectedDataPoint = (index: clampedIndex, value: data[clampedIndex])
                                showingChartValue = true
                            }
                        }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showingChartValue = false
                                    selectedDataPoint = nil
                                }
                            }
                        }
                )
            
            // Interactive elements
            if let selectedPoint = selectedDataPoint, showingChartValue {
                let points = createChartPoints(data: data, width: width, height: height, adjustedMin: adjustedMin, finalRange: finalRange)
                let point = points[selectedPoint.index]
                
                // Vertical line
                Path { path in
                    path.move(to: CGPoint(x: point.x, y: 0))
                    path.addLine(to: CGPoint(x: point.x, y: height))
                }
                .stroke(Color.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [3, 6]))
                
                // Touch point
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .fill(totalProfitLoss >= 0 ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                    )
                    .position(point)
                
                // Value popup
                Text(selectedPoint.value.asCurrency)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(totalProfitLoss >= 0 ? Color.green : Color.red)
                            .shadow(radius: 4)
                    )
                    .position(x: point.x, y: max(30, point.y - 30))
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Quick Stats Grid
extension PortfolioView {
    private var quickStatsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            StatCard(
                icon: "target",
                title: "Win Rate",
                value: String(format: "%.0f%%", winRate),
                color: winRate >= 50 ? .green : .orange,
                delay: 0.6
            )
            
            StatCard(
                icon: "chart.bar.fill",
                title: "Total Trades",
                value: "\(allTrades.count)",
                color: .blue,
                delay: 0.7
            )
            
            StatCard(
                icon: "clock.fill",
                title: "Open Positions",
                value: "\(openPositions.count)",
                color: .purple,
                delay: 0.8
            )
            
            StatCard(
                icon: "trophy.fill",
                title: "Best Trade",
                value: bestTradeValue,
                color: .yellow,
                delay: 0.9
            )
        }
    }
}

// MARK: - Recent Activity Section
extension PortfolioView {
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to full trades list
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.arkadGold)
            }
            
            // Content
            if recentTrades.isEmpty {
                emptyActivityView
            } else {
                tradesListView
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
                .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
        )
        .opacity(animateContent ? 1 : 0)
        .scaleEffect(animateContent ? 1 : 0.95)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.7), value: animateContent)
    }
    
    private var emptyActivityView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 50, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No trades yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Start your trading journey by adding your first trade")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var tradesListView: some View {
        VStack(spacing: 0) {
            ForEach(Array(recentTrades.prefix(4).enumerated()), id: \.element.id) { index, trade in
                RecentTradeRow(trade: trade, isLast: index == min(3, recentTrades.count - 1))
                    .onTapGesture {
                        selectedTrade = trade
                        showTradeActions = true
                    }
            }
        }
    }
}

// MARK: - Floating Action Button
extension PortfolioView {
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: { showAddTrade = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                        
                        Text("Add Trade")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(30)
                    .shadow(color: Color.arkadGold.opacity(0.4), radius: 20, x: 0, y: 10)
                    .shadow(color: Color.arkadGold.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .scaleEffect(animateContent ? 1 : 0.8)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.1), value: animateContent)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Supporting Components
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let delay: Double
    
    @State private var animateCard = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                .shadow(color: .black.opacity(0.02), radius: 1, x: 0, y: 1)
        )
        .scaleEffect(animateCard ? 1 : 0.9)
        .opacity(animateCard ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animateCard)
        .onAppear {
            animateCard = true
        }
    }
}

struct RecentTradeRow: View {
    let trade: Trade
    let isLast: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                }
                
                // Trade info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(trade.ticker)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(trade.isOpen ? "Open" : "Closed")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(statusColor))
                    }
                    
                    Text(timeAgoText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Trade value
                VStack(alignment: .trailing, spacing: 6) {
                    if trade.isOpen {
                        Text(trade.currentValue.asCurrency)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                    } else {
                        Text(trade.profitLoss.asCurrencyWithSign)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                    }
                    
                    Text("\(trade.quantity) shares")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 16)
            
            if !isLast {
                Divider().opacity(0.5)
            }
        }
    }
    
    private var statusColor: Color {
        if trade.isOpen {
            return .blue
        } else {
            return trade.profitLoss >= 0 ? .green : .red
        }
    }
    
    private var timeAgoText: String {
        let date = trade.exitDate ?? trade.entryDate
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

// MARK: - Helper Functions
extension PortfolioView {
    private func generateChartData() -> [Double] {
        let performanceData = portfolioViewModel.getPerformanceForTimeframe(selectedTimeframe)
        
        if !performanceData.isEmpty {
            return performanceData.map { $0.portfolioValue }
        }
        
        if !portfolioViewModel.trades.isEmpty {
            return generateFallbackChartData()
        }
        
        let currentValue = portfolioValue
        return [currentValue, currentValue, currentValue]
    }
    
    private func generateFallbackChartData() -> [Double] {
        let startingCapital = portfolioViewModel.getUserStartingCapital() ?? 1000.0
        let currentValue = portfolioValue
        let dataPoints = 15
        
        var chartData: [Double] = []
        let increment = (currentValue - startingCapital) / Double(dataPoints - 1)
        
        for i in 0..<dataPoints {
            let value = startingCapital + (Double(i) * increment)
            chartData.append(value)
        }
        
        return chartData
    }
    
    private func createChartPoints(data: [Double], width: CGFloat, height: CGFloat, adjustedMin: Double, finalRange: Double) -> [CGPoint] {
        return data.enumerated().map { index, value in
            let x = width * CGFloat(index) / CGFloat(data.count - 1)
            let normalizedValue = (value - adjustedMin) / finalRange
            let y = height - (height * CGFloat(normalizedValue))
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Computed Properties
extension PortfolioView {
    private var portfolioValue: Double {
        portfolioViewModel.portfolio?.totalValue ?? 0.0
    }
    
    private var totalProfitLoss: Double {
        portfolioViewModel.portfolio?.totalProfitLoss ?? 0.0
    }
    
    private var returnPercentage: Double {
        let totalInvested = allTrades.reduce(0) { $0 + ($1.entryPrice * Double($1.quantity)) }
        guard totalInvested > 0 else { return 0.0 }
        return (totalProfitLoss / totalInvested) * 100
    }
    
    private var winRate: Double {
        portfolioViewModel.portfolio?.winRate ?? 0.0
    }
    
    private var openPositions: [Trade] {
        portfolioViewModel.trades.filter { $0.isOpen }
    }
    
    private var allTrades: [Trade] {
        portfolioViewModel.trades
    }
    
    private var recentTrades: [Trade] {
        portfolioViewModel.trades.sorted { $0.entryDate > $1.entryDate }
    }
    
    private var bestTradeValue: String {
        let bestTrade = portfolioViewModel.trades.filter { !$0.isOpen }.max { $0.profitLoss < $1.profitLoss }
        return bestTrade?.profitLoss.asCurrency ?? "$0"
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
    
    private var firstName: String {
        authService.currentUser?.fullName.components(separatedBy: " ").first ?? "Trader"
    }
    
    // EXACT SAME PATTERN AS ORIGINAL
    private var userInitials: String {
        let name = authService.currentUser?.fullName ?? "User"
        let components = name.components(separatedBy: " ")
        let firstInitial = String(components.first?.first ?? Character("U"))
        let lastInitial = components.count > 1 ? String(components.last?.first ?? Character("")) : ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
}

// MARK: - TimeFrame Extension
extension TimeFrame {
    var shortName: String {
        switch self {
        case .daily: return "1D"
        case .weekly: return "1W"
        case .monthly: return "1M"
        case .allTime: return "All"
        }
    }
}

// MARK: - Preview
#Preview {
    PortfolioView()
        .environmentObject(FirebaseAuthService.shared)
}
