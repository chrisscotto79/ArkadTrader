//
//  CommunitiesView.swift
//  ArkadTrader
//
//  ENHANCED VERSION - Modern, Professional & Clean UI/UX
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
    
    // Enhanced leaderboard state
    @State private var selectedLeaderboardMode: LeaderboardMode = .communities
    @StateObject private var globalLeaderboardViewModel = GlobalLeaderboardViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Subtle background gradient
                LinearGradient(
                    colors: [
                        Color.backgroundPrimary,
                        Color.arkadGold.opacity(0.02),
                        Color.backgroundPrimary
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
                
                // Side Menu Overlay
                if showSideMenu {
                    modernSideMenuOverlay
                }
                
                // Hidden NavigationLinks
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
                viewModel.loadInitialData()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Navigation Helpers
    private func navigateToCommunitDetail(_ community: Community) {
        HapticManager.shared.impact(style: .light)
        selectedCommunity = community
        navigateToCommunity = true
    }
    
    private func navigateToLeaderboard(_ community: Community) {
        HapticManager.shared.impact(style: .light)
        selectedLeaderboardCommunity = community
        navigateToLeaderboard = true
    }
}

// MARK: - Modern Header Section
extension CommunitiesView {
    private var modernHeaderSection: some View {
        VStack(spacing: 0) {
            // Main header
            VStack(spacing: 16) {
                // Top navigation bar
                HStack(spacing: 16) {
                    // Menu button
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showSideMenu.toggle()
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.arkadGold)
                        }
                    }
                    
                    Spacer()
                    
                    // Title
                    Text(selectedTab.displayName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    // Create button
                    Button(action: {
                        showCreateCommunity = true
                        HapticManager.shared.impact(style: .light)
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.arkadGold)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.arkadBlack)
                        }
                        .shadow(color: .arkadGold.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                
                // Stats row for My Communities
                if !viewModel.userCommunities.isEmpty && selectedTab == .myCommunities {
                    cleanStatsRow
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .padding(.vertical, 16)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 0)
            )
        }
    }
    
    private var cleanStatsRow: some View {
        HStack(spacing: 12) {
            statPill(
                value: "\(viewModel.userCommunities.count)",
                label: "Joined",
                color: .arkadGold
            )
            
            statPill(
                value: "\(viewModel.activeCommunities)",
                label: "Active",
                color: .marketGreen
            )
            
            if viewModel.userOwnedCommunities.count > 0 {
                statPill(
                    value: "\(viewModel.userOwnedCommunities.count)",
                    label: "Owned",
                    color: .warning
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func statPill(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule()
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Side Menu
extension CommunitiesView {
    private var modernSideMenuOverlay: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
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
            // Header
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Communities")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.backgroundSecondary)
                            )
                    }
                }
                
                if let user = authService.currentUser {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.arkadGold)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(user.fullName.prefix(1)))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.arkadBlack)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.fullName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                            
                            Text("@\(user.username)")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            }
            .padding(20)
            
            // Menu items
            VStack(spacing: 4) {
                ForEach(CommunityMainTab.allCases, id: \.self) { tab in
                    menuItem(tab)
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // Create button
            Button(action: {
                showCreateCommunity = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showSideMenu = false
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    
                    Text("Create Community")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                }
                .foregroundColor(.arkadBlack)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.arkadGold)
                )
            }
            .padding(16)
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.backgroundPrimary)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 5, y: 0)
        )
        .offset(x: showSideMenu ? 0 : -300)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showSideMenu)
    }
    
    private func menuItem(_ tab: CommunityMainTab) -> some View {
        Button(action: {
            selectedTab = tab
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showSideMenu = false
            }
            HapticManager.shared.impact(style: .light)
        }) {
            HStack(spacing: 12) {
                Image(systemName: getTabIcon(for: tab))
                    .font(.system(size: 18))
                    .foregroundColor(selectedTab == tab ? .arkadGold : .textSecondary)
                    .frame(width: 24)
                
                Text(tab.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(selectedTab == tab ? .textPrimary : .textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedTab == tab ? Color.arkadGold.opacity(0.1) : Color.clear)
            )
        }
    }
}

