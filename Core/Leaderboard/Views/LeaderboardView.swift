//
//  LeaderboardView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Core/Leaderboard/Views/LeaderboardView.swift

import SwiftUI

struct LeaderboardView: View {
    @State private var selectedTimeframe: TimeFrame = .weekly
    
    let mockLeaderboard = [
        LeaderboardEntry(rank: 1, username: "ProTrader", profitLoss: 15240.50, winRate: 78.5, isVerified: true),
        LeaderboardEntry(rank: 2, username: "BullRunner", profitLoss: 12890.25, winRate: 72.3, isVerified: true),
        LeaderboardEntry(rank: 3, username: "MarketMaster", profitLoss: 11650.00, winRate: 69.8, isVerified: false),
        LeaderboardEntry(rank: 4, username: "TradingGuru", profitLoss: 9875.75, winRate: 68.2, isVerified: true),
        LeaderboardEntry(rank: 5, username: "StockWiz", profitLoss: 8420.30, winRate: 65.7, isVerified: false)
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Time frame picker
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Market sentiment card
                VStack {
                    HStack {
                        Text("Market Sentiment")
                            .font(.headline)
                        
                        Spacer()
                        
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                            Text("Bullish 68%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Text("Community is feeling optimistic about the markets")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Leaderboard list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(mockLeaderboard, id: \.rank) { entry in
                            LeaderboardRowView(entry: entry)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Leaderboard")
        }
    }
}



enum TimeFrame: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case allTime = "All Time"
}

#Preview {
    LeaderboardView()
}
