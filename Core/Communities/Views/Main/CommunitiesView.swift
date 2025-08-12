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
    
    @State private var selectedCommunityForPreview: Community?
    @State private var showCommunityPreview = false
    @State private var showFilterSheet = false
    
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
                // Enhanced background with mesh gradient effect
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.backgroundPrimary,
                            Color.arkadGold.opacity(0.05),
                            Color.backgroundPrimary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Floating orbs for depth
                    GeometryReader { geometry in
                        Circle()
                            .fill(Color.arkadGold.opacity(0.03))
                            .frame(width: 300, height: 300)
                            .blur(radius: 100)
                            .offset(x: -100, y: -100)
                        
                        Circle()
                            .fill(Color.blue.opacity(0.03))
                            .frame(width: 250, height: 250)
                            .blur(radius: 80)
                            .offset(x: geometry.size.width - 100, y: geometry.size.height - 200)
                    }
                }
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
            .sheet(isPresented: $showCommunityPreview) {
                if let community = selectedCommunityForPreview {
                    CommunityPreviewSheet(
                        community: community,
                        isUserMember: viewModel.isUserMember(of: community),
                        onJoin: {
                            viewModel.joinCommunity(community)
                            HapticManager.shared.notification(type: .success)
                        },
                        onEnterCommunity: {
                            // Navigate to full community detail
                            selectedCommunityForPreview = nil
                            showCommunityPreview = false
                            navigateToCommunitDetail(community)
                        },
                        onClose: {
                            selectedCommunityForPreview = nil
                            showCommunityPreview = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                CommunityFilterSheet(viewModel: viewModel)
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
            // Main header with frosted glass effect
            VStack(spacing: 20) {
                // Top navigation bar
                HStack(spacing: 20) {
                    // Menu button with animation
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showSideMenu.toggle()
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.arkadGold.opacity(0.3), Color.arkadGold.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                            
                            Image(systemName: showSideMenu ? "xmark" : "line.3.horizontal")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.arkadGold)
                                .rotationEffect(.degrees(showSideMenu ? 90 : 0))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSideMenu)
                        }
                        .shadow(color: .arkadGold.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    
                    Spacer()
                    
                    // Animated title
                    VStack(spacing: 4) {
                        Text(selectedTab.displayName)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.textPrimary, Color.textPrimary.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        // Subtitle
                        Text(getSubtitle())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Create button with pulse animation
                    Button(action: {
                        showCreateCommunity = true
                        HapticManager.shared.impact(style: .light)
                    }) {
                        ZStack {
                            // Background pulse
                            Circle()
                                .fill(Color.arkadGold.opacity(0.2))
                                .frame(width: 52, height: 52)
                                .scaleEffect(1.2)
                                .opacity(0.5)
                                .animation(
                                    Animation.easeInOut(duration: 2)
                                        .repeatForever(autoreverses: true),
                                    value: showCreateCommunity
                                )
                            
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.arkadGold, Color.arkadGold.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.arkadBlack)
                        }
                        .shadow(color: .arkadGold.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                }
                .padding(.horizontal, 24)
                
                // Enhanced stats row
                if !viewModel.userCommunities.isEmpty && selectedTab == .myCommunities {
                    cleanStatsRow
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
            .padding(.vertical, 20)
            .background(
                ZStack {
                    // Frosted glass background
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
                    // Top gradient overlay
                    LinearGradient(
                        colors: [Color.arkadGold.opacity(0.05), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .overlay(
                // Bottom border
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.borderPrimary.opacity(0.3), Color.borderPrimary.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1),
                alignment: .bottom
            )
        }
    }
    
    private var cleanStatsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                statPill(
                    value: "\(viewModel.userCommunities.count)",
                    label: "Joined",
                    color: .arkadGold,
                    icon: "person.3.fill"
                )
                
                statPill(
                    value: "\(viewModel.activeCommunities)",
                    label: "Active",
                    color: .marketGreen,
                    icon: "bolt.fill"
                )
                
                if viewModel.userOwnedCommunities.count > 0 {
                    statPill(
                        value: "\(viewModel.userOwnedCommunities.count)",
                        label: "Owned",
                        color: .purple,
                        icon: "crown.fill"
                    )
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func statPill(value: String, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            // Icon container
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [color.opacity(0.4), color.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func getSubtitle() -> String {
        switch selectedTab {
        case .discover:
            return "Find new communities"
        case .myCommunities:
            return "Your trading groups"
        case .leaderboard:
            return "Top performers"
        }
    }
}

// MARK: - Side Menu
extension CommunitiesView {
    private var modernSideMenuOverlay: some View {
        ZStack {
            // Animated backdrop
            Color.black
                .opacity(showSideMenu ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showSideMenu = false
                    }
                }
                .animation(.easeOut(duration: 0.3), value: showSideMenu)
            
            HStack {
                modernSideMenu
                Spacer()
            }
        }
    }
    
    private var modernSideMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Enhanced header
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Communities")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.textPrimary, Color.arkadGold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Connect & Trade Together")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.backgroundSecondary)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.borderPrimary, lineWidth: 1)
                                )
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                
                // Enhanced user profile
                if let user = authService.currentUser {
                    HStack(spacing: 14) {
                        // Avatar with gradient border
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.arkadGold, Color.arkadGold.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 48, height: 48)
                            
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.arkadGold, Color.arkadGold.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(String(user.fullName.prefix(1)))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.arkadBlack)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.fullName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "at")
                                    .font(.system(size: 10))
                                    .foregroundColor(.arkadGold)
                                
                                Text(user.username)
                                    .font(.system(size: 13))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.backgroundSecondary.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.borderPrimary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(24)
            
            // Divider
            Rectangle()
                .fill(Color.borderPrimary.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            // Enhanced menu items
            VStack(spacing: 6) {
                ForEach(CommunityMainTab.allCases, id: \.self) { tab in
                    menuItem(tab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            
            Spacer()
            
            // Enhanced create button
            Button(action: {
                showCreateCommunity = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showSideMenu = false
                }
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.arkadBlack)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.arkadGold)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create Community")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Start your own group")
                            .font(.system(size: 12))
                            .opacity(0.8)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                        .opacity(0.6)
                }
                .foregroundColor(.arkadBlack)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.arkadGold, Color.arkadGold.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: .arkadGold.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(20)
        }
        .frame(width: 320)
        .background(
            ZStack {
                // Background with blur
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.backgroundPrimary)
                
                // Gradient overlay
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold.opacity(0.05), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .black.opacity(0.2), radius: 30, x: 10, y: 0)
        )
        .offset(x: showSideMenu ? 0 : -340)
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
            HStack(spacing: 14) {
                // Icon with background
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedTab == tab ? Color.arkadGold.opacity(0.15) : Color.clear)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: getTabIcon(for: tab))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(selectedTab == tab ? .arkadGold : .textSecondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? .textPrimary : .textSecondary)
                    
                    Text(getTabDescription(for: tab))
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                }
                
                Spacer()
                
                if selectedTab == tab {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.arkadGold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selectedTab == tab ? Color.arkadGold.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                selectedTab == tab ? Color.arkadGold.opacity(0.2) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getTabDescription(for tab: CommunityMainTab) -> String {
        switch tab {
        case .discover:
            return "Browse all groups"
        case .myCommunities:
            return "Your joined groups"
        case .leaderboard:
            return "Rankings & stats"
        }
    }
}

// MARK: - Content Section
extension CommunitiesView {
    private var contentSection: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 24) {
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
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }
    
    private func comingSoonView(for feature: String, icon: String, description: String) -> some View {
        VStack(spacing: 28) {
            // Enhanced icon with animation
            ZStack {
                // Animated rings
                ForEach(0..<3) { index in
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.arkadGold.opacity(0.3 - Double(index) * 0.1), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: CGFloat(100 + index * 30), height: CGFloat(100 + index * 30))
                        .scaleEffect(1.0)
                        .opacity(0.5)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                            value: feature
                        )
                }
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold.opacity(0.15), Color.arkadGold.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Text content
            VStack(spacing: 14) {
                Text("\(feature) Coming Soon")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .lineSpacing(4)
            }
        }
        .padding(.top, 80)
    }
}

