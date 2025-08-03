// File: Core/Profile/Views/ProfileView.swift
// Redesigned Profile View with Modern Layout - Inspired by Financial App UI

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var postsViewModel = UserPostsViewModel()
    @StateObject private var groupsViewModel = UserGroupsViewModel()
    
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var selectedTab: ProfileTab = .posts
    @State private var showPortfolioDetails = false
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Modern Gradient Header
                modernHeaderSection
                
                // Main Content Area
                VStack(spacing: 20) {
                    // Quick Stats Card
                    quickStatsCard
                    
                    // Portfolio Performance Card
                    portfolioPerformanceCard
                    
                    // Tab Content
                    tabContentSection
                }
                .padding(.horizontal)
                .padding(.top, -30) // Overlap with header
            }
        }
        .ignoresSafeArea(.all, edges: .top) // Extend to full top
        .refreshable {
            await refreshProfile()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showPortfolioDetails) {
            PortfolioDetailsSheet()
                .environmentObject(portfolioViewModel)
        }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
            postsViewModel.loadUserPosts(userId: authService.currentUser?.id ?? "")
            groupsViewModel.loadUserGroups(userId: authService.currentUser?.id ?? "")
        }
    }
    
    // MARK: - Modern Header Section
    private var modernHeaderSection: some View {
        GeometryReader { geometry in
            ZStack {
                // Gradient Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.arkadGold.opacity(0.9),
                        Color.arkadGold.opacity(0.7),
                        Color.arkadGold.opacity(0.5)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Decorative elements
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .offset(x: -150, y: -80)
                
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 60, height: 60)
                    .offset(x: 140, y: -100)
                
                VStack(spacing: 0) {
                    // Top Bar with Safe Area
                    HStack {
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .opacity(0) // Hidden for main profile
                        
                        Spacer()
                        
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, geometry.safeAreaInsets.top + 50) // Proper safe area + extra padding
                    
                    Spacer()
                    
                    // Profile Info
                    VStack(spacing: 20) {
                        // Profile Image - Fixed to match EditProfileView pattern
                        Group {
                            if let imageUrl = authService.currentUser?.profileImageUrl,
                               !imageUrl.isEmpty {
                                AsyncImage(url: URL(string: imageUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.arkadGold.opacity(0.2))
                                        .overlay(
                                            ProgressView()
                                                .tint(.arkadGold)
                                        )
                                }
                            } else {
                                // Fallback to initials
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.arkadGold.opacity(0.8),
                                                Color.arkadGold.opacity(0.6)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Text(String(authService.currentUser?.username.prefix(2) ?? "LA").uppercased())
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                        .frame(width: 110, height: 110)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 5)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        // User Info
                        VStack(spacing: 8) {
                            Text(authService.currentUser?.fullName ?? "User Name")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 16) {
                                Text("@\(authService.currentUser?.username ?? "username")")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text("Joined \(formatJoinDate())")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .frame(height: 320) // Increased height to account for full top extension
        .clipped()
    }
    
    // MARK: - Quick Stats Card
    private var quickStatsCard: some View {
        VStack(spacing: 20) {
            // Header with Edit Profile Button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trading Profile")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Your performance overview")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Button(action: { showEditProfile = true }) {
                    Text("Edit Profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.arkadGold.opacity(0.1))
                        .cornerRadius(20)
                }
            }
            
            // Stats Grid
            HStack(spacing: 16) {
                statItem(
                    title: "Followers",
                    value: "0",
                    action: { showFollowersList = true }
                )
                
                statItem(
                    title: "Following",
                    value: "2",
                    action: { showFollowingList = true }
                )
                
                statItem(
                    title: "Trades",
                    value: "\(portfolioViewModel.getPortfolioSummaryForProfile().totalTrades)",
                    action: nil
                )
                
                statItem(
                    title: "Win Rate",
                    value: String(format: "%.1f%%", portfolioViewModel.getPortfolioSummaryForProfile().winRate),
                    action: nil
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Portfolio Performance Card
    private var portfolioPerformanceCard: some View {
        Button(action: { showPortfolioDetails = true }) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Performance Tracker")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("Tap to view detailed analytics")
                            .font(.caption)
                            .foregroundColor(.arkadGold)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.subheadline)
                        .foregroundColor(.arkadGold)
                }
                
                // Main Metric
                VStack(spacing: 8) {
                    Text("Total P&L")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    
                    Text(portfolioViewModel.getPortfolioSummaryForProfile().totalProfitLoss.asCurrencyWithSign)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(portfolioViewModel.getPortfolioSummaryForProfile().totalProfitLoss >= 0 ? .marketGreen : .marketRed)
                    
                    Text("+12% better than last month")
                        .font(.caption)
                        .foregroundColor(.marketGreen)
                }
                
                // Performance Metrics
                HStack(spacing: 20) {
                    performanceMetric(
                        title: "Today",
                        value: portfolioViewModel.getPortfolioSummaryForProfile().dayProfitLoss.asCurrencyWithSign,
                        color: portfolioViewModel.getPortfolioSummaryForProfile().dayProfitLoss >= 0 ? .marketGreen : .marketRed,
                        icon: "calendar"
                    )
                    
                    performanceMetric(
                        title: "Win Rate",
                        value: String(format: "%.1f%%", portfolioViewModel.getPortfolioSummaryForProfile().winRate),
                        color: portfolioViewModel.getPortfolioSummaryForProfile().winRate >= 50 ? .marketGreen : .marketRed,
                        icon: "target"
                    )
                    
                    performanceMetric(
                        title: "Trades",
                        value: "\(portfolioViewModel.getPortfolioSummaryForProfile().totalTrades)",
                        color: .arkadGold,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.arkadGold.opacity(0.05),
                                Color.white
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.arkadGold.opacity(0.1), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Tab Content Section
    private var tabContentSection: some View {
        VStack(spacing: 16) {
            // Modern Tab Selector
            modernTabSelector
            
            // Tab Content
            ProfileTabContent(
                selectedTab: selectedTab,
                portfolioViewModel: portfolioViewModel,
                postsViewModel: postsViewModel,
                groupsViewModel: groupsViewModel
            )
        }
    }
    
    // MARK: - Modern Tab Selector
    private var modernTabSelector: some View {
        ProfileTabSelector(selectedTab: $selectedTab)
    }
    
    // MARK: - Helper Views
    private func statItem(title: String, value: String, action: (() -> Void)?) -> some View {
        Button(action: action ?? {}) {
            VStack(spacing: 8) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
    
    private func performanceMetric(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
    
    @MainActor
    private func refreshProfile() async {
        // Refresh the current user data from Firebase
        await authService.refreshCurrentUser()
        
        // Refresh other profile data
        portfolioViewModel.refreshPortfolio()
        await postsViewModel.refreshPosts()
        await groupsViewModel.refreshGroups()
    }
    
    // MARK: - Helper Methods
    private func formatJoinDate() -> String {
        guard let user = authService.currentUser else { return "recently" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: user.createdAt)
    }
}

// MARK: - Simple Follow Button (Minimal Version)
struct SimpleFollowButton: View {
    let targetUserId: String
    let targetUsername: String
    @State private var isFollowing = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var debugInfo = ""
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                Task {
                    await toggleFollow()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                            .font(.subheadline)
                    }
                    
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(isFollowing ? .primary : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isFollowing ? Color.gray.opacity(0.2) : Color.arkadGold)
                        .shadow(color: isFollowing ? Color.clear : Color.arkadGold.opacity(0.5), radius: 10, x: 0, y: 5)
                )
            }
            .disabled(isLoading)
            
            // Debug info (remove in production)
            if !debugInfo.isEmpty {
                Text(debugInfo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            Task {
                await checkFollowStatus()
            }
        }
        .alert("Follow Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func toggleFollow() async {
        // Enhanced debugging and error handling
        print("🔄 toggleFollow() called")
        print("📋 targetUserId: \(targetUserId)")
        print("👤 targetUsername: \(targetUsername)")
        
        guard let currentUserId = authService.currentUser?.id else {
            await MainActor.run {
                errorMessage = "Not authenticated. Please sign in again."
                showError = true
                debugInfo = "❌ No current user"
            }
            print("❌ No current user found")
            return
        }
        
        guard !targetUserId.isEmpty else {
            await MainActor.run {
                errorMessage = "Invalid user ID"
                showError = true
                debugInfo = "❌ Empty target user ID"
            }
            print("❌ Target user ID is empty")
            return
        }
        
        guard currentUserId != targetUserId else {
            await MainActor.run {
                errorMessage = "Cannot follow yourself"
                showError = true
                debugInfo = "❌ Cannot follow self"
            }
            print("❌ Trying to follow self")
            return
        }
        
        print("✅ Current user: \(currentUserId)")
        print("🔄 Starting follow operation...")
        
        await MainActor.run {
            isLoading = true
            debugInfo = "🔄 Processing..."
        }
        
        do {
            if isFollowing {
                print("👋 Unfollowing user...")
                try await authService.unfollowUser(userId: targetUserId, followerId: currentUserId)
                print("✅ Unfollow successful")
            } else {
                print("👍 Following user...")
                try await authService.followUser(userId: targetUserId, followerId: currentUserId)
                print("✅ Follow successful")
            }
            
            await MainActor.run {
                isFollowing.toggle()
                debugInfo = isFollowing ? "✅ Following!" : "✅ Unfollowed!"
                
                // Clear debug info after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    debugInfo = ""
                }
            }
            
        } catch {
            print("❌ Follow error: \(error)")
            print("📋 Error details: \(error.localizedDescription)")
            
            await MainActor.run {
                errorMessage = "Follow failed: \(error.localizedDescription)"
                showError = true
                debugInfo = "❌ Error: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func checkFollowStatus() async {
        print("🔍 Checking follow status...")
        
        guard let currentUserId = authService.currentUser?.id else {
            print("❌ No current user for follow status check")
            await MainActor.run {
                debugInfo = "❌ Not authenticated"
            }
            return
        }
        
        guard !targetUserId.isEmpty else {
            print("❌ Empty target user ID for follow status check")
            return
        }
        
        print("🔍 Checking if \(currentUserId) follows \(targetUserId)")
        
        do {
            let followStatus = try await authService.isFollowing(userId: currentUserId, targetUserId: targetUserId)
            print("✅ Follow status result: \(followStatus)")
            
            await MainActor.run {
                isFollowing = followStatus
                debugInfo = followStatus ? "Already following" : "Not following"
                
                // Clear debug info after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    debugInfo = ""
                }
            }
        } catch {
            print("❌ Error checking follow status: \(error)")
            await MainActor.run {
                debugInfo = "❌ Status check failed"
            }
        }
    }
}

// MARK: - Simple Follow List View (Minimal Version)
struct SimpleFollowListView: View {
    let userId: String
    let listType: ListType
    
    @State private var users: [User] = []
    @State private var isLoading = true
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    enum ListType {
        case followers
        case following
        
        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if users.isEmpty {
                    VStack {
                        Text("No \(listType.title.lowercased()) yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(users) { user in
                            SimpleUserRow(user: user)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(listType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await loadUsers()
                }
            }
        }
    }
    
    private func loadUsers() async {
        isLoading = true
        
        do {
            let userIds: Set<String>
            
            switch listType {
            case .followers:
                userIds = try await authService.getUserFollowers(userId: userId)
            case .following:
                userIds = try await authService.getUserFollowing(userId: userId)
            }
            
            // Fetch user details
            var fetchedUsers: [User] = []
            for id in userIds {
                if let user = try await authService.getUserById(userId: id) {
                    fetchedUsers.append(user)
                }
            }
            
            users = fetchedUsers.sorted { $0.username < $1.username }
            
        } catch {
            print("Error loading users: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Simple User Row (Minimal Version)
struct SimpleUserRow: View {
    let user: User
    
    var body: some View {
        HStack {
            // Simple initial circle instead of image
            Circle()
                .fill(Color.arkadGold)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(user.username.prefix(1)).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

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

// MARK: - Supporting Card Components
struct ProfileUserPostCard: View {
    let post: Post
    let onPostDeleted: (() -> Void)?
    @State private var showFullPost = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isPressed = false
    @EnvironmentObject var authService: FirebaseAuthService
    
    init(post: Post, onPostDeleted: (() -> Void)? = nil) {
        self.post = post
        self.onPostDeleted = onPostDeleted
    }
    
    var body: some View {
        Button(action: {
            showFullPost = true
        }) {
            // UPDATED: Horizontal layout for single column display
            HStack(spacing: 16) {
                // Image or icon section (fixed width)
                imageSection
                    .frame(width: 80)
                
                // Content section (flexible width)
                VStack(alignment: .leading, spacing: 12) {
                    // Post content
                    Text(post.content)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Bottom section with engagement and metadata
                    VStack(spacing: 8) {
                        // Engagement stats
                        HStack(spacing: 16) {
                            // Likes
                            HStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                        .frame(width: 20, height: 20)
                                    
                                    Image(systemName: post.likesCount > 0 ? "heart.fill" : "heart")
                                        .font(.caption2)
                                        .foregroundColor(post.likesCount > 0 ? .red : .gray)
                                }
                                
                                Text("\(post.likesCount)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            
                            // Comments
                            if post.commentsCount > 0 {
                                HStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                            .frame(width: 20, height: 20)
                                        
                                        Image(systemName: "message.fill")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Text("\(post.commentsCount)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Spacer()
                            
                            // Time
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundColor(.arkadGold.opacity(0.7))
                                
                                Text(formatTimeAgo(post.createdAt))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Post type indicator
                        HStack {
                            if post.postType != .text {
                                HStack(spacing: 4) {
                                    Image(systemName: postTypeIcon(for: post.postType))
                                        .font(.caption2)
                                    
                                    Text(post.postType.displayName)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(postTypeColor(for: post.postType))
                                        .shadow(color: postTypeColor(for: post.postType).opacity(0.3), radius: 2, x: 0, y: 1)
                                )
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(
                        color: isPressed ? Color.arkadGold.opacity(0.15) : Color.black.opacity(0.04),
                        radius: isPressed ? 8 : 4,
                        x: 0,
                        y: isPressed ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.arkadGold.opacity(isPressed ? 0.3 : 0.1),
                                Color.arkadGold.opacity(isPressed ? 0.15 : 0.05),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .sheet(isPresented: $showFullPost) {
            ProfilePostDetailView(
                post: post,
                onDelete: {
                    Task {
                        await deletePost()
                    }
                }
            )
            .environmentObject(authService)
        }
        .overlay(deletingOverlay)
    }
    
    // UPDATED: Optimized image section for horizontal layout
    @ViewBuilder
    private var imageSection: some View {
        if !post.imageUrls.isEmpty {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: post.imageUrls.first!)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.arkadGold.opacity(0.3),
                                Color.arkadGold.opacity(0.1),
                                Color.arkadGold.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundColor(.arkadGold.opacity(0.6))
                            
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .arkadGold))
                                .scaleEffect(0.6)
                        }
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Image count badge
                if post.imageUrls.count > 1 {
                    Text("\(post.imageUrls.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.4))
                                )
                        )
                        .offset(x: -4, y: 4)
                }
            }
        } else {
            // Text-only post icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.arkadGold.opacity(0.15),
                                Color.arkadGold.opacity(0.08),
                                Color.arkadGold.opacity(0.03)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 4) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.title3)
                        .foregroundColor(.arkadGold.opacity(0.7))
                    
                    Text("Text")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold.opacity(0.8))
                }
            }
            .frame(width: 80, height: 80)
        }
    }
    
    @ViewBuilder
    private var deletingOverlay: some View {
        if isDeleting {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                )
                .overlay(
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        
                        Text("Deleting...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                )
        }
    }
    
    private func postTypeIcon(for type: PostType) -> String {
        switch type {
        case .text: return "text.quote"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "magnifyingglass.circle"
        }
    }
    
    private func postTypeColor(for type: PostType) -> Color {
        switch type {
        case .text: return .gray
        case .tradeResult: return .green
        case .marketAnalysis: return .blue
        }
    }
    
    private func deletePost() async {
        isDeleting = true
        
        do {
            try await authService.deletePost(postId: post.id)
            print("✅ Post deleted successfully")
            
            // Call the callback to refresh the posts list
            await MainActor.run {
                onPostDeleted?()
            }
        } catch {
            print("❌ Error deleting post: \(error)")
        }
        
        isDeleting = false
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
// MARK: - Profile Post Detail View
struct ProfilePostDetailView: View {
    let post: Post
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    @State private var currentImageIndex = 0
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Post header
                    HStack {
                        Circle()
                            .fill(Color.arkadGold.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(post.authorUsername.prefix(1)).uppercased())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.arkadGold)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(post.authorUsername)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(formatFullDate(post.createdAt))
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Post content
                    if !post.content.isEmpty {
                        Text(post.content)
                            .font(.body)
                            .lineSpacing(6)
                            .padding(.horizontal)
                    }
                    
                    // Images
                    if !post.imageUrls.isEmpty {
                        VStack(spacing: 12) {
                            TabView(selection: $currentImageIndex) {
                                ForEach(Array(post.imageUrls.enumerated()), id: \.offset) { index, imageUrl in
                                    AsyncImage(url: URL(string: imageUrl)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .arkadGold))
                                            )
                                    }
                                    .frame(height: 300)
                                    .clipped()
                                    .tag(index)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                            .frame(height: 300)
                            
                            if post.imageUrls.count > 1 {
                                Text("\(currentImageIndex + 1) of \(post.imageUrls.count)")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    
                    // Engagement stats
                    HStack(spacing: 24) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                                .foregroundColor(.red)
                            Text("\(post.likesCount)")
                                .fontWeight(.medium)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "message")
                                .foregroundColor(.blue)
                            Text("\(post.commentsCount)")
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationTitle("Post Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete") {
                        showDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                }
            }
            .confirmationDialog("Delete Post", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Post", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ProfileUserTradeCard: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: 12) {
            // Trade icon
            Image(systemName: trade.isOpen ? "circle" : "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(trade.isOpen ? .arkadGold : .marketGreen)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.ticker)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if trade.isOpen {
                        Text("OPEN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.arkadGold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.arkadGold.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text("\(trade.quantity) shares @ \(trade.entryPrice.asCurrency)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                
                Text(formatShortDate(trade.entryDate))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.arkadGold.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct TopPositionCard: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.marketGreen.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(trade.ticker.prefix(2))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.marketGreen)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trade.ticker)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Return: \(String(format: "%.1f", trade.profitLossPercentage))%")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.marketGreen)
                
                Text("\(trade.quantity) shares")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.marketGreen.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ProfileUserGroupCard: View {
    let group: TradingGroup
    
    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.arkadGold.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(group.name.prefix(2))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.arkadGold)
                )
            
            VStack(spacing: 4) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("\(group.memberCount) members")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                )
        )
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

// MARK: - View Models (Fixed compilation errors)
class UserPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let authService = FirebaseAuthService.shared
    private var currentUserId: String = ""
    
    func loadUserPosts(userId: String) {
        currentUserId = userId
        guard !userId.isEmpty else { return }
        
        isLoading = true
        errorMessage = "" // Clear previous errors
        
        Task {
            do {
                // Try the Firebase method first, fallback to workaround if index issue
                let userPosts: [Post]
                do {
                    userPosts = try await authService.getUserPosts(userId: userId)
                } catch {
                    print("Firebase getUserPosts failed, using workaround: \(error)")
                    // Fallback to workaround method
                    userPosts = try await getUserPostsWorkaround(userId: userId)
                }
                
                await MainActor.run {
                    self.posts = userPosts
                    self.isLoading = false
                    self.errorMessage = ""
                }
            } catch {
                await MainActor.run {
                    print("Error loading posts: \(error)")
                    self.errorMessage = "Failed to load posts. Please try again."
                    self.isLoading = false
                }
            }
        }
    }
    
    @MainActor
    func refreshPosts() async {
        guard !currentUserId.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        do {
            // Try the Firebase method first, fallback to workaround if index issue
            let userPosts: [Post]
            do {
                userPosts = try await authService.getUserPosts(userId: currentUserId)
            } catch {
                print("Firebase getUserPosts failed, using workaround: \(error)")
                // Fallback to workaround method
                userPosts = try await getUserPostsWorkaround(userId: currentUserId)
            }
            
            self.posts = userPosts
            self.errorMessage = ""
        } catch {
            print("Error refreshing posts: \(error)")
            self.errorMessage = "Failed to refresh posts. Please try again."
        }
        
        isLoading = false
    }
    
    // Workaround method using the public FirebaseServices methods
    private func getUserPostsWorkaround(userId: String) async throws -> [Post] {
        do {
            // Use FirebaseServices public method to get all feed posts, then filter
            let allPosts = try await FirebaseServices.shared.getFeedPosts(limit: 200)
            
            // Filter posts by the specific user
            let userPosts = allPosts.filter { $0.authorId == userId }
            
            // Sort locally by date (newest first)
            return userPosts.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("Error in getUserPostsWorkaround: \(error)")
            // If even the workaround fails, return empty array instead of throwing
            return []
        }
    }
}

class UserGroupsViewModel: ObservableObject {
    @Published var groups: [TradingGroup] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let authService = FirebaseAuthService.shared
    private var currentUserId: String = ""
    
    func loadUserGroups(userId: String) {
        currentUserId = userId
        guard !userId.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                // Try to get communities from Firebase using the public method
                let communities: [Community]
                do {
                    communities = try await authService.getUserCommunities(userId: userId)
                } catch {
                    print("Firebase getUserCommunities failed: \(error)")
                    // If the method doesn't exist or fails, return empty array
                    communities = []
                }
                
                // Convert communities to TradingGroup
                let tradingGroups = communities.map { community in
                    TradingGroup(
                        id: community.id,
                        name: community.name,
                        description: community.description,
                        memberCount: community.memberCount,
                        isPrivate: false, // You can add this field to Community model if needed
                        imageUrl: nil,
                        category: community.type.displayName,
                        createdAt: community.createdAt
                    )
                }
                
                await MainActor.run {
                    self.groups = tradingGroups
                    self.isLoading = false
                    self.errorMessage = ""
                }
            } catch {
                await MainActor.run {
                    print("Error loading groups: \(error)")
                    self.errorMessage = "Failed to load groups. Please try again."
                    self.isLoading = false
                }
            }
        }
    }
    
    @MainActor
    func refreshGroups() async {
        guard !currentUserId.isEmpty else { return }
        
        isLoading = true
        
        do {
            let communities: [Community]
            do {
                communities = try await authService.getUserCommunities(userId: currentUserId)
            } catch {
                print("Firebase getUserCommunities failed: \(error)")
                communities = []
            }
            
            let tradingGroups = communities.map { community in
                TradingGroup(
                    id: community.id,
                    name: community.name,
                    description: community.description,
                    memberCount: community.memberCount,
                    isPrivate: false,
                    imageUrl: nil,
                    category: community.type.displayName,
                    createdAt: community.createdAt
                )
            }
            
            self.groups = tradingGroups
            self.errorMessage = ""
        } catch {
            print("Error refreshing groups: \(error)")
            self.errorMessage = "Failed to refresh groups. Please try again."
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Models
struct TradingGroup: Identifiable {
    let id: String
    let name: String
    let description: String
    let memberCount: Int
    let isPrivate: Bool
    let imageUrl: String?
    let category: String
    let createdAt: Date
}

#Preview {
    ProfileView()
        .environmentObject(FirebaseAuthService.shared)
}
