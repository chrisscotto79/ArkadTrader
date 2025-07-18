//
//  TradeCardView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//


import SwiftUI

// MARK: - Simple Trade Card View (Placeholder)
struct TradeCardView: View {
    let trade: Trade
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Simple user avatar
                Circle()
                    .fill(Color.arkadGold)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("T")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trade Update")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(trade.entryDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                Text(trade.isOpen ? "OPEN" : "CLOSED")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(trade.isOpen ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .foregroundColor(trade.isOpen ? .blue : .gray)
                    .cornerRadius(12)
            }
            
            // Trade info
            VStack(alignment: .leading, spacing: 8) {
                Text(trade.ticker)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Entry Price")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(trade.entryPrice.asCurrency)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Quantity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(trade.quantity)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                
                if let notes = trade.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Simple Activity Card View (Placeholder)
