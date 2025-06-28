// File: Core/Portfolio/Views/AllTradesView.swift
// Comprehensive Trades List with Filtering, Sorting, and Management

import SwiftUI

struct AllTradesView: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @State private var searchText = ""
    @State private var selectedFilter: AllTradesFilter = .all
    @State private var selectedSort: AllTradesSort = .newest
    @State private var showFilterSheet = false
    @State private var showSortSheet = false
    @State private var selectedTrade: Trade?
    @State private var showTradeDetail = false
    @State private var showBulkActions = false
    @State private var selectedTrades: Set<UUID> = []
    
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
        VStack(spacing: 0) {
            // Header with Stats
            TradesHeaderView(
                totalTrades: portfolioViewModel.trades.count,
                filteredCount: filteredAndSortedTrades.count,
                selectedCount: selectedTrades.count,
                showBulkActions: $showBulkActions
            )
            
            // Search and Filter Bar
            SearchAndFilterBar(
                searchText: $searchText,
                selectedFilter: selectedFilter,
                selectedSort: selectedSort,
                showFilterSheet: $showFilterSheet,
                showSortSheet: $showSortSheet
            )
            
            // Trades List
            if filteredAndSortedTrades.isEmpty {
                EmptyTradesListView(hasAnyTrades: !portfolioViewModel.trades.isEmpty)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredAndSortedTrades, id: \.id) { trade in
                            AdvancedTradeRow(
                                trade: trade,
                                isSelected: selectedTrades.contains(trade.id),
                                showSelection: showBulkActions
                            ) {
                                if showBulkActions {
                                    toggleTradeSelection(trade.id)
                                } else {
                                    selectedTrade = trade
                                    showTradeDetail = true
                                }
                            }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showBulkActions.toggle() }) {
                        Label(showBulkActions ? "Cancel Selection" : "Select Trades", systemImage: "checkmark.circle")
                    }
                    
                    Button(action: exportTrades) {
                        Label("Export Trades", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: refreshTrades) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.arkadGold)
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheet(selectedFilter: $selectedFilter)
        }
        .sheet(isPresented: $showSortSheet) {
            SortSheet(selectedSort: $selectedSort)
        }
        .sheet(isPresented: $showTradeDetail) {
            if let trade = selectedTrade {
                EnhancedTradeDetailView(trade: trade)
                    .environmentObject(portfolioViewModel)
            }
        }
        .overlay(
            // Bulk Actions Bar
            Group {
                if showBulkActions && !selectedTrades.isEmpty {
                    BulkActionsBar(
                        selectedCount: selectedTrades.count,
                        onDelete: deleteBulkTrades,
                        onExport: exportSelectedTrades
                    )
                }
            }
        )
    }
    
    private func toggleTradeSelection(_ tradeId: UUID) {
        if selectedTrades.contains(tradeId) {
            selectedTrades.remove(tradeId)
        } else {
            selectedTrades.insert(tradeId)
        }
    }
    
    private func deleteBulkTrades() {
        // Delete selected trades
        let tradesToDelete = portfolioViewModel.trades.filter { selectedTrades.contains($0.id) }
        for trade in tradesToDelete {
            portfolioViewModel.deleteTrade(trade)
        }
        selectedTrades.removeAll()
        showBulkActions = false
    }
    
    private func exportSelectedTrades() {
        // Implementation for exporting selected trades
        let tradesToExport = portfolioViewModel.trades.filter { selectedTrades.contains($0.id) }
        // Generate CSV or report
    }
    
    private func exportTrades() {
        // Implementation for exporting all trades
    }
    
    private func refreshTrades() {
        portfolioViewModel.loadPortfolioData()
    }
}

// MARK: - Trades Header View
struct TradesHeaderView: View {
    let totalTrades: Int
    let filteredCount: Int
    let selectedCount: Int
    @Binding var showBulkActions: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(filteredCount) of \(totalTrades) trades")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if showBulkActions {
                        Text("\(selectedCount) selected")
                            .font(.caption)
                            .foregroundColor(.arkadGold)
                    }
                }
                
                Spacer()
                
                if showBulkActions {
                    Button("Cancel") {
                        showBulkActions = false
                    }
                    .font(.subheadline)
                    .foregroundColor(.arkadGold)
                }
            }
            
            // Quick Stats
            if !showBulkActions {
                HStack(spacing: 16) {
                    QuickStatPill(title: "Open", value: "\(totalTrades)", color: .arkadGold)
                    QuickStatPill(title: "Closed", value: "\(totalTrades)", color: .gray)
                    QuickStatPill(title: "Winners", value: "\(totalTrades)", color: .marketGreen)
                    QuickStatPill(title: "Losers", value: "\(totalTrades)", color: .marketRed)
                }
            }
        }
        .padding()
        .background(Color.white)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Search and Filter Bar
struct SearchAndFilterBar: View {
    @Binding var searchText: String
    let selectedFilter: AllTradesFilter
    let selectedSort: AllTradesSort
    @Binding var showFilterSheet: Bool
    @Binding var showSortSheet: Bool
    
    var body: some View {
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
        .background(Color.white)
    }
}

// MARK: - Advanced Trade Row
struct AdvancedTradeRow: View {
    let trade: Trade
    let isSelected: Bool
    let showSelection: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                if showSelection {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .arkadGold : .gray)
                }
                
                // Trade Status Indicator
                VStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(trade.ticker)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(width: 40)
                
                // Trade Information
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trade.ticker)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(trade.tradeType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(3)
                        
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
                    
                    HStack {
                        Text("\(trade.quantity) @ $\(String(format: "%.2f", trade.entryPrice))")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if !trade.isOpen, let exitPrice = trade.exitPrice {
                            Text("→ $\(String(format: "%.2f", exitPrice))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
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
                
                if !showSelection {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(isSelected ? Color.arkadGold.opacity(0.1) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.arkadGold : Color.gray.opacity(0.2), lineWidth: 1)
        )
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

// MARK: - Supporting Views
struct QuickStatPill: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct EmptyTradesListView: View {
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

struct BulkActionsBar: View {
    let selectedCount: Int
    let onDelete: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Text("\(selectedCount) selected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: onExport) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.subheadline)
                    .foregroundColor(.arkadGold)
                }
                
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color.white)
            .shadow(color: .gray.opacity(0.3), radius: 8, x: 0, y: -2)
        }
    }
}

// MARK: - Filter and Sort Sheets
struct FilterSheet: View {
    @Binding var selectedFilter: AllTradesFilter
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AllTradesFilter.allCases, id: \.self) { filter in
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

struct SortSheet: View {
    @Binding var selectedSort: AllTradesSort
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AllTradesSort.allCases, id: \.self) { sort in
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

// MARK: - Enhanced Enums
enum AllTradesFilter: CaseIterable {
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

enum AllTradesSort: CaseIterable {
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
    NavigationView {
        AllTradesView()
            .environmentObject(PortfolioViewModel())
    }
}
