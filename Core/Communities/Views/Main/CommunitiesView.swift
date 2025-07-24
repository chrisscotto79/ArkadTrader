//
//  CommunitiesView.swift
//  ArkadTrader
//
//  ENHANCED VERSION - Beautiful & Functional
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
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        Color(.systemBackground).opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with hamburger menu
                    headerSection
                    
                    // Main Content
                    contentSection
                }
                
                // Side Menu Overlay
                if showSideMenu {
                    sideMenuOverlay
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

// MARK: - Header Section
extension CommunitiesView {
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Top Navigation Row
            HStack {
                // Hamburger Menu Button
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showSideMenu.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                }
                
                Spacer()
                
                // Current Section Title with icon
                HStack(spacing: 8) {
                    Image(systemName: getTabIcon(for: selectedTab))
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    Text(selectedTab.displayName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Create Button with animation
                Button(action: {
                    print("➕ Create community button tapped")
                    showCreateCommunity = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .shadow(color: .blue.opacity(0.3), radius: 3, x: 0, y: 2)
                        )
                        .scaleEffect(showCreateCommunity ? 0.9 : 1.0)
                        .animation(.spring(response: 0.3), value: showCreateCommunity)
                }
            }
            .padding(.horizontal, 20)
            
            // Stats Row with animations
            if !viewModel.userCommunities.isEmpty && selectedTab == .myCommunities {
                HStack(spacing: 16) {
                    statBox(title: "Joined", value: "\(viewModel.userCommunities.count)", icon: "person.3.fill", color: .blue)
                    statBox(title: "Active", value: "\(viewModel.activeCommunities)", icon: "chart.line.uptrend.xyaxis", color: .green)
                    statBox(title: "Created", value: "\(viewModel.userOwnedCommunities.count)", icon: "trophy.fill", color: .orange)
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 16)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
        )
    }
    
    private func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: color.opacity(0.2), radius: 3, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Side Menu
extension CommunitiesView {
    private var sideMenuOverlay: some View {
        ZStack {
            // Dark overlay with blur effect
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showSideMenu = false
                    }
                }
            
            HStack {
                // Side Menu Content
                enhancedSideMenu
                Spacer()
            }
        }
    }
    
    private var enhancedSideMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Menu Header with gradient
            menuHeader
            
            // Menu Items
            VStack(spacing: 4) {
                ForEach(CommunityMainTab.allCases, id: \.self) { tab in
                    enhancedMenuItem(tab)
                }
            }
            .padding(.vertical, 16)
            
            Spacer()
            
            // Create Community Button
            Button(action: {
                print("➕ Side menu create community tapped")
                showCreateCommunity = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showSideMenu = false
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("Create Community")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 5, y: 0)
        )
        .offset(x: showSideMenu ? 0 : -350)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showSideMenu)
    }
    
    private var menuHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Communities")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showSideMenu = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            
            if let user = authService.currentUser {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome back,")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(user.fullName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private func enhancedMenuItem(_ tab: CommunityMainTab) -> some View {
        Button(action: {
            print("📱 Side menu tab tapped: \(tab.displayName)")
            selectedTab = tab
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showSideMenu = false
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: getTabIcon(for: tab))
                    .font(.title3)
                    .foregroundColor(selectedTab == tab ? .white : .gray)
                    .frame(width: 28, height: 28)
                
                Text(tab.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                
                Spacer()
                
                if selectedTab == tab {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedTab == tab ?
                          LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                          LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Content Section
extension CommunitiesView {
    private var contentSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                switch selectedTab {
                case .discover:
                    discoverContent
                case .myCommunities:
                    myCommunitiesContent
                case .leaderboard:
                    comingSoonView(for: "Leaderboard", icon: "trophy.fill")
                case .activity:
                    comingSoonView(for: "Activity", icon: "clock.fill")
                case .search:
                    comingSoonView(for: "Search", icon: "magnifyingglass")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }
    
    private func comingSoonView(for feature: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("\(feature) Coming Soon")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("We're working hard to bring you this feature!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 80)
    }
}

// MARK: - My Communities Content
extension CommunitiesView {
    private var myCommunitiesContent: some View {
        VStack(spacing: 24) {
            if viewModel.userCommunities.isEmpty {
                emptyMyCommunitiesState
            } else {
                VStack(alignment: .leading, spacing: 32) {
                    // Communities I Own
                    if !viewModel.userOwnedCommunities.isEmpty {
                        communitySection(
                            title: "Communities I Own",
                            icon: "crown.fill",
                            communities: viewModel.userOwnedCommunities,
                            isOwner: true
                        )
                    }
                    
                    // Communities I'm In
                    if !viewModel.userMemberCommunities.isEmpty {
                        communitySection(
                            title: "Communities I'm In",
                            icon: "person.3.fill",
                            communities: viewModel.userMemberCommunities,
                            isOwner: false
                        )
                    }
                }
            }
        }
        .padding(.top, 20)
        .onAppear {
            print("📋 My Communities content appeared")
            print("   User communities count: \(viewModel.userCommunities.count)")
            print("   Owned communities count: \(viewModel.userOwnedCommunities.count)")
        }
    }
    
    private func communitySection(title: String, icon: String, communities: [Community], isOwner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(communities.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            // Communities Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(communities) { community in
                    enhancedCommunityCard(community: community, isOwner: isOwner)
                }
            }
        }
    }
    
    private func enhancedCommunityCard(community: Community, isOwner: Bool) -> some View {
        Button(action: {
            print("🏘️ Enhanced community tapped: \(community.name)")
            navigateToCommunitDetail(community)
        }) {
            VStack(spacing: 12) {
                // Community Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [getCommunityColor(for: community.type), getCommunityColor(for: community.type).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(getCommunityInitials(from: community.name))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .shadow(color: getCommunityColor(for: community.type).opacity(0.4), radius: 6, x: 0, y: 3)
                
                // Community Info
                VStack(spacing: 6) {
                    Text(community.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.caption2)
                            Text("\(community.memberCount)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                        
                        if isOwner {
                            Text("OWNER")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(community.type.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(getCommunityColor(for: community.type))
                        .cornerRadius(6)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(getCommunityColor(for: community.type).opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Discover Content
extension CommunitiesView {
    private var discoverContent: some View {
        VStack(spacing: 32) {
            if viewModel.discoveryCommunities.isEmpty {
                emptyDiscoverState
            } else {
                // Featured Communities
                if !viewModel.featuredCommunities.isEmpty {
                    featuredCommunitiesSection
                }
                
                // All Communities
                allCommunitiesSection
            }
        }
        .padding(.top, 20)
        .onAppear {
            print("🔍 Discover content appeared")
            print("   Discovery communities count: \(viewModel.discoveryCommunities.count)")
            print("   Featured communities count: \(viewModel.featuredCommunities.count)")
        }
    }
    
    private var featuredCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundColor(.yellow)
                
                Text("Featured Communities")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.featuredCommunities) { community in
                        featuredCommunityCard(community: community)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func featuredCommunityCard(community: Community) -> some View {
        Button(action: {
            print("⭐ Featured community tapped: \(community.name)")
            navigateToCommunitDetail(community)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(getCommunityColor(for: community.type))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(getCommunityInitials(from: community.name))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    Spacer()
                    
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(community.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Text("\(community.memberCount) members")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(community.type.displayName)
                            .font(.caption2)
                            .foregroundColor(getCommunityColor(for: community.type))
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .frame(width: 200, height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var allCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("All Communities")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(viewModel.discoveryCommunities) { community in
                    discoveryCommunityCard(community: community)
                }
            }
        }
    }
    
    private func discoveryCommunityCard(community: Community) -> some View {
        Button(action: {
            print("🌍 Discovery community tapped: \(community.name)")
            navigateToCommunitDetail(community)
        }) {
            VStack(spacing: 12) {
                // Community Avatar
                Circle()
                    .fill(getCommunityColor(for: community.type))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(getCommunityInitials(from: community.name))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                // Community Info
                VStack(spacing: 6) {
                    Text(community.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text("\(community.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if viewModel.isUserMember(of: community) {
                        Text("MEMBER")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(6)
                    } else {
                        Button(action: {
                            print("➕ Join button tapped for: \(community.name)")
                            viewModel.joinCommunity(community)
                        }) {
                            Text("JOIN")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(getCommunityColor(for: community.type))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty States
extension CommunitiesView {
    private var emptyMyCommunitiesState: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Communities Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Join communities to connect with other traders and share insights.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Explore Communities") {
                print("🔍 Explore Communities button tapped")
                selectedTab = .discover
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.top, 80)
    }
    
    private var emptyDiscoverState: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Communities Available")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Be the first to create a community!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Create First Community") {
                print("➕ Create First Community button tapped")
                showCreateCommunity = true
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.top, 80)
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
        case .search: return "magnifyingglass"
        }
    }
    
    private func getCommunityColor(for type: CommunityType) -> Color {
        switch type {
        case .dayTrading: return .red
        case .swingTrading: return .orange
        case .options: return .purple
        case .crypto: return .yellow
        case .stocks: return .green
        case .general: return .blue
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
    case search
    
    var displayName: String {
        switch self {
        case .discover: return "Discover"
        case .myCommunities: return "My Communities"
        case .leaderboard: return "Leaderboard"
        case .activity: return "Activity"
        case .search: return "Search"
        }
    }
}

#Preview {
    CommunitiesView()
        .environmentObject(FirebaseAuthService.shared)
}
