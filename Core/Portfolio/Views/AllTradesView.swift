// Core/Portfolio/Views/AllTradesView.swift
// Fixed All Trades View - removed duplicate TradeFilter enum
// Uses TradeFilter from TradingEnums.swift

import SwiftUI

struct AllTradesView: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @State private var selectedFilter: TradeFilter = .all
    @State private var searchText = ""
    
    var filteredTrades: [Trade] {
        var trades = portfolioViewModel.trades
        
        // Apply search filter
        if !searchText.isEmpty {
            trades = trades.filter { trade in
                trade.ticker.localizedCaseInsensitiveContains(searchText)
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search trades...", text: $searchText)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Filter Picker
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(TradeFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding()
                
                // Trades List
                if filteredTrades.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(searchText.isEmpty ? "No trades found" : "No trades match your search")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTrades, id: \.id) { trade in
                                SimpleTradeCardView(trade: trade)
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("All Trades")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Simple Trade Card
struct SimpleTradeCardView: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.ticker)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if trade.isOpen {
                        Text("OPEN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text("\(trade.quantity) shares @ $\(String(format: "%.2f", trade.entryPrice))")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(formatDate(trade.entryDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if trade.isOpen {
                    Text("$\(String(format: "%.0f", trade.currentValue))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                } else {
                    Text(trade.profitLoss >= 0 ? "+$\(String(format: "%.0f", trade.profitLoss))" : "-$\(String(format: "%.0f", abs(trade.profitLoss)))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                    
                    Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.1f", trade.profitLossPercentage))%")
                        .font(.caption)
                        .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                }
            }
        }
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

#Preview {
    AllTradesView()
        .environmentObject(PortfolioViewModel())
}
