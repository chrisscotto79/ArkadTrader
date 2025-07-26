//
//  CommunitiesView.swift
//  ArkadTrader
//
//  ENHANCED VERSION - Modern, Professional & Arkad Branded
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
                
                // Hidden NavigationLink
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

// MARK: - Modern Side Menu
extension CommunitiesView {
    private var modernSideMenuOverlay: some View {
        ZStack {
            // Enhanced backdrop
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
            // Elegant header with Arkad branding
            modernMenuHeader
            
            // Navigation items
            VStack(spacing: 8) {
                ForEach(CommunityMainTab.allCases, id: \.self) { tab in
                    modernMenuItem(tab)
                }
            }
            .padding(.vertical, 24)
            
            Spacer()
            
            // Premium create button
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

// MARK: - Content Section
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
                    modernComingSoonView(for: "Leaderboard", icon: "trophy.fill", description: "See top performing traders and communities")
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

// MARK: - Modern My Communities Content
extension CommunitiesView {
    private var modernMyCommunitiesContent: some View {
        VStack(spacing: 32) {
            if viewModel.userCommunities.isEmpty {
                modernEmptyMyCommunitiesState
            } else {
                VStack(alignment: .leading, spacing: 40) {
                    // Communities I Own
                    if !viewModel.userOwnedCommunities.isEmpty {
                        modernCommunitySection(
                            title: "Communities I Own",
                            icon: "crown.fill",
                            communities: viewModel.userOwnedCommunities,
                            isOwner: true,
                            accentColor: .warning
                        )
                    }
                    
                    // Communities I'm In
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
            // Enhanced section header
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
            
            // Modern communities grid
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
                // Community avatar with modern styling
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
                
                // Community information
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

// MARK: - Modern Discover Content with Integrated Search
extension CommunitiesView {
    private var modernDiscoverContent: some View {
        VStack(spacing: 32) {
            // Integrated search bar
            modernSearchSection
            
            if viewModel.discoveryCommunities.isEmpty {
                modernEmptyDiscoverState
            } else {
                VStack(spacing: 32) {
                    // Featured communities
                    if !viewModel.featuredCommunities.isEmpty {
                        modernFeaturedSection
                    }
                    
                    // All communities
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
            
            // Modern search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                
                TextField("Search communities...", text: .constant(""))
                    .font(.subheadline)
                    .disabled(true) // Placeholder for now
                
                Button(action: {
                    // Future: Advanced search/filters
                }) {
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
                // Community avatar
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
                
                // Community info
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

// MARK: - Supporting Types (Updated - Removed Search Tab)
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

#Preview {
    CommunitiesView()
        .environmentObject(FirebaseAuthService.shared)
}
