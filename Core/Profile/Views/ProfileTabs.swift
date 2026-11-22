// File: Core/Profile/Views/ProfileTabs.swift
// Profile tab selector and the Posts, Trades, Portfolio and Groups tab contents.

import SwiftUI

// MARK: - Profile Tab Selector (Reusable Component)
struct ProfileTabSelector: View {
    @Binding var selectedTab: ProfileTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedTab == tab ? .arkadGold : .textSecondary)
                        
                        Text(tab.title)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedTab == tab ? .arkadGold : .textSecondary)
                        
                        // Active indicator
                        Circle()
                            .fill(selectedTab == tab ? Color.arkadGold : Color.clear)
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedTab == tab ? Color.arkadGold.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Portfolio Details Sheet
struct PortfolioDetailsSheet: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            PortfolioView()
                .environmentObject(portfolioViewModel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.arkadGold)
                        .fontWeight(.semibold)
                    }
                }
        }
    }
}

// MARK: - Profile Tab Content
struct ProfileTabContent: View {
    let selectedTab: ProfileTab
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    @ObservedObject var postsViewModel: UserPostsViewModel
    @ObservedObject var groupsViewModel: UserGroupsViewModel
    
    var body: some View {
        switch selectedTab {
        case .posts:
            UserPostsTab(postsViewModel: postsViewModel)
        case .trades:
            UserTradesTab(portfolioViewModel: portfolioViewModel)
        case .portfolio:
            UserPortfolioTab(portfolioViewModel: portfolioViewModel)
        case .groups:
            UserGroupsTab(groupsViewModel: groupsViewModel)
        }
    }
}

// MARK: - User Posts Tab
struct UserPostsTab: View {
    @ObservedObject var postsViewModel: UserPostsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if postsViewModel.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.arkadGold)
                    
                    Text("Loading posts...")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 60)
            } else if !postsViewModel.errorMessage.isEmpty {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.arkadGold.opacity(0.6))
                    
                    Text("Failed to Load Posts")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text(postsViewModel.errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        Task {
                            await postsViewModel.refreshPosts()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 60)
            } else if postsViewModel.posts.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 48))
                        .foregroundColor(.arkadGold.opacity(0.6))
                    
                    Text("No Posts Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Share your trading insights and market thoughts with the community")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    NavigationLink(destination: HomeView().environmentObject(FirebaseAuthService.shared)) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Create Your First Post")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 60)
            } else {
                // Posts content
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("My Posts (\(postsViewModel.posts.count))")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.textPrimary)
                            
                            Text("Your trading insights and updates")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                        
                        if postsViewModel.posts.count > 6 {
                            NavigationLink(destination: HomeView().environmentObject(FirebaseAuthService.shared)) {
                                HStack(spacing: 4) {
                                    Text("View All")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.arkadGold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.arkadGold.opacity(0.1))
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Enhanced Posts grid
                    LazyVStack(spacing: 16) {
                        ForEach(postsViewModel.posts.prefix(6), id: \.id) { post in
                            ProfileUserPostCard(
                                post: post,
                                onPostDeleted: {
                                    Task {
                                        await postsViewModel.refreshPosts()
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer(minLength: 100)
        }
        .refreshable {
            await postsViewModel.refreshPosts()
        }
    }
}

// MARK: - User Trades Tab
struct UserTradesTab: View {
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if portfolioViewModel.trades.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.arkadGold.opacity(0.6))
                    
                    Text("No Trades Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Start logging your trades to track your performance and share your success with the community")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    NavigationLink(destination: PortfolioView().environmentObject(portfolioViewModel)) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add Your First Trade")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 60)
            } else {
                // Recent trades
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Trades")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        NavigationLink(destination: PortfolioView().environmentObject(portfolioViewModel)) {
                            Text("View All")
                                .font(.subheadline)
                                .foregroundColor(.arkadGold)
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(portfolioViewModel.trades.prefix(10)), id: \.id) { trade in
                                ProfileUserTradeCard(trade: trade)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Spacer(minLength: 100)
        }
    }
}

// MARK: - User Portfolio Tab
struct UserPortfolioTab: View {
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Performance summary
                VStack(alignment: .leading, spacing: 16) {
                    Text("Performance Summary")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        performanceCard(
                            title: "Total Return",
                            value: portfolioViewModel.getPortfolioSummaryForProfile().totalProfitLoss.asCurrencyWithSign,
                            color: portfolioViewModel.getPortfolioSummaryForProfile().totalProfitLoss >= 0 ? .marketGreen : .marketRed,
                            icon: "dollarsign.circle.fill"
                        )
                        
                        performanceCard(
                            title: "Win Rate",
                            value: String(format: "%.1f%%", portfolioViewModel.getPortfolioSummaryForProfile().winRate),
                            color: portfolioViewModel.getPortfolioSummaryForProfile().winRate >= 50 ? .marketGreen : .marketRed,
                            icon: "target"
                        )
                        
                        performanceCard(
                            title: "Best Trade",
                            value: getBestTradeValue(),
                            color: .marketGreen,
                            icon: "star.fill"
                        )
                        
                        performanceCard(
                            title: "Total Trades",
                            value: "\(portfolioViewModel.getPortfolioSummaryForProfile().totalTrades)",
                            color: .arkadGold,
                            icon: "number.circle.fill"
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Top positions
                if !portfolioViewModel.trades.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Top Performing Positions")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ForEach(Array(getTopPerformingTrades().prefix(5)), id: \.id) { trade in
                            TopPositionCard(trade: trade)
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 100)
            }
        }
    }
    
    private func getBestTradeValue() -> String {
        let bestTrade = portfolioViewModel.trades.max { $0.profitLoss < $1.profitLoss }
        return bestTrade?.profitLoss.asCurrencyWithSign ?? "$0"
    }
    
    private func getTopPerformingTrades() -> [Trade] {
        return portfolioViewModel.trades.sorted { $0.profitLoss > $1.profitLoss }
    }
    
    private func performanceCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - User Groups Tab
