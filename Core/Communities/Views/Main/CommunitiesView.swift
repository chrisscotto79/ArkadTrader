// File: Core/Communities/Views/Main/CommunitiesView.swift
// Clean Communities View - All Errors Fixed

import SwiftUI

struct CommunitiesView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var communities: [Community] = []
    @State private var userCommunities: [Community] = []
    @State private var showCreateCommunity = false
    @State private var selectedTab: CommunityMainTab = .discover
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (no navigation title)
                headerSection
                
                // Tab Selector (vertical layout)
                tabSection
                
                // Content
                contentSection
            }
            
            // Floating Create Button (only on discover and my communities)
            if selectedTab == .discover || selectedTab == .myCommunities {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        createButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 90)
                }
            }
        }
        .sheet(isPresented: $showCreateCommunity) {
            createSheet
        }
        .onAppear {
            loadAllData()
        }
    }
}

// MARK: - Header Section
extension CommunitiesView {
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Communities")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { selectedTab = .search }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            
            // Only show stats if user actually has communities
            if !userCommunities.isEmpty {
                realStatsRow
            }
        }
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }
    
    private var realStatsRow: some View {
        HStack(spacing: 16) {
            statBox(title: "Joined", value: "\(userCommunities.count)", icon: "person.3.fill")
            statBox(title: "Active", value: "\(userCommunities.count)", icon: "chart.line.uptrend.xyaxis")
            statBox(title: "Created", value: "\(userCreatedCommunitiesCount)", icon: "trophy.fill")
        }
        .padding(.horizontal, 20)
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

// MARK: - Tab Section
extension CommunitiesView {
    private var tabSection: some View {
        VStack(spacing: 0) {
            // First row of tabs
            HStack(spacing: 0) {
                tabButton(.discover)
                tabButton(.myCommunities)
                tabButton(.leaderboard)
            }
            
            // Second row of tabs
            HStack(spacing: 0) {
                tabButton(.activity)
                tabButton(.search)
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
    }
    
    private func tabButton(_ tab: CommunityMainTab) -> some View {
        Button(action: { selectedTab = tab }) {
            VStack(spacing: 6) {
                Image(systemName: getTabIcon(for: tab))
                    .font(.title3)
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                
                Text(tab.displayName)
                    .font(.caption)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Content Section
extension CommunitiesView {
    private var contentSection: some View {
        Group {
            if isLoading {
                loadingView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        switch selectedTab {
                        case .discover:
                            discoverContent
                        case .myCommunities:
                            myCommunitiesContent
                        case .leaderboard:
                            leaderboardContent
                        case .activity:
                            activityContent
                        case .search:
                            searchContent
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            
            Text("Loading communities...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Discover Content
extension CommunitiesView {
    private var discoverContent: some View {
        VStack(spacing: 24) {
            if communities.isEmpty {
                emptyDiscoverState
            } else {
                // Featured Communities (top 3 by member count)
                if communities.count > 0 {
                    featuredSection
                }
                
                // Categories Section
                categoriesSection
                
                // All Communities
                allCommunitiesSection
            }
        }
        .padding(.top, 16)
    }
    
    private var featuredSection: some View {
        FeaturedCommunitiesSection.standard(
            communities: featuredCommunities,
            onCommunityTap: { community in
                print("Featured community tapped: \(community.name)")
            },
            onSeeAllTap: communities.count > 3 ? {
                print("See all featured communities")
            } : nil
        )
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Browse by Category")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CommunityType.allCases, id: \.self) { type in
                        categoryCard(type: type)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var allCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Communities")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ForEach(communities) { community in
                    CommunityCard.regular(
                        community: community,
                        isUserMember: isUserMember(community),
                        onTap: {
                            print("Community tapped: \(community.name)")
                        },
                        onJoin: {
                            joinCommunity(community)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func categoryCard(type: CommunityType) -> some View {
        VStack(spacing: 8) {
            Image(systemName: getCategoryIcon(for: type))
                .font(.title2)
                .foregroundColor(getCommunityTypeColor(for: type))
            
            Text(type.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            
            Text("\(communitiesCount(for: type))")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(width: 80, height: 80)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - My Communities Content
extension CommunitiesView {
    private var myCommunitiesContent: some View {
        VStack(spacing: 20) {
            if userCommunities.isEmpty {
                emptyMyCommunitiesState
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    // Communities I Own
                    if !userOwnedCommunities.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Communities I Own")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(userOwnedCommunities) { community in
                                    CommunityCard.userCommunity(
                                        community: community,
                                        isOwner: true,
                                        onTap: {
                                            print("Owned community tapped: \(community.name)")
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Communities I'm a Member Of
                    if !userMemberCommunities.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Communities I'm In")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(userMemberCommunities) { community in
                                    CommunityCard.userCommunity(
                                        community: community,
                                        isOwner: false,
                                        onTap: {
                                            print("Member community tapped: \(community.name)")
                                        }
                                    )
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

// MARK: - Other Content Tabs
extension CommunitiesView {
    private var leaderboardContent: some View {
        VStack(spacing: 24) {
            if communities.isEmpty {
                emptyStateView(
                    icon: "trophy.circle",
                    title: "No Leaderboards Yet",
                    description: "Community leaderboards will appear here when communities are created and active."
                )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Community Leaderboards")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 20)
                    
                    // Top Communities by Members
                    leaderboardSection(
                        title: "Most Popular",
                        communities: communities.sorted { $0.memberCount > $1.memberCount }.prefix(5),
                        metric: "members"
                    )
                    
                    // Newest Communities
                    leaderboardSection(
                        title: "Newest",
                        communities: communities.sorted { $0.createdAt > $1.createdAt }.prefix(5),
                        metric: "days old"
                    )
                }
            }
        }
        .padding(.top, 16)
    }
    
    private var activityContent: some View {
        VStack(spacing: 24) {
            if communities.isEmpty {
                emptyStateView(
                    icon: "clock.circle",
                    title: "No Activity Yet",
                    description: "Recent community activity will appear here as communities become active."
                )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Recent Activity")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 16) {
                        ForEach(0..<min(communities.count, 5), id: \.self) { index in
                            simpleActivityRow(community: communities[index])
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.top, 16)
    }
    
    private var searchContent: some View {
        VStack(spacing: 24) {
            Text("Search Communities")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
            
            Text("Advanced search features coming soon! You'll be able to filter by trading focus, member count, activity level, and more.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 40)
        }
        .padding(.top, 16)
    }
}

// MARK: - Supporting Views
extension CommunitiesView {
    private func leaderboardSection(title: String, communities: ArraySlice<Community>, metric: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
            
            VStack(spacing: 8) {
                ForEach(0..<communities.count, id: \.self) { index in
                    let community = Array(communities)[index]
                    leaderboardRow(community: community, rank: index + 1, metric: metric)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func leaderboardRow(community: Community, rank: Int, metric: String) -> some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(rank == 1 ? .yellow : rank == 2 ? .gray : rank == 3 ? .orange : .blue)
                .frame(width: 30)
            
            Circle()
                .fill(getCommunityColor(for: community))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(getInitials(from: community.name))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(community.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(metric == "members" ? "\(community.memberCount) members" : "\(daysSinceCreated(community)) days old")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func simpleActivityRow(community: Community) -> some View {
        let daysOld = daysSinceCreated(community)
        
        return HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 40, height: 40)
                .background(Color.green.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Community Created")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(community.name)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(daysOld == 0 ? "Today" : "\(daysOld) day\(daysOld == 1 ? "" : "s") ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func emptyStateView(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }
}

// MARK: - Empty States
extension CommunitiesView {
    private var emptyDiscoverState: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Communities Available")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Be the first to create a community and start building your trading network!")
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
        .padding(.horizontal, 20)
    }
    
    private var emptyMyCommunitiesState: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Communities Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Join communities to connect with other traders, share insights, and learn from experienced investors.")
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
        .padding(.horizontal, 20)
    }
}

// MARK: - Create Button & Sheet
extension CommunitiesView {
    private var createButton: some View {
        Button(action: { showCreateCommunity = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Create")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private var createSheet: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Create Community")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Community creation features are coming soon! You'll be able to create and manage your own trading communities.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 30)
                
                Button("Got it") {
                    showCreateCommunity = false
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(40)
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") { showCreateCommunity = false })
        }
    }
}

// MARK: - Helper Methods
extension CommunitiesView {
    private func loadAllData() {
        Task {
            isLoading = true
            
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadAllCommunities() }
                group.addTask { await self.loadUserCommunities() }
            }
            
            isLoading = false
        }
    }
    
    private func loadAllCommunities() async {
        do {
            communities = try await authService.getCommunities()
        } catch {
            print("Error loading all communities: \(error)")
        }
    }
    
    private func loadUserCommunities() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            userCommunities = try await authService.getUserCommunities(userId: userId)
        } catch {
            print("Error loading user communities: \(error)")
        }
    }
    
    private func joinCommunity(_ community: Community) {
        guard let userId = authService.currentUser?.id else { return }
        
        Task {
            do {
                try await authService.joinCommunity(communityId: community.id, userId: userId)
                await loadAllData()
            } catch {
                print("Error joining community: \(error)")
            }
        }
    }
    
    private func isUserMember(_ community: Community) -> Bool {
        return userCommunities.contains { $0.id == community.id }
    }
    
    private func getTabIcon(for tab: CommunityMainTab) -> String {
        switch tab {
        case .discover: return "magnifyingglass.circle"
        case .myCommunities: return "person.3.fill"
        case .leaderboard: return "trophy.fill"
        case .activity: return "clock.fill"
        case .search: return "magnifyingglass"
        }
    }
    
    private func communitiesCount(for type: CommunityType) -> Int {
        return communities.filter { $0.type == type }.count
    }
    
    private func getCommunityTypeColor(for type: CommunityType) -> Color {
        switch type {
        case .dayTrading: return .red
        case .swingTrading: return .orange
        case .options: return .purple
        case .crypto: return .yellow
        case .stocks: return .green
        case .general: return .blue
        }
    }
    
    private func getCategoryIcon(for type: CommunityType) -> String {
        switch type {
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "waveform.path"
        case .options: return "arrow.up.arrow.down.circle"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        case .general: return "person.3.fill"
        }
    }
    
    private func daysSinceCreated(_ community: Community) -> Int {
        let days = Calendar.current.dateComponents([.day], from: community.createdAt, to: Date()).day ?? 0
        return max(0, days)
    }
    
    private func getInitials(from name: String) -> String {
        let words = name.components(separatedBy: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private func formatMemberCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
    
    private func getCommunityColor(for community: Community) -> Color {
        switch community.type {
        case .dayTrading: return .red
        case .swingTrading: return .orange
        case .options: return .purple
        case .crypto: return .yellow
        case .stocks: return .green
        case .general: return .blue
        }
    }
    
    private var userCreatedCommunitiesCount: Int {
        guard let userId = authService.currentUser?.id else { return 0 }
        return userCommunities.filter { $0.createdBy == userId }.count
    }
    
    private var userOwnedCommunities: [Community] {
        guard let userId = authService.currentUser?.id else { return [] }
        return userCommunities.filter { $0.createdBy == userId }
    }
    
    private var userMemberCommunities: [Community] {
        guard let userId = authService.currentUser?.id else { return [] }
        return userCommunities.filter { $0.createdBy != userId }
    }
    
    private var featuredCommunities: [Community] {
        return Array(communities.sorted { $0.memberCount > $1.memberCount }.prefix(3))
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
