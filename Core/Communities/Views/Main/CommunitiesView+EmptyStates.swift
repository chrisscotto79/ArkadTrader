// File: Core/Communities/Views/Main/CommunitiesView+EmptyStates.swift
// Empty and loading states for the Communities tabs.

import SwiftUI

// MARK: - Empty States (Enhanced)
extension CommunitiesView {
    var emptyMyCommunitiesState: some View {
        VStack(spacing: 28) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold.opacity(0.1), Color.arkadGold.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 14) {
                Text("No Communities Yet")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("Join communities to connect with other traders\nand share trading insights")
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button("Explore Communities") {
                selectedTab = .discover
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: .arkadGold.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .padding(.top, 80)
    }
    
    var emptyLeaderboardState: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold.opacity(0.1), Color.arkadGold.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "trophy.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 14) {
                Text("Join Communities First")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("Join communities to see leaderboards\nand compete with other traders")
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button("Explore Communities") {
                selectedTab = .discover
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: .arkadGold.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .padding(.top, 80)
    }
    
    var emptyGlobalTradersView: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.arkadGold.opacity(0.6), Color.arkadGold.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: 8) {
                Text("No Global Data Yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text("Global leaderboards will appear as more traders join")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.borderPrimary.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .arkadGold))
                .scaleEffect(1.2)
            
            Text("Loading global traders...")
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.borderPrimary.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    var errorView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Unable to Load Data")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(globalLeaderboardViewModel.errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                Task {
                    await globalLeaderboardViewModel.refresh()
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.arkadGold)
            )
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
