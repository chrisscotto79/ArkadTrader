// File: Core/Portfolio/Views/TradeRowView.swift

import SwiftUI

struct TradeRowView: View {
    let trade: Trade
    var style: DisplayStyle = .standard
    var onTap: (() -> Void)? = nil
    
    enum DisplayStyle {
        case standard      // Original style
        case compact       // Minimal info
        case detailed      // With dates and more info
        case card          // Card style with shadow
        case withIndicator // With colored status indicator
    }
    
    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: onTap) {
                    rowContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                rowContent
            }
        }
    }
    
    @ViewBuilder
    private var rowContent: some View {
        switch style {
        case .standard:
            standardRow
        case .compact:
            compactRow
        case .detailed:
            detailedRow
        case .card:
            cardRow
        case .withIndicator:
            indicatorRow
        }
    }
    
    // Standard layout (original)
    private var standardRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trade.ticker)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(trade.tradeType.displayName)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("\(trade.quantity) shares")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            tradeValueSection
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.2), radius: 2)
    }
    
    // Compact layout
    private var compactRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(trade.ticker)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(trade.quantity) shares")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            compactValueSection
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // Detailed layout with dates
    private var detailedRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.ticker)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if trade.isOpen {
                        openBadge
                    }
                }
                
                Text("\(trade.quantity) shares @ $\(trade.entryPrice, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(formatDate(trade.entryDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            tradeValueSection
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
    }
    
    // Card style
    private var cardRow: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.ticker)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if trade.isOpen {
                        openBadge
                    }
                    
                    Spacer()
                }
                
                Text("\(trade.quantity) shares @ $\(trade.entryPrice, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(formatDate(trade.entryDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            tradeValueSection
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // With status indicator
    private var indicatorRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(trade.ticker)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if trade.isOpen {
                        openBadge
                    }
                    
                    Spacer()
                }
                
                Text("\(trade.quantity) shares @ $\(trade.entryPrice, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            compactValueSection
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // Shared components
    private var tradeValueSection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if trade.isOpen {
                Text("OPEN")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.arkadGold.opacity(0.2))
                    .foregroundColor(.arkadGold)
                    .cornerRadius(4)
            } else {
                Text(trade.profitLoss >= 0 ? "+$\(trade.profitLoss, specifier: "%.2f")" : "-$\(abs(trade.profitLoss), specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                
                Text("\(trade.profitLossPercentage, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
            }
            
            Text("$\(trade.entryPrice, specifier: "%.2f")")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private var compactValueSection: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if trade.isOpen {
                Text("$\(String(format: "%.0f", trade.currentValue))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadGold)
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
    
    private var openBadge: some View {
        Text("OPEN")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.arkadGold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.arkadGold.opacity(0.2))
            .cornerRadius(4)
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

#Preview {
    let sampleTrade = Trade(ticker: "AAPL", tradeType: .stock, entryPrice: 150.00, quantity: 10, userId: UUID())
    
    VStack(spacing: 20) {
        TradeRowView(trade: sampleTrade, style: .standard)
        TradeRowView(trade: sampleTrade, style: .compact)
        TradeRowView(trade: sampleTrade, style: .detailed)
        TradeRowView(trade: sampleTrade, style: .card)
        TradeRowView(trade: sampleTrade, style: .withIndicator)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
