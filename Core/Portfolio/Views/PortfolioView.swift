// File: Core/Portfolio/Views/PortfolioView.swift
// Complete Modern Portfolio Interface - Production Ready

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
            // Modern background
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
                    // Header Section
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
        // .sheet(isPresented: $showProfileSettings) {
        //     ProfileSettingsView()
        //         .environmentObject(authService)
        // }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.1)) {
                animateContent = true
            }
        }
    }
}

// MARK: - Header Section
extension PortfolioView {
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(greetingText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6).delay(0.1), value: animateContent)
                
                Text(authService.currentUser?.fullName.components(separatedBy: " ").first ?? "Trader")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .opacity(animateContent ? 1 : 0)
                    .scaleEffect(animateContent ? 1 : 0.9)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateContent)
            }
            
            Spacer()
            
            // Profile Button
            Button(action: {
                showProfileSettings = true
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.arkadGold.opacity(0.2), Color.arkadGold.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Text(userInitials)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.arkadGold)
                }
            }
            .scaleEffect(animateContent ? 1 : 0.8)
            .opacity(animateContent ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)
        }
    }
}

// MARK: - Portfolio Value Card
extension PortfolioView {
    private var portfolioValueCard: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top) {
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
                    }
                    
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
                
                Spacer()
                
                // Deposit/Withdraw Button
                depositWithdrawButtonSimple
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
    
    private var depositWithdrawButton: some View {
        Button(action: {
            portfolioViewModel.showDepositWithdrawSheet = true
        }) {
            Image(systemName: "plus.minus.circle.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.arkadGold)
                .background(
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 32, height: 32)
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
        VStack(spacing: 28) {
            // Chart Header
            HStack {
                Text("Performance")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                timeframeSelector
            }
            
            // Chart Area
            premiumPerformanceChart
                .frame(height: 200)
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
    private var depositWithdrawButtonSimple: some View {
        Button(action: {
            portfolioViewModel.showDepositWithdrawSheet = true
        }) {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.arkadGold)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Premium Performance Chart
extension PortfolioView {
    private var premiumPerformanceChart: some View {
        GeometryReader { geometry in
            let data = generateChartData()
            let performanceData = portfolioViewModel.getPerformanceForTimeframe(selectedTimeframe)
            
            let chartWidth = geometry.size.width - 20
            let chartHeight = geometry.size.height - 40
            let chartOriginX: CGFloat = 10
            let chartOriginY: CGFloat = 10
            
            guard data.count >= 2 else {
                return AnyView(
                    VStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            Text("Not enough data")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("Add some trades to see your performance")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
            }
            
            let maxValue = data.max() ?? 0
            let minValue = data.min() ?? 0
            let range = maxValue - minValue
            let adjustedRange = range < 1 ? 100.0 : range
            let adjustedMin = range < 1 ? minValue - 50.0 : minValue
            let adjustedMax = range < 1 ? maxValue + 50.0 : maxValue
            let finalRange = adjustedMax - adjustedMin
            
            return AnyView(
                ZStack {
                    // Chart Background
                    chartBackground(width: chartWidth, height: chartHeight)
                    
                    // Main Chart Content
                    chartContent(
                        data: data,
                        width: chartWidth,
                        height: chartHeight,
                        adjustedMin: adjustedMin,
                        finalRange: finalRange
                    )
                    
                    // Interactive Layer
                    chartInteractiveLayer(
                        data: data,
                        width: chartWidth,
                        height: chartHeight,
                        adjustedMin: adjustedMin,
                        finalRange: finalRange
                    )
                    
                    // Date Labels
                    chartDateLabels(
                        performanceData: performanceData,
                        width: chartWidth,
                        height: chartHeight
                    )
                }
                .frame(width: chartWidth, height: chartHeight)
                .offset(x: chartOriginX, y: chartOriginY)
            )
        }
    }
    
    private func chartBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Vertical Grid Lines
            Path { path in
                for i in 1..<5 {
                    let x = width * CGFloat(i) / 5
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
            }
            .stroke(
                Color.secondary.opacity(0.15),
                style: StrokeStyle(lineWidth: 1, dash: [4, 8])
            )
            
            // Horizontal Grid Lines
            Path { path in
                for i in 1..<4 {
                    let y = height * CGFloat(i) / 4
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(
                Color.secondary.opacity(0.1),
                style: StrokeStyle(lineWidth: 1, dash: [4, 8])
            )
        }
    }
    
    private func chartContent(data: [Double], width: CGFloat, height: CGFloat, adjustedMin: Double, finalRange: Double) -> some View {
        ZStack {
            // Area Fill
            Path { path in
                let controlPoints = createSmoothPath(
                    data: data,
                    width: width,
                    height: height,
                    adjustedMin: adjustedMin,
                    finalRange: finalRange
                )
                
                path.move(to: CGPoint(x: 0, y: height))
                
                for (index, point) in controlPoints.enumerated() {
                    if index == 0 {
                        path.addLine(to: point)
                    } else {
                        let previousPoint = controlPoints[index - 1]
                        let controlPoint1 = CGPoint(
                            x: previousPoint.x + (point.x - previousPoint.x) / 3,
                            y: previousPoint.y
                        )
                        let controlPoint2 = CGPoint(
                            x: point.x - (point.x - previousPoint.x) / 3,
                            y: point.y
                        )
                        path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                    }
                }
                
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        (totalProfitLoss >= 0 ? Color.green : Color.red).opacity(0.3),
                        (totalProfitLoss >= 0 ? Color.green : Color.red).opacity(0.15),
                        (totalProfitLoss >= 0 ? Color.green : Color.red).opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Smooth Line
            Path { path in
                let controlPoints = createSmoothPath(
                    data: data,
                    width: width,
                    height: height,
                    adjustedMin: adjustedMin,
                    finalRange: finalRange
                )
                
                for (index, point) in controlPoints.enumerated() {
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        let previousPoint = controlPoints[index - 1]
                        let controlPoint1 = CGPoint(
                            x: previousPoint.x + (point.x - previousPoint.x) / 3,
                            y: previousPoint.y
                        )
                        let controlPoint2 = CGPoint(
                            x: point.x - (point.x - previousPoint.x) / 3,
                            y: point.y
                        )
                        path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                    }
                }
            }
            .stroke(
                totalProfitLoss >= 0 ? Color.green : Color.red,
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
            )
        }
    }
    
    private func chartInteractiveLayer(data: [Double], width: CGFloat, height: CGFloat, adjustedMin: Double, finalRange: Double) -> some View {
        ZStack {
            // Touch interaction
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showingChartValue = false
                                    selectedDataPoint = nil
                                }
                            }
                        }
                )
            
            // Interactive elements
            if let selectedPoint = selectedDataPoint, showingChartValue {
                let controlPoints = createSmoothPath(
                    data: data,
                    width: width,
                    height: height,
                    adjustedMin: adjustedMin,
                    finalRange: finalRange
                )
                let point = controlPoints[selectedPoint.index]
                
                // Vertical indicator line
                Path { path in
                    path.move(to: CGPoint(x: point.x, y: 0))
                    path.addLine(to: CGPoint(x: point.x, y: height))
                }
                .stroke(
                    Color.primary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 6])
                )
                
                // Touch point
                ZStack {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.15), radius: 4)
                    
                    Circle()
                        .fill(totalProfitLoss >= 0 ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                }
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
                            .shadow(color: .black.opacity(0.2), radius: 4)
                    )
                    .position(x: point.x, y: max(30, point.y - 30))
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingChartValue)
            }
        }
    }
    
    private func chartDateLabels(performanceData: [DailyPerformance], width: CGFloat, height: CGFloat) -> some View {
        VStack {
            Spacer()
            
            HStack {
                ForEach(0..<5) { i in
                    let dateText = getDateLabelForIndex(i, total: 5, performanceData: performanceData)
                    Text(dateText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if i < 4 { Spacer() }
                }
            }
            .padding(.horizontal, 8)
        }
        .offset(y: 25)
    }
}

