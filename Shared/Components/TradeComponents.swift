// File: Shared/Components/TradeComponents.swift
// Fixed trade components - avoids naming conflicts with existing components

import SwiftUI

// MARK: - Enhanced Trade Card (no conflicts)
struct EnhancedTradeCard: View {
    let trade: Trade
    let style: TradeCardStyle
    let onTap: (() -> Void)?
    
    enum TradeCardStyle {
        case compact, standard, detailed
        
        var height: CGFloat {
            switch self {
            case .compact: return 80
            case .standard: return 100
            case .detailed: return 120
            }
        }
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                // Status Indicator
                statusIndicator
                
                // Trade Info
                tradeInfoSection
                
                Spacer()
                
                // Value Section
                valueSection
                
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .frame(height: style.height)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Circle()
                .stroke(statusColor, lineWidth: 2)
                .frame(width: 40, height: 40)
            
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }
    
    private var tradeInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
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
            }
            
            Text("\(trade.quantity) shares")
                .font(.caption)
                .foregroundColor(.gray)
            
            if style == .detailed {
                Text("Entry: \(trade.entryPrice.asCurrency)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var valueSection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if trade.isOpen {
                Text(trade.currentValue.asCurrency)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                if style != .compact {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                
                if style != .compact {
                    Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.1f", trade.profitLossPercentage))%")
                        .font(.caption)
                        .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                }
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
    
    private var statusIcon: String {
        if trade.isOpen {
            return "clock"
        } else {
            return trade.profitLoss >= 0 ? "arrow.up" : "arrow.down"
        }
    }
}

// MARK: - Simple Metric Card (renamed to avoid conflicts)
struct MetricDisplayCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
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
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Trading Insight Card (renamed to avoid conflicts)
struct TradingInsightCard: View {
    let title: String
    let message: String
    let type: InsightType
    let action: (() -> Void)?
    
    enum InsightType {
        case tip, warning, success, info
        
        var color: Color {
            switch self {
            case .tip: return .blue
            case .warning: return .orange
            case .success: return .green
            case .info: return .purple
            }
        }
        
        var icon: String {
            switch self {
            case .tip: return "lightbulb.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundColor(type.color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
            
            if let action = action {
                Button("Learn More") {
                    action()
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(type.color)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(type.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(type.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Performance Badge Component (simple version)
struct TradingPerformanceBadge: View {
    let value: Double
    let type: BadgeType
    
    enum BadgeType {
        case profitLoss, percentage, winRate
        
        func color(for value: Double) -> Color {
            switch self {
            case .profitLoss:
                return value >= 0 ? .green : .red
            case .percentage:
                return value >= 0 ? .green : .red
            case .winRate:
                if value >= 70 { return .green }
                else if value >= 50 { return .orange }
                else { return .red }
            }
        }
        
        func formattedValue(_ value: Double) -> String {
            switch self {
            case .profitLoss:
                return value.asCurrencyWithSign
            case .percentage:
                return "\(value >= 0 ? "+" : "")\(String(format: "%.1f", value))%"
            case .winRate:
                return "\(String(format: "%.0f", value))%"
            }
        }
        
        var icon: String {
            switch self {
            case .profitLoss:
                return "dollarsign.circle.fill"
            case .percentage:
                return "percent"
            case .winRate:
                return "target"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: type.icon)
                .font(.caption)
                .foregroundColor(type.color(for: value))
            
            Text(type.formattedValue(value))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(type.color(for: value))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(type.color(for: value).opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Sample trade for preview
        let sampleTrade = Trade(ticker: "AAPL", tradeType: .stock, entryPrice: 150.00, quantity: 10, userId: "sample")
        
        EnhancedTradeCard(trade: sampleTrade, style: .standard, onTap: {})
        
        MetricDisplayCard(
            title: "Total Portfolio",
            value: "$52,345",
            color: .green,
            icon: "chart.pie.fill"
        )
        
        TradingInsightCard(
            title: "Great Performance!",
            message: "Your win rate of 75% is excellent. Keep up the great work!",
            type: .success,
            action: {}
        )
        
        HStack {
            TradingPerformanceBadge(value: 1250.50, type: .profitLoss)
            TradingPerformanceBadge(value: 15.8, type: .percentage)
            TradingPerformanceBadge(value: 72.5, type: .winRate)
        }
    }
    .padding()
}
