// File: Core/Portfolio/Views/PortfolioView.swift
// Enhanced Performance Dashboard with Improved UI and Easy Actions

import SwiftUI

struct PortfolioView: View {
    @State private var showAddTrade = false
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTimeframe: PerformanceTimeframe = .week
    @State private var showTradeDetail = false
    @State private var selectedTrade: Trade?
    @State private var showQuickActions = false
    
    var body: some View {
        ZStack {
            // Main Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Enhanced Portfolio Summary
                    EnhancedPortfolioHeader()
                        .environmentObject(portfolioViewModel)
                    
                    // Improved Performance Chart
                    ImprovedPerformanceChart(selectedTimeframe: $selectedTimeframe)
                        .environmentObject(portfolioViewModel)
                    
                    // Quick Stats Cards
                    QuickStatsSection()
                        .environmentObject(portfolioViewModel)
                    
                    // Enhanced Recent Trades
                    EasyTradesSection(
                        showTradeDetail: $showTradeDetail,
                        selectedTrade: $selectedTrade
                    )
                    .environmentObject(portfolioViewModel)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            
            // Floating Action Buttons
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionMenu(
                        showAddTrade: $showAddTrade,
                        showQuickActions: $showQuickActions
                    )
                    .environmentObject(portfolioViewModel)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddTrade) {
            QuickAddTradeView()
                .environmentObject(portfolioViewModel)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showTradeDetail) {
            if let trade = selectedTrade {
                QuickTradeDetailView(trade: trade)
                    .environmentObject(portfolioViewModel)
            }
        }
        .refreshable {
            portfolioViewModel.loadPortfolioData()
        }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
        }
    }
}


// MARK: - Enhanced Portfolio Header
struct EnhancedPortfolioHeader: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Welcome & Time
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good \(timeOfDay)")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    Text("Your Portfolio")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Quick Stats Badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Today")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(portfolioViewModel.portfolio?.dayProfitLoss.asCurrencyWithSign ?? "$0.00")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(dayChangeColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(dayChangeColor.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Main Portfolio Value Card
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(portfolioViewModel.portfolio?.totalValue.asCurrency ?? "$0.00")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: dayChangeIcon)
                                .font(.caption)
                            Text(portfolioViewModel.portfolio?.dayProfitLoss.asCurrencyWithSign ?? "$0.00")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(dayChangeColor)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text("\(String(format: "%.1f", portfolioViewModel.portfolio?.dayProfitLossPercentage ?? 0))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(dayChangeColor)
                    }
                }
                
                // Total Return
                HStack {
                    Text("Total Return")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(portfolioViewModel.portfolio?.totalProfitLoss.asCurrencyWithSign ?? "$0.00")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(totalReturnColor)
                        
                        Text("\(String(format: "%.2f", portfolioViewModel.portfolio?.totalProfitLossPercentage ?? 0))%")
                            .font(.caption)
                            .foregroundColor(totalReturnColor)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(color: .gray.opacity(0.1), radius: 10, x: 0, y: 5)
            )
        }
    }
    
    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        default: return "Evening"
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
    
    private var totalReturnColor: Color {
        let total = portfolioViewModel.portfolio?.totalProfitLoss ?? 0
        return total >= 0 ? .marketGreen : .marketRed
    }
}

