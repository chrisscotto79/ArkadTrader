// File: Core/Portfolio/Views/PortfolioView.swift
// Fixed Portfolio View - uses simple components, no missing dependencies
// Removed duplicate TradeFilter enum - uses the one from TradingEnums.swift

import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    
    @State private var showAddTrade = false
    @State private var showTradeDetail = false
    @State private var selectedTrade: Trade?
    @State private var selectedFilter: TradeFilter = .all
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Portfolio Summary Header
                portfolioSummarySection
                
                // Search and Filter Section
                searchAndFilterSection
                
                // Trades List
                tradesListSection
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddTrade = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }
            }
            .refreshable {
                portfolioViewModel.loadPortfolioData()
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
        }
    }
    
    // MARK: - Portfolio Summary Section
    private var portfolioSummarySection: some View {
        VStack(spacing: 16) {
            // Main Portfolio Value
            VStack(spacing: 8) {
                Text("Portfolio Value")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(portfolioViewModel.portfolio?.totalValue.asCurrency ?? "$0.00")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 20) {
                    VStack {
                        Text(portfolioViewModel.portfolio?.totalProfitLoss.asCurrencyWithSign ?? "$0.00")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(profitLossColor)
                        Text("Total P&L")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text("\(String(format: "%.1f", portfolioViewModel.portfolio?.winRate ?? 0))%")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Text("Win Rate")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Simple Stats Cards (no external dependencies)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    simpleStatCard(
                        title: "Open Positions",
                        value: "\(portfolioViewModel.portfolio?.openPositions ?? 0)",
                        icon: "clock.fill",
                        color: .blue
                    )
                    
                    simpleStatCard(
                        title: "Total Trades",
                        value: "\(portfolioViewModel.portfolio?.totalTrades ?? 0)",
                        icon: "chart.bar.fill",
                        color: .purple
                    )
                    
                    simpleStatCard(
                        title: "Today's P&L",
                        value: portfolioViewModel.portfolio?.dayProfitLoss.asCurrencyWithSign ?? "$0.00",
                        icon: "calendar",
                        color: dayPLColor
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color.gray.opacity(0.05))
    }
    
    // MARK: - Simple Stat Card (inline component)
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
        }
        .padding()
        .frame(width: 120, height: 80)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
    }
    
    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
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
            .cornerRadius(10)
            
            // Filter Picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(TradeFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(.horizontal)
    }
    
    // MARK: - Trades List Section
    private var tradesListSection: some View {
        Group {
            if filteredTrades.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTrades, id: \.id) { trade in
                            TradeCard(trade: trade) {
                                selectedTrade = trade
                                showTradeDetail = true
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Trades Yet" : "No Matching Trades")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
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
                        Image(systemName: "plus.circle")
                        Text("Add Your First Trade")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(25)
                }
            }
        }
        .padding(.top, 60)
    }
    
    // MARK: - Computed Properties
    private var filteredTrades: [Trade] {
        var trades = portfolioViewModel.trades
        
        // Apply search filter
        if !searchText.isEmpty {
            trades = trades.filter { trade in
                trade.ticker.localizedCaseInsensitiveContains(searchText) ||
                (trade.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
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
}

// MARK: - Trade Card
struct TradeCard: View {
    let trade: Trade
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Status Indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                // Trade Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trade.ticker)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(trade.tradeType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        
                        if trade.isOpen {
                            Text("OPEN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
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
                
                // P&L Info
                VStack(alignment: .trailing, spacing: 4) {
                    if trade.isOpen {
                        Text(trade.currentValue.asCurrency)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("Current Value")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text(trade.profitLoss.asCurrencyWithSign)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                        
                        Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.1f", trade.profitLossPercentage))%")
                            .font(.caption)
                            .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Trade Detail Sheet
struct TradeDetailSheet: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showEditTrade = false
    @State private var showCloseTrade = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Trade Header
                    tradeHeaderSection
                    
                    // Trade Details
                    tradeDetailsSection
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Trade Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Trade") { showEditTrade = true }
                        if trade.isOpen {
                            Button("Close Position") { showCloseTrade = true }
                        }
                        Divider()
                        Button("Delete Trade", role: .destructive) { showDeleteAlert = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditTrade) {
            EditTradeSheet(trade: trade)
                .environmentObject(portfolioViewModel)
        }
        .sheet(isPresented: $showCloseTrade) {
            CloseTradeSheet(trade: trade)
                .environmentObject(portfolioViewModel)
        }
        .alert("Delete Trade", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteTrade() }
            }
        } message: {
            Text("Are you sure you want to delete this trade? This action cannot be undone.")
        }
    }
    
    private var tradeHeaderSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(trade.ticker)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                if trade.isOpen {
                    Text("OPEN")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
            
            if !trade.isOpen {
                VStack(spacing: 8) {
                    Text(trade.profitLoss.asCurrencyWithSign)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                    
                    Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.2f", trade.profitLossPercentage))%")
                        .font(.title2)
                        .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                }
            }
        }
    }
    
    private var tradeDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trade Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                DetailRow(label: "Type", value: trade.tradeType.displayName)
                DetailRow(label: "Quantity", value: "\(trade.quantity) shares")
                DetailRow(label: "Entry Price", value: trade.entryPrice.asCurrency)
                DetailRow(label: "Entry Date", value: formatDate(trade.entryDate))
                
                if let exitPrice = trade.exitPrice {
                    DetailRow(label: "Exit Price", value: exitPrice.asCurrency)
                }
                
                if let exitDate = trade.exitDate {
                    DetailRow(label: "Exit Date", value: formatDate(exitDate))
                }
                
                if let strategy = trade.strategy, !strategy.isEmpty {
                    DetailRow(label: "Strategy", value: strategy)
                }
                
                if let notes = trade.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.gray)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if trade.isOpen {
                Button(action: { showCloseTrade = true }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Close Position")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: { showEditTrade = true }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Button(action: { showDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func deleteTrade() async {
        print("Would delete trade: \(trade.ticker)")
        dismiss()
    }
}

struct DetailRow: View {
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
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PortfolioView()
        .environmentObject(FirebaseAuthService.shared)
}
