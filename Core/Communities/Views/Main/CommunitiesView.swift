//
//  CommunitiesView.swift
//  ArkadTrader
//
//  ENHANCED VERSION - Modern, Professional & Arkad Branded - FIXED
//

import SwiftUI

struct CommunitiesView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var viewModel = CommunitiesViewModel()
    @State private var showCreateCommunity = false
    @State private var selectedTab: CommunityMainTab = .myCommunities
    @State private var showSideMenu = false
    
    // Navigation state
    @State private var selectedCommunity: Community?
    @State private var navigateToCommunity = false
    
    @State private var selectedLeaderboardCommunity: Community?
    @State private var navigateToLeaderboard = false
    
    // ✅ FIXED: Enhanced leaderboard state
    @State private var selectedLeaderboardMode: LeaderboardMode = .communities
    @StateObject private var globalLeaderboardViewModel = GlobalLeaderboardViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium background gradient using Arkad colors
                LinearGradient(
                    colors: [
                        Color.arkadGold.opacity(0.03),
                        Color.backgroundPrimary,
                        Color.arkadGold.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Modern header
                    modernHeaderSection
                    
                    // Main Content
                    contentSection
                }
                
                // Enhanced Side Menu
                if showSideMenu {
                    modernSideMenuOverlay
                }
                
                // Hidden NavigationLink for Leaderboard
                NavigationLink(
                    destination: Group {
                        if let community = selectedLeaderboardCommunity {
                            SimpleConsistencyLeaderboardView(community: community)
                                .environmentObject(authService)
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: $navigateToLeaderboard
                ) {
                    EmptyView()
                }
                .hidden()

                // Hidden NavigationLink for Community Detail
                NavigationLink(
                    destination: Group {
                        if let community = selectedCommunity {
                            CommunityDetailView(community: community)
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: $navigateToCommunity
                ) {
                    EmptyView()
                }
                .hidden()
                
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreateCommunity) {
                CreateCommunityView()
            }
            .onAppear {
                print("🚀 CommunitiesView appeared")
                viewModel.loadInitialData()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Navigation Helper
    private func navigateToCommunitDetail(_ community: Community) {
        print("🚀 Navigating to: \(community.name)")
        selectedCommunity = community
        navigateToCommunity = true
    }
    
    private func navigateToLeaderboard(_ community: Community) {
        print("🏆 Navigating to leaderboard for: \(community.name)")
        selectedLeaderboardCommunity = community
        navigateToLeaderboard = true
    }
    
    private var modernEmptyLeaderboardState: some View {
        VStack(spacing: 32) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.arkadGold.opacity(0.2), Color.arkadGoldLight.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.arkadGold, Color.arkadGoldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            VStack(spacing: 16) {
                Text("Join Communities First")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text("Join trading communities to see leaderboards and compete with other traders.")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Explore Communities") {
                selectedTab = .discover
            }
            .font(.headline)
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGoldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .arkadGold.opacity(0.4), radius: 8, x: 0, y: 4)
            )
        }
        .padding(.top, 60)
        .padding(.bottom, 40)
    }

    private func modernCommunityLeaderboardCard(community: Community) -> some View {
        Button(action: {
            print("🏆 Tapped leaderboard for: \(community.name)")
            navigateToLeaderboard(community)
        }) {
            HStack(spacing: 16) {
                // Community avatar
                Circle()
                    .fill(getCommunityColor(for: community.type))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(getCommunityInitials(from: community.name))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                // Community info
                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(community.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                // Leaderboard preview
                VStack(alignment: .trailing, spacing: 4) {
                    Text("View Rankings")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.arkadGold)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(getCommunityColor(for: community.type).opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Leaderboard Content (FIXED - Single Definition)
extension CommunitiesView {
    
    private var modernLeaderboardContent: some View {
        VStack(spacing: 24) {
            // Header with segmented control
            VStack(spacing: 20) {
                // Title and icon
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.arkadGold, Color.arkadGoldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Leaderboards")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                }
                
                // Segmented Control (matching your home tab style)
                HStack(spacing: 4) {
                    ForEach(LeaderboardMode.allCases, id: \.self) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedLeaderboardMode = mode
                            }
                            
                            // Load data when switching to global
                            if mode == .globalTraders {
                                Task {
                                    await globalLeaderboardViewModel.loadGlobalLeaderboard()
                                }
                            }
                        }) {
                            Text(mode.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(selectedLeaderboardMode == mode ? .arkadBlack : .textSecondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedLeaderboardMode == mode ? Color.arkadGold : Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            // Content based on selected mode
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
        .padding(.top, 8)
    }
    
    // MARK: - Community Leaderboards Content
    private var communityLeaderboardsContent: some View {
        VStack(spacing: 16) {
            // Communities with leaderboards
            LazyVStack(spacing: 16) {
                ForEach(viewModel.userCommunities) { community in
                    modernCommunityLeaderboardCard(community: community)
                }
            }
        }
    }
    
    // MARK: - Global Traders Content (FIXED - Single Definition)
    private var globalTradersContent: some View {
        VStack(spacing: 20) {
            // Header with category selector
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Traders Worldwide")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("Based on \(globalLeaderboardViewModel.selectedCategory.description.lowercased())")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Refresh button
                    Button(action: {
                        Task {
                            await globalLeaderboardViewModel.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.arkadGold)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.arkadGold.opacity(0.1))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
                
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(LeaderboardCategory.allCases, id: \.self) { category in
                            Button(action: {
                                Task {
                                    await globalLeaderboardViewModel.changeCategory(category)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: category.icon)
                                        .font(.caption)
                                    
                                    Text(category.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(globalLeaderboardViewModel.selectedCategory == category ? .arkadBlack : .arkadGold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(globalLeaderboardViewModel.selectedCategory == category ?
                                              Color.arkadGold : Color.arkadGold.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Global traders list
            if globalLeaderboardViewModel.isLoading {
                globalTradersLoadingView
            } else if !globalLeaderboardViewModel.errorMessage.isEmpty {
                globalTradersErrorView
            } else if globalLeaderboardViewModel.globalTraders.isEmpty {
                globalTradersEmptyView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(globalLeaderboardViewModel.globalTraders) { trader in
                        globalTraderCard(trader: trader)
                    }
                }
            }
        }
        .onAppear {
            // Load data when view appears if not already loaded
            if globalLeaderboardViewModel.globalTraders.isEmpty && !globalLeaderboardViewModel.isLoading {
                Task {
                    await globalLeaderboardViewModel.loadGlobalLeaderboard()
                }
            }
        }
    }
    
    // MARK: - Global Trader Card
    private func globalTraderCard(trader: GlobalTrader) -> some View {
        Button(action: {
            // Navigate to user profile
            print("🌍 Tapped global trader: \(trader.username)")
        }) {
            HStack(spacing: 16) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(getRankColor(for: trader.rank))
                        .frame(width: 36, height: 36)
                    
                    if trader.rank <= 3 {
                        Image(systemName: getRankIcon(for: trader.rank))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("#\(trader.rank)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                // User avatar
                AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(trader.username)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.arkadGold)
                        .overlay(
                            Text(getInitials(from: trader.username))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                
                // User info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(trader.username)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                        
                        if trader.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Communities with nice styling
                    if !trader.communities.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(trader.communities.prefix(3)), id: \.self) { community in
                                    Text(community)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.arkadGold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.arkadGold.opacity(0.1))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.arkadGold.opacity(0.3), lineWidth: 0.5)
                                                )
                                        )
                                }
                                
                                if trader.communities.count > 3 {
                                    Text("+\(trader.communities.count - 3)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.textSecondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.gray.opacity(0.1))
                                        )
                                }
                            }
                        }
                    } else {
                        Text("No communities")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Spacer()
                
                // Performance stats
                VStack(alignment: .trailing, spacing: 6) {
                    Text(formatProfitLoss(trader.totalProfitLoss))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(trader.totalProfitLoss >= 0 ? .marketGreen : .marketRed)
                    
                    HStack(spacing: 8) {
                        Text("\(String(format: "%.1f", trader.winRate))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.textSecondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                        
                        Text("\(trader.totalTrades) trades")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                // Follow button (smaller version)
                SimpleFollowButton(
                    targetUserId: trader.userId,
                    targetUsername: trader.username
                )
                .scaleEffect(0.8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.arkadGold.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Loading and Empty States
    private var globalTradersLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .foregroundColor(.arkadGold)
            
            Text("Loading global traders...")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var globalTradersEmptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.arkadGold, Color.arkadGoldLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("No Global Data Yet")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text("Global leaderboards will appear as more traders join communities and complete trades.")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // Add error view
    private var globalTradersErrorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Unable to Load Data")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text(globalLeaderboardViewModel.errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button("Try Again") {
                Task {
                    await globalLeaderboardViewModel.refresh()
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.arkadGold)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Methods
    private func getRankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private func getRankIcon(for rank: Int) -> String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal"
        default: return ""
        }
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[1].prefix(1))
            return (first + last).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
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

// MARK: - Modern Header Section
extension CommunitiesView {
    private var modernHeaderSection: some View {
        VStack(spacing: 0) {
            // Main header with glassmorphism effect
            VStack(spacing: 20) {
                // Top navigation bar
                HStack {
                    // Hamburger menu with modern styling
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu.toggle()
                        }
                    }) {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.arkadGold)
                                .frame(width: 20, height: 2)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.arkadGold)
                                .frame(width: 16, height: 2)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.arkadGold)
                                .frame(width: 18, height: 2)
                        }
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    
                    Spacer()
                    
                    // Modern title with icon
                    HStack(spacing: 12) {
                        Image(systemName: getTabIcon(for: selectedTab))
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.arkadGold, Color.arkadGoldLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(selectedTab.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Modern create button
                    Button(action: {
                        print("➕ Create community button tapped")
                        showCreateCommunity = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.arkadBlack)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.arkadGold, Color.arkadGoldLight],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .arkadGold.opacity(0.4), radius: 8, x: 0, y: 4)
                            )
                    }
                    .scaleEffect(showCreateCommunity ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3), value: showCreateCommunity)
                }
                .padding(.horizontal, 24)
                
                // Enhanced stats row for My Communities
                if !viewModel.userCommunities.isEmpty && selectedTab == .myCommunities {
                    modernStatsRow
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.vertical, 24)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 0)
            )
            .overlay(
                Rectangle()
                    .fill(Color.arkadGold.opacity(0.1))
                    .frame(height: 1),
                alignment: .bottom
            )
        }
    }
    
    private var modernStatsRow: some View {
        HStack(spacing: 16) {
            modernStatCard(
                title: "Joined",
                value: "\(viewModel.userCommunities.count)",
                icon: "person.3.fill",
                gradient: LinearGradient(colors: [.arkadGold, .arkadGoldLight], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            
            modernStatCard(
                title: "Active",
                value: "\(viewModel.activeCommunities)",
                icon: "chart.line.uptrend.xyaxis",
                gradient: LinearGradient(colors: [.marketGreen, .marketGreenLight], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            
            modernStatCard(
                title: "Created",
                value: "\(viewModel.userOwnedCommunities.count)",
                icon: "crown.fill",
                gradient: LinearGradient(colors: [.warning, .arkadGoldLight], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        .padding(.horizontal, 24)
    }
    
    private func modernStatCard(title: String, value: String, icon: String, gradient: LinearGradient) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(gradient)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(gradient.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Modern Side Menu (Keeping existing code)
extension CommunitiesView {
    private var modernSideMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showSideMenu = false
                    }
                }
            
            HStack {
                modernSideMenu
                Spacer()
            }
        }
    }
    
    private var modernSideMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            modernMenuHeader
            
            VStack(spacing: 8) {
                ForEach(CommunityMainTab.allCases, id: \.self) { tab in
                    modernMenuItem(tab)
                }
            }
            .padding(.vertical, 24)
            
            Spacer()
            
            modernCreateButton
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .offset(x: showSideMenu ? 0 : -380)
        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: showSideMenu)
    }
    
    private var modernMenuHeader: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Communities")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Connect & Share")
                        .font(.subheadline)
                        .foregroundColor(.arkadGold)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showSideMenu = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.backgroundSecondary)
                        )
                }
            }
            
            if let user = authService.currentUser {
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.arkadGold, Color.arkadGoldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(user.fullName.prefix(1)))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadBlack)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome back,")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        
                        Text(user.fullName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.arkadGold.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private func modernMenuItem(_ tab: CommunityMainTab) -> some View {
        Button(action: {
            print("📱 Side menu tab tapped: \(tab.displayName)")
            selectedTab = tab
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showSideMenu = false
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: getTabIcon(for: tab))
                    .font(.title3)
                    .foregroundColor(selectedTab == tab ? .arkadBlack : .textSecondary)
                    .frame(width: 28, height: 28)
                
                Text(tab.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedTab == tab ? .arkadBlack : .textPrimary)
                
                Spacer()
                
                if selectedTab == tab {
                    Circle()
                        .fill(Color.arkadGold)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedTab == tab ?
                        AnyShapeStyle(LinearGradient(
                            colors: [Color.arkadGold.opacity(0.15), Color.arkadGoldLight.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )) :
                        AnyShapeStyle(Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedTab == tab ? Color.arkadGold.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var modernCreateButton: some View {
        Button(action: {
            print("➕ Side menu create community tapped")
            showCreateCommunity = true
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showSideMenu = false
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.arkadBlack)
                
                Text("Create Community")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadBlack)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.subheadline)
                    .foregroundColor(.arkadBlack)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGoldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .arkadGold.opacity(0.4), radius: 8, x: 0, y: 4)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}

// MARK: - Content Section (Keeping existing code)
extension CommunitiesView {
    private var contentSection: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                switch selectedTab {
                case .discover:
                    modernDiscoverContent
                case .myCommunities:
                    modernMyCommunitiesContent
                case .leaderboard:
                    if viewModel.userCommunities.isEmpty {
                        modernEmptyLeaderboardState
                    } else {
                        modernLeaderboardContent
                    }
                case .activity:
                    modernComingSoonView(for: "Activity", icon: "clock.fill", description: "Track your community interactions and updates")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }
    
    private func modernComingSoonView(for feature: String, icon: String, description: String) -> some View {
        VStack(spacing: 24) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.arkadGold.opacity(0.2), Color.arkadGoldLight.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.arkadGold, Color.arkadGoldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            VStack(spacing: 12) {
                Text("\(feature) Coming Soon")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.top, 60)
        .padding(.bottom, 40)
    }
}

// MARK: - Modern My Communities Content (All existing code)
extension CommunitiesView {
    private var modernMyCommunitiesContent: some View {
        VStack(spacing: 32) {
            if viewModel.userCommunities.isEmpty {
                modernEmptyMyCommunitiesState
            } else {
                VStack(alignment: .leading, spacing: 40) {
                    if !viewModel.userOwnedCommunities.isEmpty {
                        modernCommunitySection(
                            title: "Communities I Own",
                            icon: "crown.fill",
                            communities: viewModel.userOwnedCommunities,
                            isOwner: true,
                            accentColor: .warning
                        )
                    }
                    
                    if !viewModel.userMemberCommunities.isEmpty {
                        modernCommunitySection(
                            title: "Communities I'm In",
                            icon: "person.3.fill",
                            communities: viewModel.userMemberCommunities,
                            isOwner: false,
                            accentColor: .arkadGold
                        )
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func modernCommunitySection(title: String, icon: String, communities: [Community], isOwner: Bool, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Text("\(communities.count) \(communities.count == 1 ? "community" : "communities")")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 20) {
                ForEach(communities) { community in
                    modernCommunityCard(community: community, isOwner: isOwner)
                }
            }
        }
    }
    
    private func modernCommunityCard(community: Community, isOwner: Bool) -> some View {
        Button(action: {
            print("🏘️ Modern community tapped: \(community.name)")
            navigateToCommunitDetail(community)
        }) {
            VStack(spacing: 16) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [getCommunityColor(for: community.type), getCommunityColor(for: community.type).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(getCommunityInitials(from: community.name))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .shadow(color: getCommunityColor(for: community.type).opacity(0.3), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 8) {
                    Text(community.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.caption2)
                            Text("\(community.memberCount)")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.textSecondary)
                        
                        if isOwner {
                            Text("OWNER")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadBlack)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.arkadGold)
                                )
                        }
                    }
                    
                    Text(community.type.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(getCommunityColor(for: community.type))
                        )
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(getCommunityColor(for: community.type).opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Modern Discover Content (All existing code)
extension CommunitiesView {
    private var modernDiscoverContent: some View {
        VStack(spacing: 32) {
            modernSearchSection
            
            if viewModel.discoveryCommunities.isEmpty {
                modernEmptyDiscoverState
            } else {
                VStack(spacing: 32) {
                    if !viewModel.featuredCommunities.isEmpty {
                        modernFeaturedSection
                    }
                    
                    modernAllCommunitiesSection
                }
            }
        }
        .padding(.top, 8)
    }
    
    private var modernSearchSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGoldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Discover Communities")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                
                TextField("Search communities...", text: .constant(""))
                    .font(.subheadline)
                    .disabled(true)
                
                Button(action: {}) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline)
                        .foregroundColor(.arkadGold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    private var modernFeaturedSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGoldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Featured Communities")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(viewModel.featuredCommunities) { community in
                        modernFeaturedCard(community: community)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func modernFeaturedCard(community: Community) -> some View {
        Button(action: {
            print("⭐ Featured community tapped: \(community.name)")
            navigateToCommunitDetail(community)
        }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Circle()
                        .fill(getCommunityColor(for: community.type))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(getCommunityInitials(from: community.name))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    Spacer()
                    
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.arkadGold)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.arkadGold.opacity(0.15))
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(community.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text(community.description)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                    
                    HStack {
                        Text("\(community.memberCount) members")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                        
                        Spacer()
                        
                        Text(community.type.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(getCommunityColor(for: community.type))
                    }
                }
                
                Spacer()
            }
            .padding(20)
            .frame(width: 220, height: 160)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var modernAllCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGoldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("All Communities")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 20) {
                ForEach(viewModel.discoveryCommunities) { community in
                    modernDiscoveryCard(community: community)
                }
            }
        }
    }
    
    private func modernDiscoveryCard(community: Community) -> some View {
        Button(action: {
            print("🌍 Discovery community tapped: \(community.name)")
            navigateToCommunitDetail(community)
        }) {
            VStack(spacing: 16) {
                Circle()
                    .fill(getCommunityColor(for: community.type))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(getCommunityInitials(from: community.name))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .shadow(color: getCommunityColor(for: community.type).opacity(0.3), radius: 6, x: 0, y: 3)
                
                VStack(spacing: 8) {
                    Text(community.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text("\(community.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    if viewModel.isUserMember(of: community) {
                        Text("MEMBER")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.arkadBlack)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.marketGreen.opacity(0.2))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.marketGreen, lineWidth: 1)
                                    )
                            )
                    } else {
                        Button(action: {
                            print("➕ Join button tapped for: \(community.name)")
                            viewModel.joinCommunity(community)
                        }) {
                            Text("JOIN")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadBlack)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.arkadGold, Color.arkadGoldLight],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(getCommunityColor(for: community.type).opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Modern Empty States
extension CommunitiesView {
    private var modernEmptyMyCommunitiesState: some View {
        VStack(spacing: 32) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.arkadGold.opacity(0.2), Color.arkadGoldLight.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "person.3.circle")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.arkadGold, Color.arkadGoldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            VStack(spacing: 16) {
                Text("No Communities Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text("Join communities to connect with other traders and share insights.")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Explore Communities") {
                print("🔍 Explore Communities button tapped")
                selectedTab = .discover
            }
            .font(.headline)
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGoldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .arkadGold.opacity(0.4), radius: 8, x: 0, y: 4)
            )
        }
        .padding(.top, 60)
        .padding(.bottom, 40)
    }
    
    private var modernEmptyDiscoverState: some View {
        VStack(spacing: 32) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.arkadGold.opacity(0.2), Color.arkadGoldLight.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.arkadGold, Color.arkadGoldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            VStack(spacing: 16) {
                Text("No Communities Available")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text("Be the first to create a community and start connecting with fellow traders!")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Create First Community") {
                print("➕ Create First Community button tapped")
                showCreateCommunity = true
            }
            .font(.headline)
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGoldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .arkadGold.opacity(0.4), radius: 8, x: 0, y: 4)
            )
        }
        .padding(.top, 60)
        .padding(.bottom, 40)
    }
}

// MARK: - Helper Methods
extension CommunitiesView {
    private func getTabIcon(for tab: CommunityMainTab) -> String {
        switch tab {
        case .discover: return "magnifyingglass.circle"
        case .myCommunities: return "person.3.fill"
        case .leaderboard: return "trophy.fill"
        case .activity: return "clock.fill"
        }
    }
    
    private func getCommunityColor(for type: CommunityType) -> Color {
        switch type {
        case .dayTrading: return .marketRed
        case .swingTrading: return .warning
        case .options: return .optionColor
        case .crypto: return .cryptoColor
        case .stocks: return .stockColor
        case .general: return .arkadGold
        }
    }
    
    private func getCommunityInitials(from name: String) -> String {
        let words = name.components(separatedBy: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}

// MARK: - Supporting Types
enum CommunityMainTab: CaseIterable {
    case discover
    case myCommunities
    case leaderboard
    case activity
    
    var displayName: String {
        switch self {
        case .discover: return "Discover"
        case .myCommunities: return "My Communities"
        case .leaderboard: return "Leaderboard"
        case .activity: return "Activity"
        }
    }
}

enum LeaderboardMode: CaseIterable {
    case communities
    case globalTraders
    
    var displayName: String {
        switch self {
        case .communities: return "Communities"
        case .globalTraders: return "Global Traders"
        }
    }
}

struct GlobalTrader: Identifiable {
    let id = UUID()
    let userId: String
    let username: String
    var rank: Int
    let totalProfitLoss: Double
    let winRate: Double
    let totalTrades: Int
    let communities: [String]
    let isVerified: Bool
    
    init(userId: String, username: String, rank: Int, totalProfitLoss: Double, winRate: Double, totalTrades: Int, communities: [String] = [], isVerified: Bool = false) {
        self.userId = userId
        self.username = username
        self.rank = rank
        self.totalProfitLoss = totalProfitLoss
        self.winRate = winRate
        self.totalTrades = totalTrades
        self.communities = communities
        self.isVerified = isVerified
    }
}

// MARK: - Simplified Global Leaderboard ViewModel
@MainActor
class GlobalLeaderboardViewModel: ObservableObject {
    @Published var globalTraders: [GlobalTrader] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var selectedCategory: LeaderboardCategory = .consistencyMasters
    
    private let leaderboardService = CommunityLeaderboardService.shared
    
    func loadGlobalLeaderboard(category: LeaderboardCategory = .consistencyMasters) async {
        print("🌍 Loading simplified global leaderboard for category: \(category)")
        
        isLoading = true
        errorMessage = ""
        selectedCategory = category
        
        do {
            guard let currentUser = leaderboardService.authService.currentUser else {
                throw LeaderboardError.noCurrentUser
            }
            
            print("👤 Current user has \(currentUser.communityIds.count) communities")
            
            var allTraders: [GlobalTrader] = []
            var processedUserIds: Set<String> = []
            
            for communityId in currentUser.communityIds {
                do {
                    print("🏘️ Getting leaderboard for community: \(communityId)")
                    
                    let communityEntries = try await leaderboardService.getLeaderboard(
                        communityId: communityId,
                        category: category,
                        timeframe: .allTime,
                        limit: 50
                    )
                    
                    print("📊 Got \(communityEntries.count) entries from community \(communityId)")
                    
                    for entry in communityEntries {
                        if processedUserIds.contains(entry.userId) {
                            continue
                        }
                        
                        let trader = await createSimpleGlobalTrader(from: entry, communityId: communityId)
                        allTraders.append(trader)
                        processedUserIds.insert(entry.userId)
                    }
                    
                } catch {
                    print("⚠️ Could not load leaderboard for community \(communityId): \(error)")
                }
            }
            
            print("🔄 Processing \(allTraders.count) unique traders")
            
            allTraders = sortTraders(allTraders, by: category)
            
            for i in 0..<allTraders.count {
                allTraders[i].rank = i + 1
            }
            
            globalTraders = Array(allTraders.prefix(50))
            print("✅ Successfully loaded \(globalTraders.count) global traders")
            
        } catch {
            errorMessage = "Failed to load global leaderboard: \(error.localizedDescription)"
            print("❌ Error loading global leaderboard: \(error)")
        }
        
        isLoading = false
    }
    
    private func createSimpleGlobalTrader(from entry: CommunityLeaderboardEntry, communityId: String) async -> GlobalTrader {
        var isVerified = false
        var userCommunities: [String] = []
        
        do {
            if let user = try await leaderboardService.authService.getUserById(userId: entry.userId) {
                isVerified = user.isVerified
                userCommunities = user.communityIds.map { "Community \($0.suffix(8))" }
            }
        } catch {
            print("⚠️ Could not get user details for \(entry.userId): \(error)")
            userCommunities = ["Community \(communityId.suffix(8))"]
        }
        
        if userCommunities.isEmpty {
            userCommunities = ["Community \(communityId.suffix(8))"]
        }
        
        return GlobalTrader(
            userId: entry.userId,
            username: entry.username,
            rank: entry.rank,
            totalProfitLoss: entry.totalProfitLoss,
            winRate: entry.winRate,
            totalTrades: entry.totalTrades,
            communities: userCommunities,
            isVerified: isVerified
        )
    }
    
    private func sortTraders(_ traders: [GlobalTrader], by category: LeaderboardCategory) -> [GlobalTrader] {
        switch category {
        case .consistencyMasters:
            return traders
                .filter { $0.totalTrades >= 5 }
                .sorted { lhs, rhs in
                    if lhs.winRate == rhs.winRate {
                        return lhs.totalTrades > rhs.totalTrades
                    }
                    return lhs.winRate > rhs.winRate
                }
        case .profitKings:
            return traders.sorted { $0.totalProfitLoss > $1.totalProfitLoss }
        case .volumeTraders:
            return traders.sorted { $0.totalTrades > $1.totalTrades }
        case .riskMasters:
            return traders
                .filter { $0.totalTrades >= 3 }
                .sorted { lhs, rhs in
                    let lhsScore = lhs.winRate * 0.7 + Double(min(lhs.totalTrades, 100)) * 0.3
                    let rhsScore = rhs.winRate * 0.7 + Double(min(rhs.totalTrades, 100)) * 0.3
                    return lhsScore > rhsScore
                }
        }
    }
    
    func refresh() async {
        await loadGlobalLeaderboard(category: selectedCategory)
    }
    
    func changeCategory(_ category: LeaderboardCategory) async {
        await loadGlobalLeaderboard(category: category)
    }
}

#Preview {
    CommunitiesView()
        .environmentObject(FirebaseAuthService.shared)
}