// MARK: - Improved Performance Chart
struct ImprovedPerformanceChart: View {
    @Binding var selectedTimeframe: PerformanceTimeframe
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Chart Header
            HStack {
                Text("Performance")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Compact Timeframe Picker
                HStack(spacing: 0) {
                    ForEach(PerformanceTimeframe.allCases, id: \.self) { timeframe in
                        Button(action: { selectedTimeframe = timeframe }) {
                            Text(timeframe.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(selectedTimeframe == timeframe ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedTimeframe == timeframe ? Color.arkadGold : Color.clear)
                                )
                        }
                    }
                }
                .padding(4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Enhanced Chart
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(timeframeReturn)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(chartColor)
                        
                        Text(timeframePercentage)
                            .font(.subheadline)
                            .foregroundColor(chartColor)
                    }
                    
                    Spacer()
                    
                    // Chart Legend
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(chartColor)
                                .frame(width: 8, height: 8)
                            Text("Portfolio")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                            Text("Benchmark")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // Improved Chart Visual
                GeometryReader { geometry in
                    ZStack {
                        // Background Grid
                        Path { path in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            
                            // Horizontal grid lines
                            for i in 0...4 {
                                let y = CGFloat(i) * height / 4
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: width, y: y))
                            }
                        }
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        
                        // Chart Line
                        Path { path in
                            let points = generateChartPoints()
                            let width = geometry.size.width
                            let height = geometry.size.height
                            
                            guard !points.isEmpty else { return }
                            
                            let maxValue = points.max() ?? 1
                            let minValue = points.min() ?? 0
                            let range = maxValue - minValue
                            
                            path.move(to: CGPoint(x: 0, y: height - CGFloat((points[0] - minValue) / range) * height))
                            
                            for (index, point) in points.enumerated() {
                                let x = CGFloat(index) / CGFloat(points.count - 1) * width
                                let y = height - CGFloat((point - minValue) / range) * height
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(chartColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        
                        // Gradient Fill
                        Path { path in
                            let points = generateChartPoints()
                            let width = geometry.size.width
                            let height = geometry.size.height
                            
                            guard !points.isEmpty else { return }
                            
                            let maxValue = points.max() ?? 1
                            let minValue = points.min() ?? 0
                            let range = maxValue - minValue
                            
                            path.move(to: CGPoint(x: 0, y: height - CGFloat((points[0] - minValue) / range) * height))
                            
                            for (index, point) in points.enumerated() {
                                let x = CGFloat(index) / CGFloat(points.count - 1) * width
                                let y = height - CGFloat((point - minValue) / range) * height
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            
                            path.addLine(to: CGPoint(x: width, y: height))
                            path.addLine(to: CGPoint(x: 0, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: chartColor.opacity(0.3), location: 0),
                                    .init(color: chartColor.opacity(0.1), location: 0.5),
                                    .init(color: chartColor.opacity(0.05), location: 1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .frame(height: 140)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .gray.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var timeframeReturn: String {
        let value = 1847.50 // Mock data
        return value >= 0 ? "+$\(String(format: "%.0f", value))" : "-$\(String(format: "%.0f", abs(value)))"
    }
    
    private var timeframePercentage: String {
        let percentage = 12.34 // Mock data
        return percentage >= 0 ? "+\(String(format: "%.2f", percentage))%" : "\(String(format: "%.2f", percentage))%"
    }
    
    private var chartColor: Color {
        return .marketGreen // Mock positive performance
    }
    
    private func generateChartPoints() -> [Double] {
        // Enhanced mock data with more realistic fluctuations
        switch selectedTimeframe {
        case .day:
            return [100, 102, 98, 105, 103, 107, 109, 106, 108, 112]
        case .week:
            return [100, 105, 102, 110, 108, 115, 112, 118, 120, 125]
        case .month:
            return [100, 108, 112, 106, 115, 120, 118, 125, 130, 128, 135]
        case .year:
            return [100, 120, 115, 140, 135, 160, 155, 175, 180, 185, 190]
        case .all:
            return [100, 130, 125, 150, 145, 170, 165, 185, 190, 195, 200]
        }
    }
}

// MARK: - Quick Stats Section
struct QuickStatsSection: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Stats")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ModernStatCard(
                    title: "Win Rate",
                    value: "\(String(format: "%.0f", portfolioViewModel.portfolio?.winRate ?? 0))%",
                    subtitle: "Success",
                    icon: "target",
                    color: .arkadGold,
                    trend: .stable
                )
                
                ModernStatCard(
                    title: "Active",
                    value: "\(portfolioViewModel.trades.filter { $0.isOpen }.count)",
                    subtitle: "Positions",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .marketGreen,
                    trend: .up
                )
                
                ModernStatCard(
                    title: "Best Trade",
                    value: bestTradeValue,
                    subtitle: bestTradeTicker,
                    icon: "crown.fill",
                    color: .arkadGold,
                    trend: .up
                )
                
                ModernStatCard(
                    title: "Total Trades",
                    value: "\(portfolioViewModel.trades.count)",
                    subtitle: "All time",
                    icon: "chart.bar.fill",
                    color: .gray,
                    trend: .stable
                )
            }
        }
    }
    
    private var bestTradeValue: String {
        let bestTrade = portfolioViewModel.trades
            .filter { !$0.isOpen }
            .max(by: { $0.profitLoss < $1.profitLoss })
        
        guard let trade = bestTrade else { return "$0" }
        return "+$\(String(format: "%.0f", trade.profitLoss))"
    }
    
    private var bestTradeTicker: String {
        let bestTrade = portfolioViewModel.trades
            .filter { !$0.isOpen }
            .max(by: { $0.profitLoss < $1.profitLoss })
        return bestTrade?.ticker ?? "None"
    }
}

// MARK: - Modern Stat Card
struct ModernStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .foregroundColor(trend.color)
                    .font(.caption)
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
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .gray.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    enum TrendDirection {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .marketGreen
            case .down: return .marketRed
            case .stable: return .gray
            }
        }
    }
}