struct UserGroupsTab: View {
    @ObservedObject var groupsViewModel: UserGroupsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if groupsViewModel.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.arkadGold)
                    
                    Text("Loading groups...")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 60)
            } else if !groupsViewModel.errorMessage.isEmpty {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.arkadGold.opacity(0.6))
                    
                    Text("Failed to Load Groups")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text(groupsViewModel.errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        Task {
                            await groupsViewModel.refreshGroups()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 60)
            } else if groupsViewModel.groups.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "person.3")
                        .font(.system(size: 48))
                        .foregroundColor(.arkadGold.opacity(0.6))
                    
                    Text("No Groups Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Join trading communities to connect with like-minded traders and share strategies")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    NavigationLink(destination: CommunitiesView()) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                            Text("Discover Groups")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 60)
            } else {
                // Groups content
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("My Groups (\(groupsViewModel.groups.count))")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        NavigationLink(destination: CommunitiesView()) {
                            Text("Discover More")
                                .font(.subheadline)
                                .foregroundColor(.arkadGold)
                        }
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(groupsViewModel.groups, id: \.id) { group in
                            ProfileUserGroupCard(group: group)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer(minLength: 100)
        }
        .refreshable {
            await groupsViewModel.refreshGroups()
        }
    }
}

// MARK: - Supporting Types and View Models
enum ProfileTab: CaseIterable {
    case posts, trades, portfolio, groups
    
    var title: String {
        switch self {
        case .posts: return "Posts"
        case .trades: return "Trades"
        case .portfolio: return "Portfolio"
        case .groups: return "Groups"
        }
    }
    
    var icon: String {
        switch self {
        case .posts: return "square.and.pencil"
        case .trades: return "chart.line.uptrend.xyaxis"
        case .portfolio: return "chart.bar.fill"
        case .groups: return "person.3.fill"
        }
    }
}
