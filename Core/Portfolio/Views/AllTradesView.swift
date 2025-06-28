// File: Core/Portfolio/Views/AllTradesView.swift
// Conflict-free version with unique view names

import SwiftUI

struct AllTradesView: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @State private var searchText = ""
    @State private var selectedFilter: TradeFilterType = .all
    @State private var selectedSort: TradeSortType = .newest
    @State private var showFilterSheet = false
    @State private var showSortSheet = false
    @State private var selectedTrade: Trade?
    @State private var showTradeDetail = false
    @Environment(\.dismiss) var dismiss
    
    var filteredAndSortedTrades: [Trade] {
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
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            trades = trades.filter { $0.entryDate >= weekAgo }
        case .thisMonth:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            trades = trades.filter { $0.entryDate >= monthAgo }
        }
        
        // Apply sorting
        switch selectedSort {
        case .newest:
            trades.sort { $0.entryDate > $1.entryDate }
        case .oldest:
            trades.sort { $0.entryDate < $1.entryDate }
        case .highestGain:
            trades.sort { $0.profitLoss > $1.profitLoss }
        case .highestLoss:
            trades.sort { $0.profitLoss < $1.profitLoss }
        case .ticker:
            trades.sort { $0.ticker < $1.ticker }
        case .largestPosition:
            trades.sort { $0.currentValue > $1.currentValue }
        }
        
        return trades
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("\(filteredAndSortedTrades.count) of \(portfolioViewModel.trades.count) trades")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .padding()
                
                // Search and Filter Bar
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search trades, tickers, notes...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Filter and Sort Buttons
                    HStack(spacing: 12) {
                        Button(action: { showFilterSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                Text(selectedFilter.shortName)
                            }
                            .font(.caption)
                            .foregroundColor(.arkadGold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.arkadGold.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        Button(action: { showSortSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                Text(selectedSort.shortName)
                            }
                            .font(.caption)
                            .foregroundColor(.arkadGold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.arkadGold.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Trades List
                if filteredAndSortedTrades.isEmpty {
                    EmptyAllTradesView(hasAnyTrades: !portfolioViewModel.trades.isEmpty)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredAndSortedTrades, id: \.id) { trade in
                                Button(action: {
                                    selectedTrade = trade
                                    showTradeDetail = true
                                }) {
                                    TradeListItemView(trade: trade)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("All Trades")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        portfolioViewModel.loadPortfolioData()
                    }
                    .foregroundColor(.arkadGold)
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            TradeFilterSheet(selectedFilter: $selectedFilter)
        }
        .sheet(isPresented: $showSortSheet) {
            TradeSortSheet(selectedSort: $selectedSort)
        }
        .sheet(isPresented: $showTradeDetail) {
            if let trade = selectedTrade {
                TradeDetailPopup(trade: trade)
            }
        }
    }
}

// MARK: - Trade List Item View (completely unique name)
struct TradeListItemView: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // Trade Information
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
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.arkadGold.opacity(0.2))
                            .cornerRadius(3)
                    }
                    
                    Spacer()
                }
                
                Text("\(trade.quantity) @ $\(String(format: "%.2f", trade.entryPrice))")
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
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
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

// MARK: - Trade Detail Popup (completely unique name)
struct TradeDetailPopup: View {
    let trade: Trade
    @Environment(\.dismiss) var dismiss
    
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
                                
                                Text(trade.tradeType.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: trade.isOpen ? "clock.fill" : "checkmark.circle.fill")
                                .font(.system(size: 30))
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
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Trade Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trade Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Quantity")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(trade.quantity) shares")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Entry Price")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("$\(String(format: "%.2f", trade.entryPrice))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Entry Date")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(formatDate(trade.entryDate))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            if let exitPrice = trade.exitPrice {
                                HStack {
                                    Text("Exit Price")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("$\(String(format: "%.2f", exitPrice))")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            if let exitDate = trade.exitDate {
                                HStack {
                                    Text("Exit Date")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(formatDate(exitDate))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            if let strategy = trade.strategy {
                                HStack {
                                    Text("Strategy")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(strategy)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            if let notes = trade.notes {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Notes")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(notes)
                                        .font(.body)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .padding()
            }
            .navigationTitle("Trade Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
}

// MARK: - Empty View (completely unique name)
struct EmptyAllTradesView: View {
    let hasAnyTrades: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasAnyTrades ? "magnifyingglass" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(hasAnyTrades ? "No trades match your filters" : "No trades yet")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(hasAnyTrades ? "Try adjusting your search or filter criteria" : "Add your first trade to get started")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Filter and Sort Sheets (completely unique names)
struct TradeFilterSheet: View {
    @Binding var selectedFilter: TradeFilterType
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(TradeFilterType.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        dismiss()
                    }) {
                        HStack {
                            Text(filter.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedFilter == filter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.arkadGold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Trades")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct TradeSortSheet: View {
    @Binding var selectedSort: TradeSortType
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(TradeSortType.allCases, id: \.self) { sort in
                    Button(action: {
                        selectedSort = sort
                        dismiss()
                    }) {
                        HStack {
                            Text(sort.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedSort == sort {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.arkadGold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sort Trades")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Enums (completely unique names)
enum TradeFilterType: CaseIterable {
    case all, open, closed, profitable, losses, thisWeek, thisMonth
    
    var displayName: String {
        switch self {
        case .all: return "All Trades"
        case .open: return "Open Positions"
        case .closed: return "Closed Trades"
        case .profitable: return "Profitable Trades"
        case .losses: return "Loss Trades"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        }
    }
    
    var shortName: String {
        switch self {
        case .all: return "All"
        case .open: return "Open"
        case .closed: return "Closed"
        case .profitable: return "Wins"
        case .losses: return "Losses"
        case .thisWeek: return "Week"
        case .thisMonth: return "Month"
        }
    }
}

enum TradeSortType: CaseIterable {
    case newest, oldest, highestGain, highestLoss, ticker, largestPosition
    
    var displayName: String {
        switch self {
        case .newest: return "Newest First"
        case .oldest: return "Oldest First"
        case .highestGain: return "Highest Gain"
        case .highestLoss: return "Highest Loss"
        case .ticker: return "Ticker (A-Z)"
        case .largestPosition: return "Largest Position"
        }
    }
    
    var shortName: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .highestGain: return "Best"
        case .highestLoss: return "Worst"
        case .ticker: return "A-Z"
        case .largestPosition: return "Size"
        }
    }
}

#Preview {
    AllTradesView()
        .environmentObject(PortfolioViewModel())
}