// MARK: - Easy Trades Section
struct EasyTradesSection: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Binding var showTradeDetail: Bool
    @Binding var selectedTrade: Trade?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Trades")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !portfolioViewModel.trades.isEmpty {
                    NavigationLink("View All") {
                        AllTradesView()
                            .environmentObject(portfolioViewModel)
                    }
                    .font(.subheadline)
                    .foregroundColor(.arkadGold)
                }
            }
            .padding(.horizontal, 4)
            
            if portfolioViewModel.trades.isEmpty {
                EmptyTradesCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(portfolioViewModel.trades.prefix(4), id: \.id) { trade in
                        SwipeableTradeRow(trade: trade) {
                            selectedTrade = trade
                            showTradeDetail = true
                        }
                        .environmentObject(portfolioViewModel)
                    }
                }
            }
        }
    }
}

// MARK: - Swipeable Trade Row
struct SwipeableTradeRow: View {
    let trade: Trade
    let onTap: () -> Void
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @State private var offset: CGFloat = 0
    @State private var showCloseAlert = false
    
    var body: some View {
        ZStack {
            // Background Actions
            HStack {
                if trade.isOpen {
                    // Close Action
                    Button(action: { showCloseAlert = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                            Text("Close")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70)
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                    }
                }
                
                Spacer()
                
                // Edit Action
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                        Text("Edit")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70)
                    .frame(maxHeight: .infinity)
                    .background(Color.arkadGold)
                }
            }
            
            // Main Trade Content
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Status Indicator
                    VStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        
                        Text(trade.ticker)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .frame(width: 50)
                    
                    // Trade Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(trade.ticker)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if trade.isOpen {
                                Text("OPEN")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.arkadGold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.arkadGold.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                        }
                        
                        Text("\(trade.quantity) shares @ $\(String(format: "%.2f", trade.entryPrice))")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatDate(trade.entryDate))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Performance
                    VStack(alignment: .trailing, spacing: 4) {
                        if trade.isOpen {
                            Text("$\(String(format: "%.0f", trade.currentValue))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.arkadGold)
                            
                            Text("Current")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        } else {
                            Text(trade.profitLoss >= 0 ? "+$\(String(format: "%.0f", trade.profitLoss))" : "-$\(String(format: "%.0f", abs(trade.profitLoss)))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                            
                            Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.1f", trade.profitLossPercentage))%")
                                .font(.caption)
                                .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                        }
                    }
                }
                .padding(16)
                .background(.white)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if abs(offset) > 50 {
                                offset = offset > 0 ? 0 : -140
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .clipped()
        .alert("Close Position", isPresented: $showCloseAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Close") {
                portfolioViewModel.closeTrade(trade, exitPrice: trade.entryPrice * 1.1) // Mock exit price
            }
        } message: {
            Text("Are you sure you want to close this position?")
        }
    }
    
    private var statusColor: Color {
        if trade.isOpen {
            return .arkadGold
        } else {
            return trade.profitLoss >= 0 ? .marketGreen : .marketRed
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Empty Trades Card
struct EmptyTradesCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 40))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No trades yet")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                Text("Tap the + button to add your first trade")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .gray.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Floating Action Menu
struct FloatingActionMenu: View {
    @Binding var showAddTrade: Bool
    @Binding var showQuickActions: Bool
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if showQuickActions {
                // Quick Actions
                VStack(spacing: 12) {
                    QuickActionButton(
                        icon: "chart.bar.fill",
                        label: "Analytics",
                        color: .blue
                    ) {
                        // TODO: Show analytics
                    }
                    
                    QuickActionButton(
                        icon: "square.and.arrow.up",
                        label: "Export",
                        color: .green
                    ) {
                        // TODO: Export data
                    }
                    
                    QuickActionButton(
                        icon: "xmark.circle.fill",
                        label: "Close All",
                        color: .red
                    ) {
                        // TODO: Close all positions
                    }
                }
            }
            