// MARK: - Quick Stats Grid
extension PortfolioView {
    private var quickStatsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            StatCard(
                icon: "target",
                title: "Win Rate",
                value: "\(String(format: "%.0f", winRate))%",
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

// MARK: - StatCard Component
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

// MARK: - Recent Activity Section
extension PortfolioView {
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 20) {
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
            
            if recentTrades.isEmpty {
                emptyActivityView
            } else {
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
        .padding(28)
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
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - RecentTradeRow Component
struct RecentTradeRow: View {
    let trade: Trade
    let isLast: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Status Indicator
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                }
                
                // Trade Info
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
                            .background(
                                Capsule()
                                    .fill(statusColor)
                            )
                    }
                    
                    Text(timeAgoText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Trade Value
                VStack(alignment: .trailing, spacing: 6) {
                    if !trade.isOpen {
                        Text(trade.profitLoss.asCurrencyWithSign)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                    } else {
                        Text(trade.currentValue.asCurrency)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Text("\(trade.quantity) shares")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 16)
            
            if !isLast {
                Divider()
                    .opacity(0.5)
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
    
    // ADD this computed property to replace the timeAgo function call:
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

// MARK: - Floating Action Button
extension PortfolioView {
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: {
                    showAddTrade = true
                }) {
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
    
    private func createSmoothPath(data: [Double], width: CGFloat, height: CGFloat, adjustedMin: Double, finalRange: Double) -> [CGPoint] {
        return data.enumerated().map { index, value in
            let x = width * CGFloat(index) / CGFloat(data.count - 1)
            let normalizedValue = (value - adjustedMin) / finalRange
            let y = height - (height * CGFloat(normalizedValue))
            return CGPoint(x: x, y: y)
        }
    }
    
    private func getDateLabelForIndex(_ index: Int, total: Int, performanceData: [DailyPerformance]) -> String {
        let formatter = DateFormatter()
        
        switch selectedTimeframe {
        case .weekly:
            formatter.dateFormat = "EEE"
        case .monthly:
            formatter.dateFormat = "MMM d"
        case .allTime:
            formatter.dateFormat = "MMM"
        default:
            formatter.dateFormat = "MMM d"
        }
        
        if !performanceData.isEmpty && performanceData.count >= total {
            let dataIndex = (performanceData.count - 1) * index / (total - 1)
            let clampedIndex = min(dataIndex, performanceData.count - 1)
            return formatter.string(from: performanceData[clampedIndex].date)
        } else {
            let calendar = Calendar.current
            let now = Date()
            
            let startDate: Date
            switch selectedTimeframe {
            case .weekly:
                startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            case .monthly:
                startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            case .allTime:
                startDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            default:
                startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            }
            
            let timeInterval = now.timeIntervalSince(startDate)
            let dateForIndex = Date(timeInterval: timeInterval * Double(index) / Double(total - 1), since: startDate)
            
            return formatter.string(from: dateForIndex)
        }
    }
}

// MARK: - Computed Properties
extension PortfolioView {
    private var portfolioValue: Double {
        return portfolioViewModel.portfolio?.totalValue ?? 0.0
    }
    
    private var totalProfitLoss: Double {
        return portfolioViewModel.portfolio?.totalProfitLoss ?? 0.0
    }
    
    private var returnPercentage: Double {
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