// MARK: - My Communities Content
extension CommunitiesView {
    private var myCommunitiesContent: some View {
        VStack(spacing: 28) {
            if viewModel.userCommunities.isEmpty {
                emptyMyCommunitiesState
            } else {
                VStack(spacing: 36) {
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
        VStack(alignment: .leading, spacing: 18) {
            // Enhanced section header
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                // Count badge
                Text("\(communities.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.arkadGold)
                    .frame(minWidth: 24)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.arkadGold.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.arkadGold.opacity(0.3), lineWidth: 1)
                            )
                    )
                
                Spacer()
                
                if isOwner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.arkadGold)
                        .opacity(0.6)
                }
            }
            
            // Community cards with enhanced design
            LazyVStack(spacing: 14) {
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
            HStack(spacing: 18) {
                // Enhanced avatar with gradient
                ZStack {
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
                        .frame(width: 54, height: 54)
                        .shadow(color: getCommunityColor(for: community.type).opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Text(getCommunityInitials(from: community.name))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Enhanced info section
                VStack(alignment: .leading, spacing: 6) {
                    Text(community.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 14) {
                        // Members with icon
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.textSecondary)
                            
                            Text("\(community.memberCount)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                        
                        if isOwner {
                            // Owner badge
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 11))
                                
                                Text("Owner")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.arkadGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.arkadGold.opacity(0.1))
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Enhanced type badge and chevron
                HStack(spacing: 12) {
                    Text(community.type.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(getCommunityColor(for: community.type))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(getCommunityColor(for: community.type).opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            getCommunityColor(for: community.type).opacity(0.3),
                                            lineWidth: 1
                                        )
                                )
                        )
                    
                    // Animated chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textTertiary)
                        .opacity(0.6)
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
                                    colors: [Color.borderPrimary.opacity(0.3), Color.borderPrimary.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Discover Content
extension CommunitiesView {
    private var discoverContent: some View {
        VStack(spacing: 28) {
            searchBar
            
            if viewModel.discoveryCommunities.isEmpty && !viewModel.isLoading {
                emptyDiscoverState
            } else {
                VStack(spacing: 36) {
                    // Featured Section (mixed types)
                    if !viewModel.featuredCommunities.isEmpty {
                        featuredCommunitiesSection
                    }
                    
                    // Type-Based Sections
                    communityTypesSections
                }
            }
        }
    }
    
    // MARK: - Featured Communities Section
    private var featuredCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "Featured",
                icon: "star.fill",
                iconColor: .arkadGold,
                count: viewModel.featuredCommunities.count,
                showSeeAll: true
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(viewModel.featuredCommunities) { community in
                        EnhancedCommunityCard(
                            community: community,
                            style: .featured(),
                            isUserMember: viewModel.isUserMember(of: community),
                            onTap: {
                                navigateToCommunitDetail(community)
                            },
                            onJoin: {
                                viewModel.joinCommunity(community)
                                HapticManager.shared.notification(type: .success)
                            },
                            onInfo: {
                                showCommunityPreview(community)
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Community Types Sections
    private var communityTypesSections: some View {
        VStack(spacing: 32) {
            ForEach(viewModel.allCommunityTypesInOrder, id: \.self) { type in
                communityTypeSection(for: type)
            }
        }
    }
    
    private func communityTypeSection(for type: CommunityType) -> some View {
        let communities = viewModel.communitiesForType(type)
        let hasContent = !communities.isEmpty
        
        return VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: viewModel.sectionTitle(for: type),
                icon: viewModel.sectionIcon(for: type),
                iconColor: getSectionColor(for: type),
                count: communities.count,
                showSeeAll: false
            )
            
            if hasContent {
                // Grid layout for regular cards
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    spacing: 18
                ) {
                    ForEach(communities) { community in
                        EnhancedCommunityCard(
                            community: community,
                            style: .regular(),
                            isUserMember: viewModel.isUserMember(of: community),
                            onTap: {
                                navigateToCommunitDetail(community)
                            },
                            onJoin: {
                                viewModel.joinCommunity(community)
                                HapticManager.shared.notification(type: .success)
                            },
                            onInfo: {
                                showCommunityPreview(community)
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            } else {
                // Empty state for this type
                emptyCommunityTypeState(for: type)
            }
        }
    }
    
    // MARK: - Section Header
    private func sectionHeader(
        title: String,
        icon: String,
        iconColor: Color,
        count: Int,
        showSeeAll: Bool = false
    ) -> some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    if count > 0 {
                        Text("\(count) \(count == 1 ? "community" : "communities")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Count badge
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(iconColor)
                    .frame(minWidth: 28)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(iconColor.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .strokeBorder(iconColor.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            // See all button (only for featured)
            if showSeeAll {
                Button(action: {
                    // TODO: Navigate to see all featured communities
                }) {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(.system(size: 14, weight: .medium))
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.arkadGold)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Empty States
    private var emptyDiscoverState: some View {
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
                
                Image(systemName: "magnifyingglass.circle.fill")
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
                Text("No Communities Available")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("Be the first to create a community!")
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
            }
            
            Button("Create Community") {
                showCreateCommunity = true
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
    
    private func emptyCommunityTypeState(for type: CommunityType) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.sectionIcon(for: type))
                    .font(.system(size: 24))
                    .foregroundColor(getSectionColor(for: type).opacity(0.4))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("No \(type.shortDisplayName) communities yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Text("Be the first to create a \(type.displayName.lowercased()) community!")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Button("Create") {
                    showCreateCommunity = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.arkadBlack)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(getSectionColor(for: type).opacity(0.2))
                )
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.backgroundSecondary.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                getSectionColor(for: type).opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Helper Methods
    private func getSectionColor(for type: CommunityType) -> Color {
        switch type {
        case .dayTrading: return .marketRed
        case .swingTrading: return .warning
        case .options: return .optionColor
        case .crypto: return .cryptoColor
        case .stocks: return .stockColor
        case .general: return .arkadGold
        }
    }
    
    private func showCommunityPreview(_ community: Community) {
        selectedCommunityForPreview = community
        showCommunityPreview = true
    }
}

// MARK: - Working Search Bar and Filter
extension CommunitiesView {
    private var searchBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textSecondary)
                
                TextField("Search communities...", text: $viewModel.searchQuery)
                    .font(.system(size: 16))
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        // Trigger search when user presses return
                        Task {
                            await viewModel.searchCommunities(query: viewModel.searchQuery)
                        }
                    }
                
                Spacer()
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                        Task {
                            await viewModel.loadDiscoveryCommunities()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                viewModel.searchQuery.isEmpty ?
                                    Color.borderPrimary.opacity(0.3) :
                                    Color.arkadGold.opacity(0.5),
                                lineWidth: 1
                            )
                    )
            )
            
            // Working Filter button
            Button(action: {
                showFilterSheet = true
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(hasActiveFilters ? Color.arkadGold.opacity(0.15) : Color.arkadGold.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    hasActiveFilters ? Color.arkadGold.opacity(0.6) : Color.arkadGold.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                    
                    ZStack {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.arkadGold)
                        
                        // Active filter indicator
                        if hasActiveFilters {
                            Circle()
                                .fill(Color.arkadGold)
                                .frame(width: 8, height: 8)
                                .offset(x: 12, y: -12)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // Check if any filters are active
    private var hasActiveFilters: Bool {
        viewModel.selectedCategory != nil ||
        !viewModel.showPrivateCommunities ||
        viewModel.sortType != .memberCount

    }
}

// MARK: - Leaderboard Content
extension CommunitiesView {
    private var leaderboardContent: some View {
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
    
    private var communityLeaderboardsContent: some View {
        LazyVStack(spacing: 14) {
            ForEach(viewModel.userCommunities) { community in
                communityLeaderboardCard(community: community)
            }
        }
    }
    
    private func communityLeaderboardCard(community: Community) -> some View {
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
    
    private var globalTradersContent: some View {
        VStack(spacing: 20) {
            // Enhanced header with category selector
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Traders Worldwide")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Text("Global rankings across all communities")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await globalLeaderboardViewModel.refresh()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.arkadGold.opacity(0.1))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.arkadGold)
                        }
                    }
                }
                
                // Enhanced category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
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
                LazyVStack(spacing: 14) {
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
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 13, weight: .medium))
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(globalLeaderboardViewModel.selectedCategory == category ? .arkadBlack : .arkadGold)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(globalLeaderboardViewModel.selectedCategory == category ?
                          LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGold.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                          ) : LinearGradient(
                            colors: [Color.arkadGold.opacity(0.1), Color.arkadGold.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                          ))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                globalLeaderboardViewModel.selectedCategory == category ?
                                Color.clear : Color.arkadGold.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: globalLeaderboardViewModel.selectedCategory == category ?
                    .arkadGold.opacity(0.2) : .clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
    }
    
    private func globalTraderCard(trader: GlobalTrader) -> some View {
        HStack(spacing: 14) {
            // Enhanced rank badge
            rankBadge(for: trader.rank)
            
            // Avatar with gradient border
            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: trader.rank <= 3 ?
                                [getRankColor(for: trader.rank), getRankColor(for: trader.rank).opacity(0.5)] :
                                [Color.borderPrimary, Color.borderPrimary.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 44, height: 44)
                
                AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(trader.username)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.arkadGold, Color.arkadGold.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(getInitials(from: trader.username))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            }
            
            // User info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(trader.username)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    if trader.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10))
                        Text("\(trader.totalTrades)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.textSecondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(trader.winRate >= 60 ? Color.marketGreen : Color.textSecondary)
                            .frame(width: 4, height: 4)
                        Text("\(String(format: "%.1f", trader.winRate))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(trader.winRate >= 60 ? .marketGreen : .textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 6) {
                Text(formatProfitLoss(trader.totalProfitLoss))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: trader.totalProfitLoss >= 0 ?
                                [Color.marketGreen, Color.marketGreen.opacity(0.8)] :
                                [Color.marketRed, Color.marketRed.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                SimpleFollowButton(
                    targetUserId: trader.userId,
                    targetUsername: trader.username
                )
                .scaleEffect(0.85)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(trader.rank <= 3 ? Color.backgroundSecondary : Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            trader.rank <= 3 ?
                                LinearGradient(
                                    colors: [getRankColor(for: trader.rank).opacity(0.3), getRankColor(for: trader.rank).opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.borderPrimary.opacity(0.3), Color.borderPrimary.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: trader.rank <= 3 ? getRankColor(for: trader.rank).opacity(0.1) : .black.opacity(0.03),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
    
    private func rankBadge(for rank: Int) -> some View {
        ZStack {
            if rank <= 3 {
                // Special design for top 3
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [getRankColor(for: rank), getRankColor(for: rank).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: getRankColor(for: rank).opacity(0.4), radius: 4, x: 0, y: 2)
                
                Image(systemName: getRankIcon(for: rank))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            } else {
                // Regular rank badge
                Circle()
                    .fill(Color.backgroundSecondary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.borderPrimary, lineWidth: 1)
                    )
                
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
            }
        }
    }
}

// MARK: - Empty States (Enhanced)
extension CommunitiesView {
    private var emptyMyCommunitiesState: some View {
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
    
    private var emptyLeaderboardState: some View {
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
    
    private var emptyGlobalTradersView: some View {
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
    
    private var loadingView: some View {
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
    
    private var errorView: some View {
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

// MARK: - Filter Sheet
struct CommunityFilterSheet: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempSelectedCategory: CommunityType?
    @State private var tempShowPrivate: Bool = true
    @State private var tempSortType: CommunitySortType = .memberCount
    @State private var tempMinMembers: Double = 0
    @State private var tempActivityFilter: ActivityLevel?
    
    var body: some View {
        NavigationView {
            Form {
                // Category Filter Section
                Section("Community Type") {
                    Picker("Category", selection: $tempSelectedCategory) {
                        Text("All Types").tag(CommunityType?.none)
                        ForEach(CommunityType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: getTypeIcon(for: type))
                                Text(type.displayName)
                            }
                            .tag(type as CommunityType?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Privacy Filter Section
                Section("Privacy") {
                    Toggle("Include Private Communities", isOn: $tempShowPrivate)
                }
                
                // Member Count Filter Section
                Section("Minimum Members") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("At least \(Int(tempMinMembers)) members")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        Slider(value: $tempMinMembers, in: 0...1000, step: 10) {
                            Text("Member Count")
                        }
                        .accentColor(.arkadGold)
                    }
                }
                
                // Activity Filter Section
                Section("Activity Level") {
                    Picker("Activity", selection: $tempActivityFilter) {
                        Text("Any Activity Level").tag(ActivityLevel?.none)
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            HStack {
                                Circle()
                                    .fill(getActivityColor(for: level))
                                    .frame(width: 8, height: 8)
                                Text(level.displayName)
                            }
                            .tag(level as ActivityLevel?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Sort Options Section
                Section("Sort By") {
                    Picker("Sort", selection: $tempSortType) {
                        ForEach(CommunitySortType.allCases, id: \.self) { sortType in
                            HStack {
                                Image(systemName: getSortIcon(for: sortType))
                                Text(sortType.displayName)
                            }
                            .tag(sortType)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Reset Section
                Section {
                    Button("Reset All Filters") {
                        resetFilters()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Filter Communities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCurrentFilters()
        }
    }
    
    private func loadCurrentFilters() {
        tempSelectedCategory = viewModel.selectedCategory
        tempShowPrivate = viewModel.showPrivateCommunities
        tempSortType = viewModel.sortType
        // Add other filters as needed
    }
    
    private func applyFilters() {
        viewModel.selectedCategory = tempSelectedCategory
        viewModel.showPrivateCommunities = tempShowPrivate
        viewModel.sortType = tempSortType
        
        // Apply other filters
        Task {
            await viewModel.loadDiscoveryCommunities()
        }
    }
    
    private func resetFilters() {
        tempSelectedCategory = nil
        tempShowPrivate = true
        tempSortType = .memberCount
        tempMinMembers = 0
        tempActivityFilter = nil
    }
    
    private func getTypeIcon(for type: CommunityType) -> String {
        switch type {
        case .general: return "person.3"
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "chart.bar"
        case .options: return "option"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        }
    }
    
    private func getActivityColor(for level: ActivityLevel) -> Color {
        switch level {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .green
        }
    }
    
    private func getSortIcon(for sortType: CommunitySortType) -> String {
        switch sortType {
        case .memberCount: return "person.3"
        case .newest: return "clock"
        case .alphabetical: return "textformat.abc"
        case .mostActive:
                return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - CommunitySortType enum


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

// MARK: - Supporting Types
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

// MARK: - Global Leaderboard ViewModel
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