            // Main Add Button
            Button(action: { showAddTrade = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if !showQuickActions {
                        Text("Add Trade")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, showQuickActions ? 16 : 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: showQuickActions ? 50 : 25)
                        .fill(Color.arkadGold)
                        .shadow(color: .arkadGold.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .onLongPressGesture {
                withAnimation(.spring()) {
                    showQuickActions.toggle()
                }
            }
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(color)
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
    }
}

// MARK: - Quick Add Trade View
struct QuickAddTradeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
    @State private var ticker = ""
    @State private var tradeType: TradeType = .stock
    @State private var entryPrice = ""
    @State private var quantity = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Add New Trade")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Quickly add a trade to your portfolio")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top)
                
                // Form
                VStack(spacing: 20) {
                    // Ticker Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ticker Symbol")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("AAPL", text: $ticker)
                            .textCase(.uppercase)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Trade Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trade Type")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Trade Type", selection: $tradeType) {
                            ForEach(TradeType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Entry Price & Quantity
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Entry Price")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("$0.00", text: $entryPrice)
                                .keyboardType(.decimalPad)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quantity")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("0", text: $quantity)
                                .keyboardType(.numberPad)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    // Trade Value Preview
                    if let price = Double(entryPrice), let qty = Int(quantity), price > 0, qty > 0 {
                        VStack(spacing: 8) {
                            Text("Total Value")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("$\(String(format: "%.2f", price * Double(qty)))")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadGold)
                        }
                        .padding()
                        .background(Color.arkadGold.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: addTrade) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Trade")
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.arkadGold)
                        .cornerRadius(16)
                    }
                    .disabled(!isFormValid)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
        .alert("Trade Added!", isPresented: $showSuccess) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("\(ticker.uppercased()) has been added to your portfolio")
        }
    }
    
    private var isFormValid: Bool {
        !ticker.isEmpty &&
        !entryPrice.isEmpty &&
        !quantity.isEmpty &&
        Double(entryPrice) != nil &&
        Int(quantity) != nil
    }
    
    private func addTrade() {
        guard let price = Double(entryPrice),
              let qty = Int(quantity),
              let userId = authViewModel.currentUser?.id else {
            return
        }
        
        let newTrade = Trade(
            ticker: ticker.uppercased(),
            tradeType: tradeType,
            entryPrice: price,
            quantity: qty,
            userId: userId
        )
        
        portfolioViewModel.addTrade(newTrade)
        showSuccess = true
    }
}

