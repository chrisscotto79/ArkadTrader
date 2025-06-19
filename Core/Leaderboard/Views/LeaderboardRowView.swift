//
//  LeaderboardRowView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//
//
//  LeaderboardRowView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

import SwiftUI

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack {
            // Rank
            Text("#\(entry.rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.arkadGold)
                .frame(width: 40, alignment: .leading)
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.username)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if entry.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.arkadGold)
                            .font(.caption)
                    }
                }
                
                Text("Win Rate: \(entry.winRate, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // P&L
            VStack(alignment: .trailing) {
                Text("+$\(entry.profitLoss, specifier: "%.0f")")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.marketGreen)
                
                Text("Total P&L")
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
    LeaderboardRowView(entry: LeaderboardEntry(rank: 1, username: "ProTrader", profitLoss: 15240.50, winRate: 78.5, isVerified: true))
        .padding()
}
