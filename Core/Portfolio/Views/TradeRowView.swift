//
//  TradeRowView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Core/Portfolio/Views/TradeRowView.swift
import SwiftUI

struct TradeRowView: View {
    let trade: Trade
    
    var body: some View {
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
                    if trade.profitLoss >= 0 {
                        Text("+$\(trade.profitLoss, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.marketGreen)
                    } else {
                        Text("-$\(abs(trade.profitLoss), specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.marketRed)
                    }
                    
                    Text("\(trade.profitLossPercentage, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                }
                
                Text("$\(trade.entryPrice, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.2), radius: 2)
    }
}

#Preview {
    let sampleTrade = Trade(ticker: "AAPL", tradeType: .stock, entryPrice: 150.00, quantity: 10, userId: UUID())
    
    TradeRowView(trade: sampleTrade)
        .padding()
}