// MARK: - Quick Trade Detail View
struct QuickTradeDetailView: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showCloseAlert = false
    @State private var exitPrice = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Trade Header
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(trade.ticker)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                HStack {
                                    Text(trade.tradeType.displayName)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    if trade.isOpen {
                                        Text("• OPEN")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.arkadGold)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: trade.isOpen ? "clock.fill" : "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(trade.isOpen ? .arkadGold : (trade.profitLoss >= 0 ? .marketGreen : .marketRed))
                        }
                        
                        // P&L Display
                        if !trade.isOpen {
                            VStack(spacing: 8) {
                                Text(trade.profitLoss >= 0 ? "+$\(String(format: "%.2f", trade.profitLoss))" : "-$\(String(format: "%.2f", abs(trade.profitLoss)))")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                                
                                Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.2f", trade.profitLossPercentage))%")
                                    .font(.title2)
                                    .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                            }
                        } else {
                            VStack(spacing: 8) {
                                Text("Current Value")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text("$\(String(format: "%.2f", trade.currentValue))")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.arkadGold)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .gray.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // Trade Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            QuickDetailRow(label: "Quantity", value: "\(trade.quantity) shares")
                            QuickDetailRow(label: "Entry Price", value: "$\(String(format: "%.2f", trade.entryPrice))")
                            QuickDetailRow(label: "Entry Date", value: formatDate(trade.entryDate))
                            
                            if let exitPrice = trade.exitPrice {
                                QuickDetailRow(label: "Exit Price", value: "$\(String(format: "%.2f", exitPrice))")
                            }
                            
                            if let exitDate = trade.exitDate {
                                QuickDetailRow(label: "Exit Date", value: formatDate(exitDate))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .gray.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // Actions
                    if trade.isOpen {
                        VStack(spacing: 16) {
                            Text("Close Position")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            TextField("Exit Price", text: $exitPrice)
                                .keyboardType(.decimalPad)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            
                            Button(action: { showCloseAlert = true }) {
                                Text("Close Position")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.arkadGold)
                                    .cornerRadius(16)
                            }
                            .disabled(exitPrice.isEmpty || Double(exitPrice) == nil)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .gray.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Close Position", isPresented: $showCloseAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Close") {
                if let price = Double(exitPrice) {
                    portfolioViewModel.closeTrade(trade, exitPrice: price)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to close this position at $\(exitPrice)?")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Quick Detail Row
struct QuickDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Performance Timeframe
enum PerformanceTimeframe: CaseIterable {
    case day, week, month, year, all
    
    var displayName: String {
        switch self {
        case .day: return "1D"
        case .week: return "1W"
        case .month: return "1M"
        case .year: return "1Y"
        case .all: return "ALL"
        }
    }
}

#Preview {
    PortfolioView()
        .environmentObject(AuthViewModel())
}

// MARK: - PortfolioViewModel Extension (Temporary)
extension PortfolioViewModel {
    func updateTrade(_ trade: Trade) async throws {
        // Temporary implementation - update trade in the trades array
        if let index = trades.firstIndex(where: { $0.id == trade.id }) {
            trades[index] = trade
            // Here you would normally save to backend/storage
        }
    }
    
    func deleteTrade(_ trade: Trade) {
        // Temporary implementation - remove trade from array
        trades.removeAll { $0.id == trade.id }
        // Here you would normally delete from backend/storage
        calculatePortfolioMetrics()
    }
    
    private func calculatePortfolioMetrics() {
        // Simple portfolio calculation
        guard let userId = UUID(uuidString: "mock-user-id") else { return }
        
        let totalValue = trades.reduce(0) { $0 + $1.currentValue }
        let totalPL = trades.filter { !$0.isOpen }.reduce(0) { $0 + $1.profitLoss }
        let openPositions = trades.filter { $0.isOpen }.count
        let totalTrades = trades.count
        let winningTrades = trades.filter { !$0.isOpen && $0.profitLoss > 0 }.count
        let winRate = totalTrades > 0 ? Double(winningTrades) / Double(totalTrades) * 100 : 0
        
        var newPortfolio = Portfolio(userId: userId)
        newPortfolio.totalValue = totalValue
        newPortfolio.totalProfitLoss = totalPL
        newPortfolio.openPositions = openPositions
        newPortfolio.totalTrades = totalTrades
        newPortfolio.winRate = winRate
        newPortfolio.dayProfitLoss = 245.0 // Mock data
        
        self.portfolio = newPortfolio
    }
}
