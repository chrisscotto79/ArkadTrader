//
//  PortfolioView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//


// File: Core/Portfolio/Views/PortfolioView.swift

import SwiftUI

struct PortfolioView: View {
    @State private var showAddTrade = false
    @State private var mockTrades: [Trade] = []
    
    var body: some View {
        NavigationView {
            VStack {
                // Portfolio Summary Card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Portfolio Value")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("$12,450.00")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Today's P&L")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("+$245.00 (+2.01%)")
                                .font(.headline)
                                .foregroundColor(.marketGreen)
                        }
                    }
                    
                    HStack {
                        StatCard(title: "Win Rate", value: "68%", color: .arkadGold)
                        StatCard(title: "Total Trades", value: "24", color: .arkadGold)
                        StatCard(title: "Open Positions", value: "3", color: .arkadGold)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Trades List
                VStack(alignment: .leading) {
                    HStack {
                        Text("Recent Trades")
                            .font(.headline)
                        Spacer()
                        Button("View All") {
                            // TODO: Navigate to all trades
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if mockTrades.isEmpty {
                                Text("No trades yet. Add your first trade!")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(mockTrades) { trade in
                                    TradeRowView(trade: trade)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddTrade = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTrade) {
                AddTradeView(trades: $mockTrades)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PortfolioView()
}
