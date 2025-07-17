// File: Core/Home/Views/Main/FollowingTabView.swift
// Following tab with posts from followed users and activity feed

import SwiftUI

struct FollowingTabView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var showSuggestedUsers = false
    @State private var selectedActivityFilter: ActivityFilter = .all
    @State private var scrollToTopId = UUID()
    
    enum ActivityFilter: String, CaseIterable {
        case all = "All"
        case posts = "Posts"
        case trades = "Trades"
        case interactions = "Interactions"
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .posts: return "doc.text"
            case .trades: return "chart.line.uptrend.xyaxis"
            case .interactions: return "heart"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Following stats and suggested users header
            if homeViewModel.followingPosts.isEmpty && !homeViewModel.isLoadingFollowing {
                suggestedUsersHeader
            } else {
                followingStatsHeader
            }
            
            // Activity filter (when following posts exist)
            if !homeViewModel.followingPosts.isEmpty {
                activityFilterBar
            }
            
            // Main content
            followingContent
        }
        .refreshable {
            await homeViewModel.refreshFollowingFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToTop"))) { _ in
            withAnimation {
                scrollToTopId = UUID()
            }
        }
    }
    
    // MARK: - Following Stats Header
    private var followingStatsHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Following Feed")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("\(homeViewModel.followingPosts.count) posts from people you follow")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showSuggestedUsers = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                            .font(.caption)
                        Text("Discover")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.arkadGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
        .sheet(isPresented: $showSuggestedUsers) {
            SuggestedUsersView()
                .environmentObject(authService)
                .environmentObject(homeViewModel)
        }
    }
    
    // MARK: - Suggested Users Header
    private var suggestedUsersHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Discover Traders")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {
                    showSuggestedUsers = true
                }
                .font(.subheadline)
                .foregroundColor(.arkadGold)
            }
            .padding(.horizontal, 16)
            
            // Quick suggested users
            SuggestedUsersCarousel()
                .environmentObject(authService)
                .environmentObject(homeViewModel)
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
        .sheet(isPresented: $showSuggestedUsers) {
            SuggestedUsersView()
                .environmentObject(authService)
                .environmentObject(homeViewModel)
        }
    }
    
    // MARK: - Activity Filter Bar
    private var activityFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ActivityFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedActivityFilter == filter
                    ) {
                        selectedActivityFilter = filter
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Following Content
    private var followingContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Scroll to top anchor
                    Color.clear
                        .frame(height: 1)
                        .id(scrollToTopId)
                    
                    if homeViewModel.isLoadingFollowing && homeViewModel.followingPosts.isEmpty {
                        LoadingView(message: "Loading following feed...")
                            .padding(.top, 50)
                    } else if homeViewModel.followingPosts.isEmpty {
                        EmptyFollowingView()
                            .padding(.top, 30)
                    } else {
                        // Mixed content feed based on filter
                        ForEach(filteredFollowingContent, id: \.id) { item in
                            switch item {
                            case .post(let post):
                                PostCard(post: post)
                                    .environmentObject(authService)
                                    .environmentObject(homeViewModel)
                            case .activity(let activity):
                                ActivityCardView(activity: activity)
                                    .environmentObject(homeViewModel)
                            }
                        }
                        
                        // Load more button
                        if homeViewModel.hasMoreFollowingPosts {
                            LoadMoreButton {
                                Task {
                                    await homeViewModel.loadMoreFollowingPosts()
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Loading more indicator
                        if homeViewModel.isLoadingMore {
                            LoadingMoreView()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 100) // Space for tab bar and floating button
            }
            .onChange(of: scrollToTopId) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(scrollToTopId, anchor: .top)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var filteredFollowingContent: [FollowingContentItem] {
        var items: [FollowingContentItem] = []
        
        // Add posts based on filter
        switch selectedActivityFilter {
        case .all:
            items.append(contentsOf: homeViewModel.followingPosts.map { .post($0) })
            items.append(contentsOf: homeViewModel.followingActivities.map { .activity($0) })
        case .posts:
            let textPosts = homeViewModel.followingPosts.filter { $0.postType == .text || $0.postType == .question }
            items.append(contentsOf: textPosts.map { .post($0) })
        case .trades:
            let tradePosts = homeViewModel.followingPosts.filter { $0.postType == .tradeResult }
            items.append(contentsOf: tradePosts.map { .post($0) })
            
            let tradeActivities = homeViewModel.followingActivities.filter {
                $0.activityType == .newTrade || $0.activityType == .tradeClosed
            }
            items.append(contentsOf: tradeActivities.map { .activity($0) })
        case .interactions:
            let interactionActivities = homeViewModel.followingActivities.filter {
                $0.activityType == .likedPost || $0.activityType == .commentedOnPost || $0.activityType == .followedUser
            }
            items.append(contentsOf: interactionActivities.map { .activity($0) })
        }
        
        // Sort by timestamp
        return items.sorted { item1, item2 in
            switch (item1, item2) {
            case (.post(let post1), .post(let post2)):
                return post1.createdAt > post2.createdAt
            case (.activity(let activity1), .activity(let activity2)):
                return activity1.timestamp > activity2.timestamp
            case (.post(let post), .activity(let activity)):
                return post.createdAt > activity.timestamp
            case (.activity(let activity), .post(let post)):
                return activity.timestamp > post.createdAt
            }
        }
    }
}

// MARK: - Following Content Item
enum FollowingContentItem: Identifiable {
    case post(Post)
    case activity(FollowingActivity)
    
    var id: String {
        switch self {
        case .post(let post):
            return "post_\(post.id)"
        case .activity(let activity):
            return "activity_\(activity.id)"
        }
    }
}

// MARK: - Activity Card View
struct ActivityCardView: View {
    let activity: FollowingActivity
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    var body: some View {
        Button(action: {
            handleActivityTap()
        }) {
            HStack(spacing: 12) {
                // Activity type icon
                ZStack {
                    Circle()
                        .fill(activityColor.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: activity.activityType.icon)
                        .foregroundColor(activityColor)
                        .font(.system(size: 16, weight: .medium))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("@\(activity.username)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(activity.activityType.description)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(formatTimeAgo(activity.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let content = activity.content {
                        Text(content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var activityColor: Color {
        switch activity.activityType {
        case .newPost: return .blue
        case .newTrade: return .green
        case .tradeClosed: return .orange
        case .likedPost: return .red
        case .commentedOnPost: return .purple
        case .followedUser: return .arkadGold
        }
    }
    
    private func handleActivityTap() {
        if let postId = activity.relatedPostId,
           let post = homeViewModel.posts.first(where: { $0.id == postId }) {
            homeViewModel.showPostDetail(post: post)
        } else {
            homeViewModel.showUserProfile(userId: activity.userId)
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Suggested Users Carousel
struct SuggestedUsersCarousel: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var suggestedUsers: [User] = []
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if suggestedUsers.isEmpty {
                    // Placeholder suggested users
                    ForEach(1...5, id: \.self) { index in
                        SuggestedUserCard(
                            user: User(
                                id: "suggested_\(index)",
                                username: "trader\(index)",
                                email: "trader\(index)@example.com",
                                bio: "Experienced trader specializing in swing trading and market analysis.",
                                profileImageUrl: nil
                            )
                        )
                        .environmentObject(authService)
                    }
                } else {
                    ForEach(suggestedUsers, id: \.id) { user in
                        SuggestedUserCard(user: user)
                            .environmentObject(authService)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            loadSuggestedUsers()
        }
    }
    
    private func loadSuggestedUsers() {
        Task {
            suggestedUsers = await homeViewModel.getSuggestedUsers()
        }
    }
}

// MARK: - Suggested User Card
struct SuggestedUserCard: View {
    let user: User
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isFollowing = false
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Profile avatar
            Button(action: {
                // Navigate to user profile
            }) {
                AsyncImage(url: URL(string: user.profileImageUrl ?? "https://avatar.iran.liara.run/username?username=\(user.username)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.arkadGold.opacity(0.2))
                        .overlay(
                            Text(String(user.username.prefix(1)).uppercased())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadGold)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(spacing: 4) {
                Text("@\(user.username)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let bio = user.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                
                // Mock follower count
                Text("\(Int.random(in: 100...1000)) followers")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
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
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .foregroundColor(isFollowing ? .secondary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isFollowing ? Color.secondary.opacity(0.2) : Color.arkadGold)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLoading)
        }
        .frame(width: 140)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func toggleFollow() {
        isLoading = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring()) {
                isFollowing.toggle()
                isLoading = false
            }
        }
        
        // TODO: Implement actual follow/unfollow logic
        // Task {
        //     do {
        //         if isFollowing {
        //             try await authService.unfollowUser(userId: user.id)
        //         } else {
        //             try await authService.followUser(userId: user.id)
        //         }
        //         await MainActor.run {
        //             isFollowing.toggle()
        //             isLoading = false
        //         }
        //     } catch {
        //         await MainActor.run {
        //             isLoading = false
        //         }
        //     }
        // }
    }
}

// MARK: - Empty Following View
struct EmptyFollowingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 50))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            Text("No Following Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Follow other traders to see their latest posts and trades here. Discover traders by browsing the main feed or using search.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                // TODO: Navigate to discover users or main feed
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .font(.subheadline)
                    Text("Discover Traders")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.arkadGold)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Suggested Users View (Full Screen)
struct SuggestedUsersView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var suggestedUsers: [User] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Finding great traders to follow...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if suggestedUsers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3")
                            .font(.system(size: 50))
                            .foregroundColor(.arkadGold.opacity(0.6))
                        
                        Text("No Suggestions")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("We'll suggest traders as more users join the platform.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(suggestedUsers, id: \.id) { user in
                                SuggestedUserCard(user: user)
                                    .environmentObject(authService)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Discover Traders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSuggestedUsers()
        }
    }
    
    private func loadSuggestedUsers() {
        Task {
            // Simulate loading
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            let mockUsers = (1...10).map { index in
                User(
                    id: "suggested_\(index)",
                    username: "trader\(index)",
                    email: "trader\(index)@example.com",
                    bio: "Experienced trader specializing in \(["swing trading", "day trading", "options", "crypto", "forex"].randomElement()!) and market analysis.",
                    profileImageUrl: nil
                )
            }
            
            await MainActor.run {
                suggestedUsers = mockUsers
                isLoading = false
            }
        }
    }
}
