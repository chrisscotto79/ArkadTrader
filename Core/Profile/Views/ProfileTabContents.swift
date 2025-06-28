// File: Core/Profile/Views/ProfileTabContents.swift
// Enhanced Trades Tab with Interactive Features

import SwiftUI

struct ProfileTradesTab: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @State private var selectedFilter: ProfileTradeFilter = .all
    @State private var selectedSort: ProfileTradeSort = .newest
    @State private var showFilterSheet = false
    @State private var selectedTrade: Trade?
    @State private var showTradeDetail = false
    
    var filteredTrades: [Trade] {
        var trades = portfolioViewModel.trades
        
        // Apply filter
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
        
        // Apply sort
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
        }
        
        return trades
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !portfolioViewModel.trades.isEmpty {
                // Enhanced Trading Stats Summary
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Trading Summary")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: { showFilterSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                Text("Filter")
                            }
                            .font(.caption)
                            .foregroundColor(.arkadGold)
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            TradingStatCard(
                                title: "Total Trades",
                                value: "\(portfolioViewModel.trades.count)",
                                color: .arkadGold,
                                subtitle: "All time"
                            )
                            TradingStatCard(
                                title: "Open Positions",
                                value: "\(portfolioViewModel.trades.filter { $0.isOpen }.count)",
                                color: .marketGreen,
                                subtitle: "Active"
                            )
                            TradingStatCard(
                                title: "Closed Trades",
                                value: "\(portfolioViewModel.trades.filter { !$0.isOpen }.count)",
                                color: .arkadGold,
                                subtitle: "Completed"
                            )
                            TradingStatCard(
                                title: "Win Rate",
                                value: "\(String(format: "%.0f", calculateWinRate()))%",
                                color: .marketGreen,
                                subtitle: "Success"
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
                
                // Filter & Sort Bar
                HStack {
                    Text("\(filteredTrades.count) trades")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Menu {
                        Picker("Sort by", selection: $selectedSort) {
                            ForEach(ProfileTradeSort.allCases, id: \.self) { sort in
                                Text(sort.displayName).tag(sort)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Sort")
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .font(.caption)
                        .foregroundColor(.arkadGold)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
                
                // Enhanced Trades List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTrades, id: \.id) { trade in
                            EnhancedTradeRow(trade: trade) {
                                selectedTrade = trade
                                showTradeDetail = true
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .refreshable {
                    portfolioViewModel.loadPortfolioData()
                }
            } else {
                // Enhanced Empty State
                VStack(spacing: 20) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 64))
                        .foregroundColor(.arkadGold.opacity(0.3))
                    
                    VStack(spacing: 8) {
                        Text("No Trades Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                        
                        Text("Start your trading journey by adding your first trade")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    NavigationLink(destination: PortfolioView()) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Your First Trade")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadBlack)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(25)
                    }
                }
                .padding(.vertical, 60)
            }
        }
        .padding(.top, 20)
        .sheet(isPresented: $showFilterSheet) {
            ProfileTradeFilterSheet(selectedFilter: $selectedFilter)
        }
        .sheet(isPresented: $showTradeDetail) {
            if let trade = selectedTrade {
                TradeDetailView(trade: trade)
                    .environmentObject(portfolioViewModel)
            }
        }
    }
    
    private func calculateWinRate() -> Double {
        let closedTrades = portfolioViewModel.trades.filter { !$0.isOpen }
        guard !closedTrades.isEmpty else { return 0 }
        let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
        return Double(winningTrades) / Double(closedTrades.count) * 100
    }
}