// MARK: - Content Section
extension CommunitiesView {
    private var contentSection: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                switch selectedTab {
                case .discover:
                    discoverContent
                case .myCommunities:
                    myCommunitiesContent
                case .leaderboard:
                    if viewModel.userCommunities.isEmpty {
                        emptyLeaderboardState
                    } else {
                        leaderboardContent
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }
    
    private func comingSoonView(for feature: String, icon: String, description: String) -> some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.arkadGold.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.arkadGold)
            }
            
            // Text content
            VStack(spacing: 12) {
                Text("\(feature) Coming Soon")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - My Communities Content
extension CommunitiesView {
    private var myCommunitiesContent: some View {
        VStack(spacing: 24) {
            if viewModel.userCommunities.isEmpty {
                emptyMyCommunitiesState
            } else {
                VStack(spacing: 32) {
                    if !viewModel.userOwnedCommunities.isEmpty {
                        communitySection(
                            title: "Communities I Own",
                            communities: viewModel.userOwnedCommunities,
                            isOwner: true
                        )
                    }
                    
                    if !viewModel.userMemberCommunities.isEmpty {
                        communitySection(
                            title: "Communities I'm In",
                            communities: viewModel.userMemberCommunities,
                            isOwner: false
                        )
                    }
                }
            }
        }
    }
    
    private func communitySection(title: String, communities: [Community], isOwner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text("\(communities.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.arkadGold.opacity(0.1))
                    )
                
                Spacer()
            }
            
            // Community cards
            LazyVStack(spacing: 12) {
                ForEach(communities) { community in
                    communityCard(community: community, isOwner: isOwner)
                }
            }
        }
    }
    
    private func communityCard(community: Community, isOwner: Bool) -> some View {
        Button(action: {
            navigateToCommunitDetail(community)
        }) {
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(getCommunityColor(for: community.type).gradient)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(getCommunityInitials(from: community.name))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Label("\(community.memberCount)", systemImage: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                        
                        if isOwner {
                            Label("Owner", systemImage: "crown.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.arkadGold)
                        }
                    }
                }
                
                Spacer()
                
                // Type badge
                Text(community.type.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(getCommunityColor(for: community.type))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(getCommunityColor(for: community.type).opacity(0.1))
                    )
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.borderPrimary, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Discover Content
extension CommunitiesView {
    private var discoverContent: some View {
        VStack(spacing: 24) {
            searchBar
            
            if viewModel.discoveryCommunities.isEmpty {
                emptyDiscoverState
            } else {
                VStack(spacing: 32) {
                    if !viewModel.featuredCommunities.isEmpty {
                        featuredSection
                    }
                    
                    allCommunitiesSection
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)
            
            TextField("Search communities...", text: .constant(""))
                .font(.system(size: 16))
                .disabled(true)
            
            Button(action: {}) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundColor(.arkadGold)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.borderPrimary, lineWidth: 1)
                )
        )
    }
    
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Featured", systemImage: "star.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.featuredCommunities) { community in
                        featuredCard(community: community)
                    }
                }
            }
        }
    }
    
    private func featuredCard(community: Community) -> some View {
        Button(action: {
            navigateToCommunitDetail(community)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Circle()
                        .fill(getCommunityColor(for: community.type).gradient)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(getCommunityInitials(from: community.name))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )
                    
                    Spacer()
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.arkadGold)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(community.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text(community.description)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Footer
                HStack {
                    Label("\(community.memberCount)", systemImage: "person.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    Text(community.type.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(getCommunityColor(for: community.type))
                }
            }
            .padding(16)
            .frame(width: 200, height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.arkadGold.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var allCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("All Communities", systemImage: "globe")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.textPrimary)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.discoveryCommunities) { community in
                    discoveryCard(community: community)
                }
            }
        }
    }
    
    private func discoveryCard(community: Community) -> some View {
        Button(action: {
            navigateToCommunitDetail(community)
        }) {
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(getCommunityColor(for: community.type).gradient)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(getCommunityInitials(from: community.name))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Label("\(community.memberCount) members", systemImage: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                // Action button
                if viewModel.isUserMember(of: community) {
                    Label("Member", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.marketGreen)
                } else {
                    Button(action: {
                        viewModel.joinCommunity(community)
                        HapticManager.shared.notification(type: .success)
                    }) {
                        Text("Join")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.arkadBlack)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.arkadGold)
                            )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.borderPrimary, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Leaderboard Content
extension CommunitiesView {
    private var leaderboardContent: some View {
        VStack(spacing: 20) {
            // Segmented Control
            HStack(spacing: 4) {
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
                        Text(mode.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedLeaderboardMode == mode ? .arkadBlack : .textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedLeaderboardMode == mode ? Color.arkadGold : Color.clear)
                            )
                    }
                }
                
                Spacer()
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.borderPrimary, lineWidth: 1)
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
    
    private var communityLeaderboardsContent: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.userCommunities) { community in
                communityLeaderboardCard(community: community)
            }
        }
    }
    
    private func communityLeaderboardCard(community: Community) -> some View {
        Button(action: {
            navigateToLeaderboard(community)
        }) {
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(getCommunityColor(for: community.type).gradient)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(getCommunityInitials(from: community.name))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(community.memberCount) members")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                // Action
                Label("View Rankings", systemImage: "chart.bar.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.arkadGold)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.borderPrimary, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var globalTradersContent: some View {
        VStack(spacing: 16) {
            // Header with category selector
            VStack(spacing: 12) {
                HStack {
                    Text("Top Traders Worldwide")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await globalLeaderboardViewModel.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.arkadGold)
                    }
                }
                
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LeaderboardCategory.allCases, id: \.self) { category in
                            categoryChip(category)
                        }
                    }
                }
            }
            
            // Content
            if globalLeaderboardViewModel.isLoading {
                loadingView
            } else if !globalLeaderboardViewModel.errorMessage.isEmpty {
                errorView
            } else if globalLeaderboardViewModel.globalTraders.isEmpty {
                emptyGlobalTradersView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(globalLeaderboardViewModel.globalTraders) { trader in
                        globalTraderCard(trader: trader)
                    }
                }
            }
        }
        .onAppear {
            if globalLeaderboardViewModel.globalTraders.isEmpty && !globalLeaderboardViewModel.isLoading {
                Task {
                    await globalLeaderboardViewModel.loadGlobalLeaderboard()
                }
            }
        }
    }
    
    private func categoryChip(_ category: LeaderboardCategory) -> some View {
        Button(action: {
            Task {
                await globalLeaderboardViewModel.changeCategory(category)
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(globalLeaderboardViewModel.selectedCategory == category ? .arkadBlack : .arkadGold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(globalLeaderboardViewModel.selectedCategory == category ?
                          Color.arkadGold : Color.arkadGold.opacity(0.1))
            )
        }
    }
    
    private func globalTraderCard(trader: GlobalTrader) -> some View {
        HStack(spacing: 12) {
            // Rank
            rankBadge(for: trader.rank)
            
            // Avatar
            AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(trader.username)")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.arkadGold.gradient)
                    .overlay(
                        Text(getInitials(from: trader.username))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(trader.username)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    if trader.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                }
                
                HStack(spacing: 8) {
                    Text("\(trader.totalTrades) trades")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                    
                    Text("\(String(format: "%.1f", trader.winRate))% win")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatProfitLoss(trader.totalProfitLoss))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(trader.totalProfitLoss >= 0 ? .marketGreen : .marketRed)
                
                SimpleFollowButton(
                    targetUserId: trader.userId,
                    targetUsername: trader.username
                )
                .scaleEffect(0.8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.borderPrimary, lineWidth: 1)
                )
        )
    }
    
    private func rankBadge(for rank: Int) -> some View {
        ZStack {
            Circle()
                .fill(getRankColor(for: rank).gradient)
                .frame(width: 28, height: 28)
            
            if rank <= 3 {
                Image(systemName: getRankIcon(for: rank))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Empty States
extension CommunitiesView {
    private var emptyMyCommunitiesState: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3.circle")
                .font(.system(size: 48))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Communities Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text("Join communities to connect with other traders")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Explore Communities") {
                selectedTab = .discover
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.arkadGold)
            )
        }
        .padding(.top, 60)
    }
    
    private var emptyDiscoverState: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Communities Available")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text("Be the first to create a community!")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
            
            Button("Create Community") {
                showCreateCommunity = true
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.arkadGold)
            )
        }
        .padding(.top, 60)
    }
    
    private var emptyLeaderboardState: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.circle")
                .font(.system(size: 48))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("Join Communities First")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text("Join communities to see leaderboards")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Explore Communities") {
                selectedTab = .discover
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.arkadGold)
            )
        }
        .padding(.top, 60)
    }
    
    private var emptyGlobalTradersView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 32))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            Text("No Global Data Yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
            
            Text("Global leaderboards will appear as more traders join")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.borderPrimary, lineWidth: 1)
                )
        )
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .arkadGold))
            
            Text("Loading global traders...")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.borderPrimary, lineWidth: 1)
                )
        )
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text("Unable to Load Data")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
            
            Text(globalLeaderboardViewModel.errorMessage)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await globalLeaderboardViewModel.refresh()
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.arkadBlack)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.arkadGold)
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Helper Methods
extension CommunitiesView {
    private func getTabIcon(for tab: CommunityMainTab) -> String {
        switch tab {
        case .discover: return "magnifyingglass"
        case .myCommunities: return "person.3"
        case .leaderboard: return "trophy"
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
}

// MARK: - Custom Button Styles


// MARK: - Haptic Manager Extension
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - Supporting Types (Keep existing)
enum CommunityMainTab: CaseIterable {
    case discover
    case myCommunities
    case leaderboard
    
    
    var displayName: String {
        switch self {
        case .discover: return "Discover"
        case .myCommunities: return "My Communities"
        case .leaderboard: return "Leaderboard"
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

// MARK: - Global Leaderboard ViewModel (Keep existing)
@MainActor
class GlobalLeaderboardViewModel: ObservableObject {
    @Published var globalTraders: [GlobalTrader] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var selectedCategory: LeaderboardCategory = .consistencyMasters
    
    private let leaderboardService = CommunityLeaderboardService.shared
    
    func loadGlobalLeaderboard(category: LeaderboardCategory = .consistencyMasters) async {
        isLoading = true
        errorMessage = ""
        selectedCategory = category
        
        do {
            guard let currentUser = leaderboardService.authService.currentUser else {
                throw LeaderboardError.noCurrentUser
            }
            
            var allTraders: [GlobalTrader] = []
            var processedUserIds: Set<String> = []
            
            for communityId in currentUser.communityIds {
                do {
                    let communityEntries = try await leaderboardService.getLeaderboard(
                        communityId: communityId,
                        category: category,
                        timeframe: .allTime,
                        limit: 50
                    )
                    
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
            
            allTraders = sortTraders(allTraders, by: category)
            
            for i in 0..<allTraders.count {
                allTraders[i].rank = i + 1
            }
            
            globalTraders = Array(allTraders.prefix(50))
            
        } catch {
            errorMessage = "Failed to load global leaderboard"
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
