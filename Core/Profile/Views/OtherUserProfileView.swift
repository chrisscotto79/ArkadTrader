//
//  OtherUserProfileView.swift
//  ArkadTrader
//
//  CREATE THIS NEW FILE: Core/Profile/Views/OtherUserProfileView.swift
//  Production-ready view for displaying other users' profiles
//

import SwiftUI

struct OtherUserProfileView: View {
    let user: User
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var postsViewModel = UserPostsViewModel()
    @StateObject private var groupsViewModel = UserGroupsViewModel()
    
    @State private var selectedTab: ProfileTab = .posts
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    @State private var userTrades: [Trade] = []
    @State private var isLoadingTrades = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    
                    // Profile Header for other users
                    OtherUserProfileHeader(
                        user: user,
                        portfolioSummary: calculatePortfolioSummary(),
                        showFollowersList: $showFollowersList,
                        showFollowingList: $showFollowingList
                    )
                    
                    // Portfolio Performance Banner (Read-only for other users)
                    OtherUserPortfolioBanner(
                        portfolioSummary: calculatePortfolioSummary()
                    )
                    
                    // Tab Selection
                    ProfileTabSelector(selectedTab: $selectedTab)
                    
                    // Tab Content (Read-only for other users)
                    OtherUserContent(
                        selectedTab: selectedTab,
                        user: user,
                        userTrades: userTrades,
                        postsViewModel: postsViewModel,
                        groupsViewModel: groupsViewModel
                    )
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
            .overlay(
                // Custom back button
                VStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .frame(width: 32, height: 32)
                                )
                        }
                        .padding(.leading, 16)
                        
                        Spacer()
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                },
                alignment: .topLeading
            )
        }
        .sheet(isPresented: $showFollowersList) {
            SimpleFollowListView(userId: user.id, listType: .followers)
        }
        .sheet(isPresented: $showFollowingList) {
            SimpleFollowListView(userId: user.id, listType: .following)
        }
        .onAppear {
            Task {
                await loadUserData()
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadUserData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await loadUserTrades()
            }
            
            group.addTask {
                postsViewModel.loadUserPosts(userId: user.id)
            }
            
            group.addTask {
                groupsViewModel.loadUserGroups(userId: user.id)
            }
        }
    }
    
    private func loadUserTrades() async {
        isLoadingTrades = true
        
        do {
            let trades = try await authService.getUserTrades(userId: user.id)
            // Only show public trades for other users
            userTrades = trades.filter { $0.isPublic == true }
        } catch {
            print("Error loading user trades: \(error)")
            userTrades = []
        }
        
        isLoadingTrades = false
    }
    
    private func calculatePortfolioSummary() -> PortfolioSummary {
        let closedTrades = userTrades.filter { !$0.isOpen }
        let totalProfitLoss = closedTrades.reduce(0) { $0 + $1.profitLoss }
        let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
        let winRate = closedTrades.isEmpty ? 0.0 : Double(winningTrades) / Double(closedTrades.count) * 100
        
        return PortfolioSummary(
            totalValue: user.totalProfitLoss,
            totalProfitLoss: totalProfitLoss,
            dayProfitLoss: 0.0, // Not available for other users
            winRate: winRate,
            totalTrades: userTrades.count,
            openPositions: userTrades.filter { $0.isOpen }.count,
            recentTrades: Array(userTrades.prefix(5)),
            topPerformer: userTrades.max(by: { $0.profitLoss < $1.profitLoss }),
            lastUpdated: Date()
        )
    }
}

// MARK: - Other User Profile Header
struct OtherUserProfileHeader: View {
    let user: User
    let portfolioSummary: PortfolioSummary
    @Binding var showFollowersList: Bool
    @Binding var showFollowingList: Bool
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Enhanced background with arkad theme
                LinearGradient(
                    colors: [
                        Color.arkadDark,
                        Color.arkadDark.opacity(0.9),
                        Color.arkadDark.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Tech elements overlay
                enhancedTechElements(geometry: geometry)
                
                VStack(spacing: 25) {
                    Spacer().frame(height: 50) // Top spacing for status bar
                    
                    // Profile image with enhanced glow
                    ZStack {
                        Circle()
                            .fill(tierColor.opacity(0.1))
                            .frame(width: 140, height: 140)
                            .shadow(color: tierColor.opacity(0.3), radius: 20, x: 0, y: 0)
                        
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [tierColor, tierColor.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 120, height: 120)
                        
                        Text(userInitials)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(tierColor)
                    }
                    
                    // User name and username with verification
                    VStack(spacing: 8) {
                        HStack {
                            Text(user.fullName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            if user.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                        }
                        
                        HStack {
                            Text("@\(user.username)")
                                .font(.title3)
                                .foregroundColor(.arkadGold)
                                .fontWeight(.medium)
                            
                            Text("•")
                                .foregroundColor(.arkadGold.opacity(0.6))
                            
                            Text(user.subscriptionTier.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tierColor.opacity(0.2))
                                .foregroundColor(tierColor)
                                .cornerRadius(6)
                        }
                    }
                    
                    // Stats with interactive followers/following
                    HStack {
                        Button(action: {
                            showFollowersList = true
                        }) {
                            statColumn(
                                number: "\(user.followersCount)",
                                label: "Followers"
                            )
                        }
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            showFollowingList = true
                        }) {
                            statColumn(
                                number: "\(user.followingCount)",
                                label: "Following"
                            )
                        }
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        statColumn(
                            number: "\(portfolioSummary.totalTrades)",
                            label: "Trades"
                        )
                        
                        Spacer()
                        
                        statColumn(
                            number: String(format: "%.1f%%", portfolioSummary.winRate),
                            label: "Win Rate"
                        )
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Bio section
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 35)
                    }
                    
                    // FOLLOW BUTTON - This will show since it's another user's profile
                    SimpleFollowButton(
                        targetUserId: user.id,
                        targetUsername: user.username
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(height: 500)
        .clipped()
        .ignoresSafeArea(edges: .top)
    }
    
    private var userInitials: String {
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first : nil
        
        if let lastInitial = lastInitial {
            return String(firstInitial) + String(lastInitial)
        } else {
            return String(firstInitial)
        }
    }
    
    private var tierColor: Color {
        switch user.subscriptionTier {
        case .basic: return .gray
        case .pro: return .blue
        case .elite: return .arkadGold
        }
    }
    
    private func statColumn(number: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.arkadGold)
                .fontWeight(.medium)
        }
    }
    
    private func enhancedTechElements(geometry: GeometryProxy) -> some View {
        ZStack {
            Circle()
                .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1.5)
                .frame(width: 25, height: 25)
                .position(x: geometry.size.width * 0.15, y: geometry.size.height * 0.15)
            
            Circle()
                .stroke(Color.arkadGold.opacity(0.15), lineWidth: 1)
                .frame(width: 18, height: 18)
                .position(x: geometry.size.width * 0.85, y: geometry.size.height * 0.12)
        }
    }
}