// MARK: - Enhanced Trading Stat Card
struct TradingStatCard: View {
    let title: String
    let value: String
    let color: Color
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding()
        .frame(width: 120, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Enhanced Trade Row
struct EnhancedTradeRow: View {
    let trade: Trade
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Trade Status Icon
                Circle()
                    .fill(trade.isOpen ? Color.arkadGold.opacity(0.2) : (trade.profitLoss >= 0 ? Color.marketGreen.opacity(0.2) : Color.marketRed.opacity(0.2)))
                    .frame(width: 50, height: 50)
                    .overlay(
                        VStack(spacing: 2) {
                            Text(trade.ticker)
                                .font(.caption)
                                .fontWeight(.bold)
                            Text(trade.isOpen ? "OPEN" : (trade.profitLoss >= 0 ? "WIN" : "LOSS"))
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(trade.isOpen ? .arkadGold : (trade.profitLoss >= 0 ? .marketGreen : .marketRed))
                    )
                
                // Trade Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trade.ticker)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if trade.isOpen {
                            Text("OPEN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.arkadGold.opacity(0.2))
                                .foregroundColor(.arkadGold)
                                .cornerRadius(4)
                        } else {
                            Text(trade.profitLoss >= 0 ? "+$\(String(format: "%.0f", trade.profitLoss))" : "-$\(String(format: "%.0f", abs(trade.profitLoss)))")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                        }
                    }
                    
                    HStack {
                        Text("\(trade.quantity) shares @ $\(trade.entryPrice, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        if !trade.isOpen {
                            Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.1f", trade.profitLossPercentage))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                        }
                    }
                    
                    Text(formatDate(trade.entryDate))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Filter Sheet
struct ProfileTradeFilterSheet: View {
    @Binding var selectedFilter: ProfileTradeFilter
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(ProfileTradeFilter.allCases, id: \.self) { filter in
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
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Trade Detail View
struct TradeDetailView: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showCloseTradeSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Trade Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(trade.ticker)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            if trade.isOpen {
                                Text("OPEN POSITION")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.arkadGold.opacity(0.2))
                                    .foregroundColor(.arkadGold)
                                    .cornerRadius(8)
                            }
                        }
                        
                        if !trade.isOpen {
                            HStack {
                                Text(trade.profitLoss >= 0 ? "+$\(String(format: "%.2f", trade.profitLoss))" : "-$\(String(format: "%.2f", abs(trade.profitLoss)))")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                                
                                Text("(\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.2f", trade.profitLossPercentage))%)")
                                    .font(.title3)
                                    .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                            }
                        }
                    }
                    
                    // Trade Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trade Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TradeDetailRow(title: "Type", value: trade.tradeType.displayName)
                        TradeDetailRow(title: "Quantity", value: "\(trade.quantity) shares")
                        TradeDetailRow(title: "Entry Price", value: "$\(String(format: "%.2f", trade.entryPrice))")
                        TradeDetailRow(title: "Entry Date", value: formatDate(trade.entryDate))
                        
                        if let exitPrice = trade.exitPrice {
                            TradeDetailRow(title: "Exit Price", value: "$\(String(format: "%.2f", exitPrice))")
                        }
                        
                        if let exitDate = trade.exitDate {
                            TradeDetailRow(title: "Exit Date", value: formatDate(exitDate))
                        }
                        
                        if let notes = trade.notes, !notes.isEmpty {
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
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    
                    // Actions
                    if trade.isOpen {
                        Button(action: {
                            showCloseTradeSheet = true
                        }) {
                            Text("Close Position")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.arkadGold)
                                .cornerRadius(12)
                        }
                    }
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
        .sheet(isPresented: $showCloseTradeSheet) {
            CloseTradeSheet(trade: trade)
                .environmentObject(portfolioViewModel)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views
struct TradeDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct CloseTradeSheet: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    @State private var exitPrice = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Close Position") {
                    TextField("Exit Price", text: $exitPrice)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Close \(trade.ticker)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        closeTrade()
                    }
                    .disabled(exitPrice.isEmpty)
                }
            }
        }
        .alert("Success", isPresented: $showAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func closeTrade() {
        guard let price = Double(exitPrice) else { return }
        
        portfolioViewModel.closeTrade(trade, exitPrice: price)
        
        let profit = (price - trade.entryPrice) * Double(trade.quantity)
        alertMessage = profit >= 0 ? "Position closed with a profit of $\(String(format: "%.2f", profit))" : "Position closed with a loss of $\(String(format: "%.2f", abs(profit)))"
        showAlert = true
    }
}

// MARK: - Enums
enum ProfileTradeFilter: CaseIterable {
    case all, open, closed, profitable, losses
    
    var displayName: String {
        switch self {
        case .all: return "All Trades"
        case .open: return "Open Positions"
        case .closed: return "Closed Trades"
        case .profitable: return "Profitable Trades"
        case .losses: return "Loss Trades"
        }
    }
}

enum ProfileTradeSort: CaseIterable {
    case newest, oldest, highestGain, highestLoss, ticker
    
    var displayName: String {
        switch self {
        case .newest: return "Newest First"
        case .oldest: return "Oldest First"
        case .highestGain: return "Highest Gain"
        case .highestLoss: return "Highest Loss"
        case .ticker: return "Ticker (A-Z)"
        }
    }
}
