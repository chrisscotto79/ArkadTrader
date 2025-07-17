// File: Core/Home/Views/Main/HomeView.swift
// Main HomeView orchestrating all tabs and functionality

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var selectedTab: HomeFeedTab = .feed
    @State private var lastTappedTab: HomeFeedTab = .feed
    @State private var lastTapTime: Date = Date()
    
    enum HomeFeedTab: String, CaseIterable {
        case feed = "Feed"
        case following = "Following"
        case marketNews = "Market News"
        
        var icon: String {
            switch self {
            case .feed: return "house.fill"
            case .following: return "person.2.fill"
            case .marketNews: return "newspaper.fill"
            }
        }
        
        var activeIcon: String {
            switch self {
            case .feed: return "house.fill"
            case .following: return "person.2.fill"
            case .marketNews: return "newspaper.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header section
                headerSection
                
                // Tab content
                tabContent
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .overlay(alignment: .bottomTrailing) {
                createPostButton
            }
        }
        .environmentObject(homeViewModel)
        .sheet(isPresented: $homeViewModel.showingCreatePost) {
            CreatePostView()
                .environmentObject(authService)
                .environmentObject(homeViewModel)
        }
        .sheet(isPresented: $homeViewModel.showingPostDetail) {
            if let selectedPost = homeViewModel.selectedPost {
                PostDetailView(post: selectedPost)
                    .environmentObject(authService)
                    .environmentObject(homeViewModel)
            }
        }
        .sheet(isPresented: $homeViewModel.showingUserProfile) {
            if let selectedUser = homeViewModel.selectedUser {
                OtherUserProfileView(user: selectedUser)
                    .environmentObject(authService)
            }
        }
        .sheet(isPresented: $homeViewModel.showingNotifications) {
            NotificationsView()
                .environmentObject(authService)
                .environmentObject(homeViewModel)
        }
        .onAppear {
            Task {
                await homeViewModel.loadInitialData()
            }
        }
        .alert("Error", isPresented: $homeViewModel.showError) {
            Button("OK") { homeViewModel.showError = false }
        } message: {
            Text(homeViewModel.errorMessage)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Top header with logo and actions
            topHeader
            
            // Search bar (when active)
            if !homeViewModel.searchQuery.isEmpty {
                searchBar
            }
            
            // Tab selector
            tabSelector
        }
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Top Header
    private var topHeader: some View {
        HStack {
            // App logo/title
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.title2)
                    .foregroundColor(.arkadGold)
                
                Text("Arkad")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                // Search button
                Button(action: {
                    // TODO: Implement search functionality
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                // Notifications button
                Button(action: {
                    homeViewModel.showingNotifications = true
                }) {
                    ZStack {
                        Image(systemName: "bell")
                            .font(.title3)
                            .foregroundColor(.primary)
                        
                        // Notification badge
                        if homeViewModel.hasUnreadNotifications {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                
                // Profile button
                Button(action: {
                    // TODO: Navigate to current user profile
                }) {
                    AsyncImage(url: URL(string: authService.currentUser?.profileImageUrl ?? "https://avatar.iran.liara.run/username?username=\(authService.currentUser?.username ?? "user")")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.arkadGold.opacity(0.2))
                            .overlay(
                                Text(String(authService.currentUser?.username.prefix(1) ?? "U").uppercased())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.arkadGold)
                            )
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search posts, users, tickers...", text: $homeViewModel.searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !homeViewModel.searchQuery.isEmpty {
                    Button(action: {
                        homeViewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            
            Button("Cancel") {
                homeViewModel.clearSearch()
            }
            .font(.subheadline)
            .foregroundColor(.arkadGold)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(HomeFeedTab.allCases, id: \.self) { tab in
                Button(action: {
                    handleTabTap(tab)
                }) {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .medium)
                            .foregroundColor(selectedTab == tab ? .arkadGold : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.arkadGold : Color.clear)
                            .frame(height: 2)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Tab Content
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .feed:
            FeedTabView()
                .environmentObject(authService)
                .environmentObject(homeViewModel)
        case .following:
            FollowingTabView()
                .environmentObject(authService)
                .environmentObject(homeViewModel)
        case .marketNews:
            MarketNewsTabView()
                .environmentObject(homeViewModel)
        }
    }
    
    // MARK: - Create Post Button
    private var createPostButton: some View {
        Button(action: {
            withAnimation(.spring()) {
                homeViewModel.showCreatePost()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.arkadGold)
                    .frame(width: 56, height: 56)
                    .shadow(color: .arkadGold.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100) // Account for tab bar
    }
    
    // MARK: - Helper Methods
    private func handleTabTap(_ tab: HomeFeedTab) {
        let now = Date()
        
        // Check for double tap (scroll to top)
        if lastTappedTab == tab && now.timeIntervalSince(lastTapTime) < 0.5 {
            // Double tap detected - scroll to top
            homeViewModel.scrollToTop()
        }
        
        // Update selected tab
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedTab = tab
        }
        
        // Update tracking variables
        lastTappedTab = tab
        lastTapTime = now
    }
}

// MARK: - Notifications View
struct NotificationsView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if homeViewModel.notifications.isEmpty {
                    EmptyNotificationsView()
                } else {
                    List {
                        ForEach(homeViewModel.notifications, id: \.id) { notification in
                            NotificationRowView(notification: notification)
                                .environmentObject(homeViewModel)
                                .onTapGesture {
                                    handleNotificationTap(notification)
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !homeViewModel.notifications.isEmpty {
                        Button("Mark All Read") {
                            Task {
                                await homeViewModel.markAllNotificationsAsRead()
                            }
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await homeViewModel.loadNotifications()
            }
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        Task {
            // Mark as read
            if !notification.isRead {
                await homeViewModel.markNotificationAsRead(notificationId: notification.id)
            }
            
            // Navigate based on notification type
            switch notification.type {
            case .like, .comment, .reply:
                if let postId = notification.relatedPostId,
                   let post = homeViewModel.posts.first(where: { $0.id == postId }) {
                    homeViewModel.showPostDetail(post: post)
                }
            case .follow, .mention:
                if let userId = notification.relatedUserId {
                    homeViewModel.showUserProfile(userId: userId)
                }
            case .tradeAlert, .marketNews:
                // Handle other notification types
                break
            }
            
            dismiss()
        }
    }
}

// MARK: - Notification Row View
struct NotificationRowView: View {
    let notification: AppNotification
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Notification icon
            ZStack {
                Circle()
                    .fill(notificationColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: notification.type.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(notificationColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(formatTimeAgo(notification.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !notification.isRead {
                Circle()
                    .fill(Color.arkadGold)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .background(notification.isRead ? Color.clear : Color.arkadGold.opacity(0.05))
    }
    
    private var notificationColor: Color {
        switch notification.type.color {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "arkadGold": return .arkadGold
        default: return .gray
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Empty Notifications View
struct EmptyNotificationsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell")
                .font(.system(size: 50))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            Text("No Notifications")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("You're all caught up! Notifications for likes, comments, and follows will appear here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Other User Profile View (Placeholder)
struct OtherUserProfileView: View {
    let user: User
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Profile header
                VStack(spacing: 16) {
                    AsyncImage(url: URL(string: user.profileImageUrl ?? "https://avatar.iran.liara.run/username?username=\(user.username)")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.arkadGold.opacity(0.2))
                            .overlay(
                                Text(String(user.username.prefix(1)).uppercased())
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.arkadGold)
                            )
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    
                    VStack(spacing: 4) {
                        Text("@\(user.username)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let bio = user.bio {
                            Text(bio)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Follow button
                    FollowButton(userId: user.id, username: user.username)
                        .environmentObject(authService)
                }
                .padding()
                
                Spacer()
                
                Text("User profile content coming soon...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Follow Button (Placeholder)
struct FollowButton: View {
    let userId: String
    let username: String
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isFollowing = false
    @State private var isLoading = false
    
    var body: some View {
        Button(action: {
            toggleFollow()
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Text(isFollowing ? "Following" : "Follow")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(isFollowing ? .primary : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isFollowing ? Color.secondary.opacity(0.2) : Color.arkadGold)
            )
        }
        .disabled(isLoading)
        .onAppear {
            checkFollowStatus()
        }
    }
    
    private func checkFollowStatus() {
        // TODO: Check if current user follows this user
        // isFollowing = ...
    }
    
    private func toggleFollow() {
        isLoading = true
        
        Task {
            do {
                if isFollowing {
                    // TODO: Implement unfollow
                    // try await authService.unfollowUser(userId: userId)
                } else {
                    // TODO: Implement follow
                    // try await authService.followUser(userId: userId)
                }
                
                await MainActor.run {
                    isFollowing.toggle()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}
