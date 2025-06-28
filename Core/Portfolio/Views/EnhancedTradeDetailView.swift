// File: Core/Portfolio/Views/EnhancedTradeDetailView.swift
// Comprehensive Trade Details and Management Interface

import SwiftUI

struct EnhancedTradeDetailView: View {
    let trade: Trade
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showEditTrade = false
    @State private var showCloseTrade = false
    @State private var showDeleteAlert = false
    @State private var showShareTrade = false
    @State private var showAddNote = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Trade Header
                    TradeHeaderSection(trade: trade)
                    
                    // Performance Metrics
                    if !trade.isOpen {
                        PerformanceMetricsSection(trade: trade)
                    }
                    
                    // Trade Details
                    TradeDetailsSection(trade: trade)
                    
                    // Trade Timeline
                    TradeTimelineSection(trade: trade)
                    
                    // Notes Section
                    TradeNotesSection(trade: trade, showAddNote: $showAddNote)
                    
                    // Action Buttons
                    TradeActionButtons(
                        trade: trade,
                        showEditTrade: $showEditTrade,
                        showCloseTrade: $showCloseTrade,
                        showDeleteAlert: $showDeleteAlert,
                        showShareTrade: $showShareTrade
                    )
                }
                .padding()
            }
            .navigationTitle("Trade Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showEditTrade = true }) {
                            Label("Edit Trade", systemImage: "pencil")
                        }
                        
                        Button(action: { showShareTrade = true }) {
                            Label("Share Trade", systemImage: "square.and.arrow.up")
                        }
                        
                        if trade.isOpen {
                            Button(action: { showCloseTrade = true }) {
                                Label("Close Position", systemImage: "xmark.circle")
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { showDeleteAlert = true }) {
                            Label("Delete Trade", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.arkadGold)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditTrade) {
            EditTradeView(trade: trade)
                .environmentObject(portfolioViewModel)
        }
        .sheet(isPresented: $showCloseTrade) {
            CloseTradeView(trade: trade)
                .environmentObject(portfolioViewModel)
        }
        .sheet(isPresented: $showShareTrade) {
            ShareTradeView(trade: trade)
        }
        .sheet(isPresented: $showAddNote) {
            AddTradeNoteView(trade: trade)
                .environmentObject(portfolioViewModel)
        }
        .alert("Delete Trade", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // For now, just simulate delete since deleteTrade method doesn't exist yet
                print("Would delete trade: \(trade.ticker)")
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this trade? This action cannot be undone.")
        }
    }
}

// MARK: - Trade Header Section
struct TradeHeaderSection: View {
    let trade: Trade
    
    var body: some View {
        VStack(spacing: 16) {
            // Ticker and Status
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(trade.ticker)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        StatusBadge(isOpen: trade.isOpen, profitLoss: trade.profitLoss)
                    }
                    
                    Text(trade.tradeType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Trade Icon/Symbol
                Image(systemName: trade.isOpen ? "clock.fill" : "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(trade.isOpen ? .arkadGold : (trade.profitLoss >= 0 ? .marketGreen : .marketRed))
            }
            
            // P&L Display (for closed trades)
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
    }
}

// MARK: - Performance Metrics Section
struct PerformanceMetricsSection: View {
    let trade: Trade
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    title: "Return",
                    value: "\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.2f", trade.profitLossPercentage))%",
                    color: trade.profitLoss >= 0 ? .marketGreen : .marketRed
                )
                
                MetricCard(
                    title: "Profit/Loss",
                    value: trade.profitLoss >= 0 ? "+$\(String(format: "%.2f", trade.profitLoss))" : "-$\(String(format: "%.2f", abs(trade.profitLoss)))",
                    color: trade.profitLoss >= 0 ? .marketGreen : .marketRed
                )
                
                MetricCard(
                    title: "Duration",
                    value: tradeDuration,
                    color: .arkadGold
                )
                
                MetricCard(
                    title: "Total Value",
                    value: "$\(String(format: "%.2f", trade.currentValue))",
                    color: .arkadGold
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var tradeDuration: String {
        let endDate = trade.exitDate ?? Date()
        let days = Calendar.current.dateComponents([.day], from: trade.entryDate, to: endDate).day ?? 0
        return "\(days) days"
    }
}

// MARK: - Trade Details Section
struct TradeDetailsSection: View {
    let trade: Trade
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trade Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                DetailRow(label: "Quantity", value: "\(trade.quantity) shares")
                DetailRow(label: "Entry Price", value: "$\(String(format: "%.2f", trade.entryPrice))")
                DetailRow(label: "Entry Date", value: formatDate(trade.entryDate))
                
                if let exitPrice = trade.exitPrice {
                    DetailRow(label: "Exit Price", value: "$\(String(format: "%.2f", exitPrice))")
                }
                
                if let exitDate = trade.exitDate {
                    DetailRow(label: "Exit Date", value: formatDate(exitDate))
                }
                
                if let strategy = trade.strategy {
                    DetailRow(label: "Strategy", value: strategy)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Trade Timeline Section
struct TradeTimelineSection: View {
    let trade: Trade
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                TimelineEvent(
                    title: "Trade Opened",
                    subtitle: "Entry at $\(String(format: "%.2f", trade.entryPrice))",
                    date: trade.entryDate,
                    isCompleted: true,
                    color: .arkadGold
                )
                
                if let exitDate = trade.exitDate, let exitPrice = trade.exitPrice {
                    TimelineEvent(
                        title: "Trade Closed",
                        subtitle: "Exit at $\(String(format: "%.2f", exitPrice))",
                        date: exitDate,
                        isCompleted: true,
                        color: trade.profitLoss >= 0 ? .marketGreen : .marketRed
                    )
                } else {
                    TimelineEvent(
                        title: "Trade Active",
                        subtitle: "Currently open position",
                        date: Date(),
                        isCompleted: false,
                        color: .arkadGold
                    )
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Trade Notes Section
struct TradeNotesSection: View {
    let trade: Trade
    @Binding var showAddNote: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Notes")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showAddNote = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.arkadGold)
                }
            }
            
            if let notes = trade.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Text("No notes added yet")
                    .font(.body)
                    .foregroundColor(.gray)
                    .italic()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Trade Action Buttons
struct TradeActionButtons: View {
    let trade: Trade
    @Binding var showEditTrade: Bool
    @Binding var showCloseTrade: Bool
    @Binding var showDeleteAlert: Bool
    @Binding var showShareTrade: Bool
    
    var body: some View {
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
                    .background(Color.arkadGold)
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
                    .foregroundColor(.arkadGold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Button(action: { showShareTrade = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadGold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct StatusBadge: View {
    let isOpen: Bool
    let profitLoss: Double
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.1))
            .cornerRadius(6)
    }
    
    private var statusText: String {
        if isOpen {
            return "OPEN"
        } else {
            return profitLoss >= 0 ? "PROFIT" : "LOSS"
        }
    }
    
    private var statusColor: Color {
        if isOpen {
            return .arkadGold
        } else {
            return profitLoss >= 0 ? .marketGreen : .marketRed
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
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

struct TimelineEvent: View {
    let title: String
    let subtitle: String
    let date: Date
    let isCompleted: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Timeline indicator
            ZStack {
                Circle()
                    .fill(color.opacity(isCompleted ? 1.0 : 0.3))
                    .frame(width: 12, height: 12)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(formatEventDate(date))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
    
    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    EnhancedTradeDetailView(trade: Trade(ticker: "AAPL", tradeType: .stock, entryPrice: 150.00, quantity: 10, userId: UUID()))
        .environmentObject(PortfolioViewModel())
}
