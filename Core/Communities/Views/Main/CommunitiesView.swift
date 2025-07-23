//
//  CommunitiesView.swift
//  ArkadTrader
//
//  Working version with hamburger menu and proper NavigationLink
//

import SwiftUI

struct CommunitiesView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var viewModel = CommunitiesViewModel()
    @State private var showCreateCommunity = false
    @State private var selectedTab: CommunityMainTab = .myCommunities
    @State private var showSideMenu = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
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
}

// MARK: - Header Section
extension CommunitiesView {
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                // Hamburger Menu Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSideMenu.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                // Current Section Title
                Text(selectedTab.displayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Create Button
                Button(action: { showCreateCommunity = true }) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 20)
            
            // Stats Row
            if !viewModel.userCommunities.isEmpty && selectedTab == .myCommunities {
                HStack(spacing: 16) {
                    statBox(title: "Joined", value: "\(viewModel.userCommunities.count)", icon: "person.3.fill")
                    statBox(title: "Active", value: "2", icon: "chart.line.uptrend.xyaxis")
                    statBox(title: "Created", value: "\(viewModel.userOwnedCommunities.count)", icon: "trophy.fill")
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }
    
    private func statBox(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Side Menu
extension CommunitiesView {
    private var sideMenuOverlay: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSideMenu = false
                    }
                }
            
            HStack {
                // Side Menu Content
                sideMenu
                Spacer()
            }
        }
    }
    
    private var sideMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Menu Header
            menuHeader
            
            // Menu Items
            VStack(spacing: 0) {
                ForEach(CommunityMainTab.allCases, id: \.self) { tab in
                    menuItem(tab)
                }
            }
            
            Spacer()
            
            // Create Community Button
            Button(action: {
                showCreateCommunity = true
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSideMenu = false
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("Create Community")
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 280)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 5, y: 0)
        .offset(x: showSideMenu ? 0 : -300)
        .animation(.easeInOut(duration: 0.3), value: showSideMenu)
    }
    
    private var menuHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Communities")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSideMenu = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            
            if let user = authService.currentUser {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back,")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(user.fullName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func menuItem(_ tab: CommunityMainTab) -> some View {
        Button(action: {
            selectedTab = tab
            withAnimation(.easeInOut(duration: 0.3)) {
                showSideMenu = false
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: getTabIcon(for: tab))
                    .font(.title3)
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                    .frame(width: 24)
                
                Text(tab.displayName)
                    .font(.subheadline)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                    .foregroundColor(selectedTab == tab ? .blue : .primary)
                
                Spacer()
                
                if selectedTab == tab {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Rectangle()
                    .fill(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Content Section
extension CommunitiesView {
    private var contentSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                switch selectedTab {
                case .discover:
                    discoverContent
                case .myCommunities:
                    myCommunitiesContent
                case .leaderboard:
                    Text("Leaderboard Coming Soon")
                        .foregroundColor(.gray)
                        .padding(.top, 50)
                case .activity:
                    Text("Activity Coming Soon")
                        .foregroundColor(.gray)
                        .padding(.top, 50)
                case .search:
                    Text("Search Coming Soon")
                        .foregroundColor(.gray)
                        .padding(.top, 50)
                }
            }
            .padding(.bottom, 100)
        }
    }
}

// MARK: - My Communities Content
extension CommunitiesView {
    private var myCommunitiesContent: some View {
        VStack(spacing: 20) {
            if viewModel.userCommunities.isEmpty {
                emptyMyCommunitiesState
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    // Communities I Own
                    if !viewModel.userOwnedCommunities.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Communities I Own")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(viewModel.userOwnedCommunities) { community in
                                    NavigationLink(destination: CommunityDetailView(community: community)) {
                                        CommunityCard.userCommunity(
                                            community: community,
                                            isOwner: true,
                                            onTap: nil
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Communities I'm In
                    if !viewModel.userMemberCommunities.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Communities I'm In")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(viewModel.userMemberCommunities) { community in
                                    NavigationLink(destination: CommunityDetailView(community: community)) {
                                        CommunityCard.userCommunity(
                                            community: community,
                                            isOwner: false,
                                            onTap: nil
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Discover Content
extension CommunitiesView {
    private var discoverContent: some View {
        VStack(spacing: 24) {
            if viewModel.discoveryCommunities.isEmpty {
                emptyDiscoverState
            } else {
                // Featured Communities
                if !viewModel.featuredCommunities.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Featured Communities")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.featuredCommunities) { community in
                                    NavigationLink(destination: CommunityDetailView(community: community)) {
                                        CommunityCard.featured(
                                            community: community,
                                            onTap: nil
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .frame(width: 180)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                // All Communities
                VStack(alignment: .leading, spacing: 16) {
                    Text("All Communities")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        ForEach(viewModel.discoveryCommunities) { community in
                            NavigationLink(destination: CommunityDetailView(community: community)) {
                                CommunityCard.regular(
                                    community: community,
                                    isUserMember: viewModel.isUserMember(of: community),
                                    onTap: nil,
                                    onJoin: {
                                        viewModel.joinCommunity(community)
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Empty States
extension CommunitiesView {
    private var emptyMyCommunitiesState: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Communities Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Join communities to connect with other traders and share insights.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Explore Communities") {
                selectedTab = .discover
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(12)
        }
        .padding(.top, 60)
    }
    
    private var emptyDiscoverState: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Communities Available")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Be the first to create a community!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Create First Community") {
                showCreateCommunity = true
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(12)
        }
        .padding(.top, 60)
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
