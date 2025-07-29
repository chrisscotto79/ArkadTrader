// File: Core/Communities/Views/Leaderboard/SimpleConsistencyLeaderboardView.swift
// Enhanced Leaderboard View - Matching Your Vision

import SwiftUI

struct SimpleConsistencyLeaderboardView: View {
    let community: Community
    
    @StateObject private var viewModel = CommunityLeaderboardViewModel()
    @State private var debugInfo = "Starting..."
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("Leaderboard - \(community.name)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("*Based on closed trades with performance data")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Debug info (you can remove this later)
                Text("Debug: \(debugInfo)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            .padding(.bottom, 20)
            
            if viewModel.isLoading {
                ProgressView("Loading rankings...")
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else if !viewModel.errorMessage.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Error Loading Leaderboard")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(viewModel.errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else if viewModel.leaderboardEntries.isEmpty {
                emptyStateView
                
            } else {
                // Enhanced Leaderboard List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.leaderboardEntries) { entry in
                            EnhancedLeaderboardCard(entry: entry)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
            
            Spacer()
            
            // Refresh Button
            Button("Refresh Rankings") {
                debugInfo = "Refresh tapped..."
                viewModel.refresh(communityId: community.id)
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            debugInfo = "View appeared, loading data..."
            viewModel.loadLeaderboard(communityId: community.id)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Rankings Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Complete some trades to appear on the leaderboard!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Enhanced Leaderboard Card
struct EnhancedLeaderboardCard: View {
    let entry: CommunityLeaderboardEntry
    
    private var isCurrentUser: Bool {
        // You can check if this is the current user
        return false // For now, we'll enhance this later
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with rank and basic info
            HStack {
                // Rank Badge
                ZStack {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 50, height: 50)
                    
                    if entry.rank <= 3 {
                        Image(systemName: rankIcon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("#\(entry.rank)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.username)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("\(String(format: "%.1f", entry.winRate))% win rate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Top stock placeholder (we'll enhance this)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Top Stock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("AAPL") // We'll make this dynamic later
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            // Stats Row
            HStack {
                statItem(title: "Total Trades", value: "\(entry.totalTrades)", icon: "chart.bar.fill")
                
                Divider()
                    .frame(height: 40)
                
                statItem(title: "Win Rate", value: String(format: "%.1f%%", entry.winRate), icon: "target")
                
                Divider()
                    .frame(height: 40)
                
                statItem(title: "P&L", value: formatProfitLoss(entry.totalProfitLoss), icon: "dollarsign.circle.fill")
            }
            .padding(.horizontal)
            
            // Trade Information Row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Biggest Win")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$24.00") // We'll make this dynamic
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Trader Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("🐂 BULL") // We'll determine this based on performance
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Biggest Loss")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$0.00") // We'll make this dynamic
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            
            // Follow Button (placeholder for now)
            Button(action: {
                print("Follow \(entry.username) tapped")
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Follow Trader")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private var rankIcon: String {
        switch entry.rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal"
        default: return ""
        }
    }
    
    private func formatProfitLoss(_ amount: Double) -> String {
        if amount >= 0 {
            return "+$\(String(format: "%.0f", amount))"
        } else {
            return "-$\(String(format: "%.0f", abs(amount)))"
        }
    }
}

#Preview {
    SimpleConsistencyLeaderboardView(
        community: Community(
            name: "Test Community",
            description: "Test",
            type: .general,
            createdBy: "test"
        )
    )
}
