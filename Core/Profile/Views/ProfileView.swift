// File: Core/Profile/Views/ProfileView.swift
// The signed-in user's profile: header, stats and tabbed content.

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var postsViewModel = UserPostsViewModel()
    @StateObject private var groupsViewModel = UserGroupsViewModel()
    
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var selectedTab: ProfileTab = .posts
    @State private var showPortfolioDetails = false
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Modern Gradient Header
                modernHeaderSection
                
                // Main Content Area
                VStack(spacing: 20) {
                    // Quick Stats Card
                    quickStatsCard
                    
                    // Portfolio Performance Card
                    portfolioPerformanceCard
                    
                    // Tab Content
                    tabContentSection
                }
                .padding(.horizontal)
                .padding(.top, -30) // Overlap with header
            }
        }
        .ignoresSafeArea(.all, edges: .top) // Extend to full top
        .refreshable {
            await refreshProfile()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showPortfolioDetails) {
            PortfolioDetailsSheet()
                .environmentObject(portfolioViewModel)
        }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
            postsViewModel.loadUserPosts(userId: authService.currentUser?.id ?? "")
            groupsViewModel.loadUserGroups(userId: authService.currentUser?.id ?? "")
        }
    }
    
    // MARK: - Modern Header Section
    private var modernHeaderSection: some View {
        GeometryReader { geometry in
            ZStack {
                // Gradient Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.arkadGold.opacity(0.9),
                        Color.arkadGold.opacity(0.7),
                        Color.arkadGold.opacity(0.5)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Decorative elements
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .offset(x: -150, y: -80)
                
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 60, height: 60)
                    .offset(x: 140, y: -100)
                
                VStack(spacing: 0) {
                    // Top Bar with Safe Area
                    HStack {
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .opacity(0) // Hidden for main profile
                        
                        Spacer()
                        
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, geometry.safeAreaInsets.top + 50) // Proper safe area + extra padding
                    
                    Spacer()
                    
                    // Profile Info
                    VStack(spacing: 20) {
                        // Profile Image - Fixed to match EditProfileView pattern
                        Group {
                            if let imageUrl = authService.currentUser?.profileImageUrl,
                               !imageUrl.isEmpty {
                                AsyncImage(url: URL(string: imageUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.arkadGold.opacity(0.2))
                                        .overlay(
                                            ProgressView()
                                                .tint(.arkadGold)
                                        )
                                }
                            } else {
                                // Fallback to initials
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.arkadGold.opacity(0.8),
                                                Color.arkadGold.opacity(0.6)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Text(String(authService.currentUser?.username.prefix(2) ?? "LA").uppercased())
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                        .frame(width: 110, height: 110)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 5)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        // User Info
                        VStack(spacing: 8) {
                            Text(authService.currentUser?.fullName ?? "User Name")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 16) {
                                Text("@\(authService.currentUser?.username ?? "username")")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text("Joined \(formatJoinDate())")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .frame(height: 320) // Increased height to account for full top extension
        .clipped()
    }
    
    // MARK: - Quick Stats Card
    private var quickStatsCard: some View {
        VStack(spacing: 20) {
            // Header with Edit Profile Button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trading Profile")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Your performance overview")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Button(action: { showEditProfile = true }) {
                    Text("Edit Profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.arkadGold.opacity(0.1))
                        .cornerRadius(20)
                }
            }
            
            // Stats Grid
            HStack(spacing: 16) {
                statItem(
                    title: "Followers",
                    value: "0",
                    action: { showFollowersList = true }
                )
                
                statItem(
                    title: "Following",
                    value: "2",
                    action: { showFollowingList = true }
                )
                
                statItem(
                    title: "Trades",
                    value: "\(portfolioViewModel.getPortfolioSummaryForProfile().totalTrades)",
                    action: nil
                )
                
                statItem(
                    title: "Win Rate",
                    value: String(format: "%.1f%%", portfolioViewModel.getPortfolioSummaryForProfile().winRate),
                    action: nil
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Portfolio Performance Card
    private var portfolioPerformanceCard: some View {
        Button(action: { showPortfolioDetails = true }) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Performance Tracker")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("Tap to view detailed analytics")
                            .font(.caption)
                            .foregroundColor(.arkadGold)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.subheadline)
                        .foregroundColor(.arkadGold)
                }
                
                // Main Metric
                VStack(spacing: 8) {
                    Text("Total P&L")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    
                    Text(portfolioViewModel.getPortfolioSummaryForProfile().totalProfitLoss.asCurrencyWithSign)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(portfolioViewModel.getPortfolioSummaryForProfile().totalProfitLoss >= 0 ? .marketGreen : .marketRed)

                }
                
                // Performance Metrics
                HStack(spacing: 20) {
                    performanceMetric(
                        title: "Today",
                        value: portfolioViewModel.getPortfolioSummaryForProfile().dayProfitLoss.asCurrencyWithSign,
                        color: portfolioViewModel.getPortfolioSummaryForProfile().dayProfitLoss >= 0 ? .marketGreen : .marketRed,
                        icon: "calendar"
                    )
                    
                    performanceMetric(
                        title: "Win Rate",
                        value: String(format: "%.1f%%", portfolioViewModel.getPortfolioSummaryForProfile().winRate),
                        color: portfolioViewModel.getPortfolioSummaryForProfile().winRate >= 50 ? .marketGreen : .marketRed,
                        icon: "target"
                    )
                    
                    performanceMetric(
                        title: "Trades",
                        value: "\(portfolioViewModel.getPortfolioSummaryForProfile().totalTrades)",
                        color: .arkadGold,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.arkadGold.opacity(0.05),
                                Color.white
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.arkadGold.opacity(0.1), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Tab Content Section
    private var tabContentSection: some View {
        VStack(spacing: 16) {
            // Modern Tab Selector
            modernTabSelector
            
            // Tab Content
            ProfileTabContent(
                selectedTab: selectedTab,
                portfolioViewModel: portfolioViewModel,
                postsViewModel: postsViewModel,
                groupsViewModel: groupsViewModel
            )
        }
    }
    
    // MARK: - Modern Tab Selector
    private var modernTabSelector: some View {
        ProfileTabSelector(selectedTab: $selectedTab)
    }
    
    // MARK: - Helper Views
    private func statItem(title: String, value: String, action: (() -> Void)?) -> some View {
        Button(action: action ?? {}) {
            VStack(spacing: 8) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
    
    private func performanceMetric(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
    
    @MainActor
    private func refreshProfile() async {
        // Refresh the current user data from Firebase
        await authService.refreshCurrentUser()
        
        // Refresh other profile data
        portfolioViewModel.refreshPortfolio()
        await postsViewModel.refreshPosts()
        await groupsViewModel.refreshGroups()
    }
    
    // MARK: - Helper Methods
    private func formatJoinDate() -> String {
        guard let user = authService.currentUser else { return "recently" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: user.createdAt)
    }
}


#Preview {
    ProfileView()
        .environmentObject(FirebaseAuthService.shared)
}
