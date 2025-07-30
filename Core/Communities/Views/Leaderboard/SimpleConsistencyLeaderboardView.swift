// File: Core/Communities/Views/Leaderboard/SimpleConsistencyLeaderboardView.swift
// Enhanced Leaderboard View - Fixed with User Profiles & Working Follow Button

import SwiftUI

struct SimpleConsistencyLeaderboardView: View {
    let community: Community
    
    @StateObject private var viewModel = CommunityLeaderboardViewModel()
    @State private var debugInfo = "Starting..."
    @EnvironmentObject var authService: FirebaseAuthService
    
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
                                .environmentObject(authService)
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
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    
    private var isCurrentUser: Bool {
        authService.currentUser?.id == entry.userId
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with rank, avatar, and basic info
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
                
                // User Avatar
                Button(action: {
                    if !isCurrentUser {
                        handleProfileTap()
                    }
                }) {
                    AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(entry.username)")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.arkadGold)
                            .overlay(
                                Text(userInitials)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.arkadGold.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isCurrentUser)
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: {
                        if !isCurrentUser {
                            handleProfileTap()
                        }
                    }) {
                        HStack {
                            Text(entry.username)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if isCurrentUser {
                                Text("(You)")
                                    .font(.caption)
                                    .foregroundColor(.arkadGold)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isCurrentUser)
                    
                    Text("\(String(format: "%.1f", entry.winRate))% win rate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Performance indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Performance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(entry.totalProfitLoss >= 0 ? .green : .red)
                            .frame(width: 8, height: 8)
                        
                        Text(entry.totalProfitLoss >= 0 ? "Profitable" : "Learning")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(entry.totalProfitLoss >= 0 ? .green : .red)
                    }
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
                    Text("Consistency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Circle()
                                .fill(index < Int(entry.winRate / 20) ? Color.arkadGold : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Trader Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(getTraderLevel())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Activity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(entry.totalTrades) trades")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Follow Button - Only show for other users
            if !isCurrentUser {
                SimpleFollowButton(
                    targetUserId: entry.userId,
                    targetUsername: entry.username
                )
                .padding(.horizontal)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .overlay(
                    // Highlight current user card
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCurrentUser ? Color.arkadGold.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
        .sheet(isPresented: $showOtherUserProfile) {
            if let profileUser = profileUser {
                OtherUserProfileView(user: profileUser)
                    .environmentObject(authService)
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
    
    private var userInitials: String {
        let names = entry.username.split(separator: " ")
        if names.count > 1 {
            let firstInitial = names.first?.first ?? Character("U")
            let lastInitial = names.last?.first ?? Character("U")
            return String(firstInitial) + String(lastInitial)
        } else {
            let username = entry.username
            let firstChar = username.first ?? Character("U")
            let secondChar = username.count > 1 ? username[username.index(username.startIndex, offsetBy: 1)] : Character("U")
            return String(firstChar) + String(secondChar)
        }
    }
    
    private func getTraderLevel() -> String {
        if entry.totalTrades < 5 {
            return "🌱 Beginner"
        } else if entry.totalTrades < 20 {
            return "📈 Growing"
        } else if entry.totalTrades < 50 {
            return "💪 Active"
        } else if entry.winRate > 70 {
            return "🏆 Expert"
        } else {
            return "⭐ Veteran"
        }
    }
    
    // MARK: - Profile Navigation
    
    private func handleProfileTap() {
        Task {
            await loadUserProfile()
        }
    }
    
    private func loadUserProfile() async {
        guard profileUser == nil else {
            await MainActor.run {
                showOtherUserProfile = true
            }
            return
        }
        
        await MainActor.run {
            isLoadingUser = true
        }
        
        do {
            if let user = try await authService.getUserById(userId: entry.userId) {
                await MainActor.run {
                    profileUser = user
                    isLoadingUser = false
                    showOtherUserProfile = true
                }
            } else {
                // Fallback: create a minimal user
                await MainActor.run {
                    profileUser = createMinimalUser()
                    isLoadingUser = false
                    showOtherUserProfile = true
                }
            }
        } catch {
            print("❌ Error loading user profile: \(error)")
            
            await MainActor.run {
                profileUser = createMinimalUser()
                isLoadingUser = false
                showOtherUserProfile = true
            }
        }
    }
    
    private func createMinimalUser() -> User {
        var user = User(
            id: entry.userId,
            email: "\(entry.username)@example.com",
            username: entry.username,
            fullName: entry.username.capitalized
        )
        
        user.bio = "Trader on ArkadTrader"
        user.followersCount = 0
        user.followingCount = 0
        user.totalProfitLoss = entry.totalProfitLoss
        user.winRate = entry.winRate
        
        return user
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
    .environmentObject(FirebaseAuthService.shared)
}
