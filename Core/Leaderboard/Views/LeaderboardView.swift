// File: Core/Leaderboard/Views/LeaderboardView.swift
// Simplified Leaderboard View

import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // Timeframe Picker
                Picker("Timeframe", selection: $viewModel.selectedTimeframe) {
                    ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Leaderboard List
                if viewModel.isLoading {
                    LoadingView()
                        .padding(.top, 50)
                } else if viewModel.leaderboard.isEmpty {
                    Text("No data available")
                        .foregroundColor(.gray)
                        .padding(.top, 50)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.leaderboard) { entry in
                                LeaderboardRowView(entry: entry)
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Leaderboard")
        }
    }
}

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack {
            // Rank
            Text("#\(entry.rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 40, alignment: .leading)
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.username)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if entry.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
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
                    .foregroundColor(.green)
                
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
    LeaderboardView()
}
