// File: Core/Communities/Views/Main/CommunitiesView+Leaderboard.swift
// The global leaderboard tab.

import SwiftUI

// MARK: - Leaderboard Content
extension CommunitiesView {
    var leaderboardContent: some View {
        VStack(spacing: 24) {
            // Enhanced Segmented Control
            HStack(spacing: 0) {
                ForEach(LeaderboardMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedLeaderboardMode = mode
                        }
                        
                        if mode == .globalTraders {
                            Task {
                                await globalLeaderboardViewModel.loadGlobalLeaderboard()
                            }
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(mode.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(selectedLeaderboardMode == mode ? .arkadBlack : .textSecondary)
                            
                            // Animated underline
                            Rectangle()
                                .fill(Color.arkadGold)
                                .frame(height: 3)
                                .cornerRadius(1.5)
                                .opacity(selectedLeaderboardMode == mode ? 1 : 0)
                                .animation(.easeInOut(duration: 0.2), value: selectedLeaderboardMode)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Rectangle()
                                .fill(selectedLeaderboardMode == mode ? Color.arkadGold.opacity(0.08) : Color.clear)
                        )
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.borderPrimary.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Content
            Group {
                switch selectedLeaderboardMode {
                case .communities:
                    communityLeaderboardsContent
                case .globalTraders:
                    globalTradersContent
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedLeaderboardMode)
        }
    }
    
    var communityLeaderboardsContent: some View {
        LazyVStack(spacing: 14) {
            ForEach(viewModel.userCommunities) { community in
                communityLeaderboardCard(community: community)
            }
        }
    }
    
    func communityLeaderboardCard(community: Community) -> some View {
        Button(action: {
            navigateToLeaderboard(community)
        }) {
            HStack(spacing: 18) {
                // Avatar with trophy overlay
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    getCommunityColor(for: community.type),
                                    getCommunityColor(for: community.type).opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Text(getCommunityInitials(from: community.name))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Trophy badge
                    ZStack {
                        Circle()
                            .fill(Color.arkadGold)
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.arkadBlack)
                    }
                    .offset(x: 2, y: 2)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(community.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("\(community.memberCount) members")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                        
                        Text("•")
                            .foregroundColor(.textTertiary)
                        
                        Text("View Rankings")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.arkadGold)
                    }
                }
                
                Spacer()
                
                // Action
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.arkadGold.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.arkadGold)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.arkadGold.opacity(0.2), Color.arkadGold.opacity(0.1)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    var globalTradersContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Top Traders")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text("Everyone on Arkad, ranked by their closed trades")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }

            LeaderboardFilterBar(
                category: $globalLeaderboardViewModel.category,
                timeframe: $globalLeaderboardViewModel.timeframe,
                horizontalPadding: 0
            )

            if globalLeaderboardViewModel.isLoading {
                loadingView
            } else if !globalLeaderboardViewModel.errorMessage.isEmpty {
                errorView
            } else if globalLeaderboardViewModel.entries.isEmpty {
                emptyGlobalTradersView
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(globalLeaderboardViewModel.entries) { entry in
                        Button {
                            openGlobalProfile(userId: entry.userId)
                        } label: {
                            LeaderboardRow(
                                entry: entry,
                                category: globalLeaderboardViewModel.category,
                                isCurrentUser: entry.userId == authService.currentUser?.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onChange(of: globalLeaderboardViewModel.category) { _, _ in globalLeaderboardViewModel.reload() }
        .onChange(of: globalLeaderboardViewModel.timeframe) { _, _ in globalLeaderboardViewModel.reload() }
        .onAppear {
            if globalLeaderboardViewModel.entries.isEmpty && !globalLeaderboardViewModel.isLoading {
                Task { await globalLeaderboardViewModel.loadGlobalLeaderboard() }
            }
        }
        .sheet(item: $globalProfileUser) { user in
            OtherUserProfileView(user: user)
                .environmentObject(authService)
        }
    }

    func openGlobalProfile(userId: String) {
        guard userId != authService.currentUser?.id else { return }
        Task { globalProfileUser = try? await authService.getUserById(userId: userId) }
    }
}