// MARK: - Other User Portfolio Banner
struct OtherUserPortfolioBanner: View {
    let portfolioSummary: PortfolioSummary
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Public Portfolio Performance")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Text("Public Trades Only")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total P&L")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Text(portfolioSummary.totalProfitLoss.asCurrency)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(portfolioSummary.totalProfitLoss >= 0 ? .arkadGreen : .arkadRed)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Win Rate")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Text(String(format: "%.1f%%", portfolioSummary.winRate))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Public Trades")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Text("\(portfolioSummary.totalTrades)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.top, -30)
    }
}

// MARK: - Other User Tab Content
struct OtherUserContent: View {
    let selectedTab: ProfileTab
    let user: User
    let userTrades: [Trade]
    let postsViewModel: UserPostsViewModel
    let groupsViewModel: UserGroupsViewModel
    
    var body: some View {
        Group {
            switch selectedTab {
            case .posts:
                LazyVStack(spacing: 16) {
                    if postsViewModel.isLoading {
                        ProgressView("Loading posts...")
                            .padding(.top, 40)
                    } else if postsViewModel.posts.isEmpty {
                        EmptyContentView(
                            icon: "text.bubble",
                            title: "No Posts Yet",
                            message: "\(user.fullName) hasn't shared any posts yet."
                        )
                    } else {
                        ForEach(postsViewModel.posts) { post in
                            OtherUserPostCard(post: post)
                        }
                    }
                }
                .padding(.horizontal)
                
            case .trades:
                LazyVStack(spacing: 16) {
                    if userTrades.isEmpty {
                        EmptyContentView(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "No Public Trades",
                            message: "\(user.fullName) hasn't shared any public trades yet."
                        )
                    } else {
                        ForEach(userTrades) { trade in
                            OtherUserTradeCard(trade: trade)
                        }
                    }
                }
                .padding(.horizontal)
                
            case .portfolio:
                VStack(spacing: 20) {
                    EmptyContentView(
                        icon: "lock.fill",
                        title: "Private Portfolio",
                        message: "Full portfolio details are only visible to the account owner."
                    )
                    
                    Text("You can see public trades in the Trades tab")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
            case .groups:
                LazyVStack(spacing: 16) {
                    if groupsViewModel.isLoading {
                        ProgressView("Loading groups...")
                            .padding(.top, 40)
                    } else if groupsViewModel.groups.isEmpty {
                        EmptyContentView(
                            icon: "person.3",
                            title: "No Groups",
                            message: "\(user.fullName) hasn't joined any public groups yet."
                        )
                    } else {
                        ForEach(groupsViewModel.groups) { group in
                            OtherUserGroupCard(group: group)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 100)
    }
}

// MARK: - Empty Content View
struct EmptyContentView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Simple Card Views for Other User Profile

struct OtherUserPostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(post.content)
                .font(.body)
                .foregroundColor(.primary)
            
            HStack {
                Text(post.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Label("\(post.likesCount)", systemImage: "heart")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct OtherUserTradeCard: View {
    let trade: Trade
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(trade.ticker)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(trade.tradeType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Entry: \(trade.entryPrice.asTradingPrice)")
                        .font(.subheadline)
                    
                    if !trade.isOpen, let exitPrice = trade.exitPrice {
                        Text("Exit: \(exitPrice.asTradingPrice)")
                            .font(.subheadline)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(trade.profitLoss.asCurrency)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
                    
                    Text(trade.isOpen ? "Open" : "Closed")
                        .font(.caption)
                        .foregroundColor(trade.isOpen ? .orange : .secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct OtherUserGroupCard: View {
    let group: TradingGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(group.name)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(group.category ?? "General")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(6)
            }
            
            Text(group.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                Text("\(group.memberCount) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if group.isPrivate {
                    Label("Private", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

