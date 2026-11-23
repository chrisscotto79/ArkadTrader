//
//  TradeCardView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//


import SwiftUI

// MARK: - Trade Card View
/// A followed trader's public trade in the Following feed.
struct TradeCardView: View {
    let trade: Trade
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var trader: User?
    @State private var showProfile = false
    
    private var traderName: String {
        trader?.username ?? ""
    }
    
    /// "@name opened AAPL" once the trader has loaded, "Opened AAPL" until then.
    private var title: String {
        let action = trade.isOpen ? "opened" : "closed"
        if let trader {
            return "@\(trader.username) \(action) \(trade.ticker)"
        }
        return "\(action.capitalized) \(trade.ticker)"
    }
    
    private var eventDate: Date {
        trade.isOpen ? trade.entryDate : (trade.exitDate ?? trade.entryDate)
    }
    
    private var quantityLabel: String {
        trade.tradeType == .option ? "Contracts" : "Shares"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    if trader != nil { showProfile = true }
                } label: {
                    UserAvatar(username: traderName, imageURL: trader?.profileImageUrl, size: 40)
                }
                .buttonStyle(.plain)
                .disabled(trader == nil)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(eventDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                Text(trade.isOpen ? "OPEN" : "CLOSED")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(trade.isOpen ? Color.arkadGold.opacity(0.15) : Color.gray.opacity(0.1))
                    .foregroundColor(trade.isOpen ? .arkadGoldDark : .gray)
                    .cornerRadius(12)
            }
            
            // Trade info
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Entry")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(trade.entryPrice.asCurrency)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                if let exitPrice = trade.exitPrice, !trade.isOpen {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Exit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(exitPrice.asCurrency)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(quantityLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(trade.quantity.quantityString)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            
            if !trade.isOpen {
                Text("\(trade.profitLoss.asCurrencyWithSign) (\(String(format: "%+.1f%%", trade.profitLossPercentage)))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
            }
            
            if let notes = trade.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .task(id: trade.userId) {
            guard trader == nil else { return }
            trader = try? await authService.getUserById(userId: trade.userId)
        }
        .sheet(isPresented: $showProfile) {
            if let trader {
                OtherUserProfileView(user: trader)
                    .environmentObject(authService)
            }
        }
    }
}

// MARK: - Activity Card View
