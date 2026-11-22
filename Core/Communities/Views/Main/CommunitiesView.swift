// File: Core/Communities/Views/Main/CommunitiesView.swift
// The Communities tab: header, side menu and tab switching. Each tab's content is in a CommunitiesView+*.swift file.

import SwiftUI

struct CommunitiesView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject var viewModel = CommunitiesViewModel()
    @State var showCreateCommunity = false
    @State var selectedTab: CommunityMainTab = .myCommunities
    @State var showSideMenu = false
    
    @State var selectedCommunityForPreview: Community?
    @State var showCommunityPreview = false
    @State var showFilterSheet = false
    
    // Navigation state
    @State var selectedCommunity: Community?
    @State var navigateToCommunity = false
    
    @State var selectedLeaderboardCommunity: Community?
    @State var navigateToLeaderboard = false
    
    // Enhanced leaderboard state
    @State var selectedLeaderboardMode: LeaderboardMode = .communities
    @StateObject var globalLeaderboardViewModel = GlobalLeaderboardViewModel()
    @State var globalProfileUser: User?
    
    var body: some View {
        NavigationStack {
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
                
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToLeaderboard) {
                if let community = selectedLeaderboardCommunity {
                    CommunityLeaderboardView(community: community)
                        .environmentObject(authService)
                }
            }
            .navigationDestination(isPresented: $navigateToCommunity) {
                if let community = selectedCommunity {
                    CommunityDetailView(community: community)
                }
            }
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
    }
    
    // MARK: - Navigation Helpers
    func navigateToCommunitDetail(_ community: Community) {
        HapticManager.shared.impact(style: .light)
        selectedCommunity = community
        navigateToCommunity = true
    }
    
    func navigateToLeaderboard(_ community: Community) {
        HapticManager.shared.impact(style: .light)
        selectedLeaderboardCommunity = community
        navigateToLeaderboard = true
    }
}

// MARK: - Modern Header Section
extension CommunitiesView {
    var modernHeaderSection: some View {
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
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
    
    var cleanStatsRow: some View {
        HStack(spacing: 10) {
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
    
    func statPill(value: String, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            // Icon container
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                
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
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
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
    
    func getSubtitle() -> String {
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
    var modernSideMenuOverlay: some View {
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
    
    var modernSideMenu: some View {
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
    
    func menuItem(_ tab: CommunityMainTab) -> some View {
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
    
    func getTabDescription(for tab: CommunityMainTab) -> String {
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
    var contentSection: some View {
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
            viewModel.refreshData()
        }
    }
}


// MARK: - Helper Methods
extension CommunitiesView {
    func getTabIcon(for tab: CommunityMainTab) -> String {
        switch tab {
        case .discover: return "magnifyingglass"
        case .myCommunities: return "person.3"
        case .leaderboard: return "trophy"
        }
    }
    
    func getCommunityColor(for type: CommunityType) -> Color {
        type.tint
    }
    
    func getCommunityInitials(from name: String) -> String {
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


// MARK: - CommunitySortType enum


// MARK: - Custom Button Styles


#Preview {
    CommunitiesView()
        .environmentObject(FirebaseAuthService.shared)
}
