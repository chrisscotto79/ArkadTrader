//
//  SearchResultView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/9/25.
//


// File: Core/Search/Views/SearchResultView.swift
// Search Result View Component with proper navigation

import SwiftUI

struct SearchResultView: View {
    let result: SearchResult
    @State private var showUserProfile = false
    @State private var showCommunityDetail = false
    @State private var showTradeDetail = false
    @State private var showPostDetail = false
    
    var body: some View {
        Button(action: handleResultTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(result.type.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: result.type.icon)
                        .font(.title3)
                        .foregroundColor(result.type.color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryText)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(secondaryText)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            NavigationLink(
                destination: destinationView,
                isActive: navigationBinding,
                label: { EmptyView() }
            )
            .hidden()
        )
    }
    
    private var primaryText: String {
        switch result.type {
        case .user:
            return result.user?.fullName ?? "Unknown User"
        case .post:
            return result.post?.content ?? "Post"
        case .trade:
            return result.trade?.ticker ?? "Trade"
        case .group:
            return result.community?.name ?? "Group"
        }
    }
    
    private var secondaryText: String {
        switch result.type {
        case .user:
            return "@\(result.user?.username ?? "username")"
        case .post:
            return "by @\(result.post?.authorUsername ?? "unknown")"
        case .trade:
            let trade = result.trade
            return trade?.isOpen ?? true ? "Open Position" : "Closed Position"
        case .group:
            return "\(result.community?.memberCount ?? 0) members"
        }
    }
    
    private func handleResultTap() {
        switch result.type {
        case .user:
            showUserProfile = true
        case .post:
            showPostDetail = true
        case .trade:
            showTradeDetail = true
        case .group:
            showCommunityDetail = true
        }
    }
    
    private var navigationBinding: Binding<Bool> {
        switch result.type {
        case .user:
            return $showUserProfile
        case .post:
            return $showPostDetail
        case .trade:
            return $showTradeDetail
        case .group:
            return $showCommunityDetail
        }
    }
    
    @ViewBuilder
    private var destinationView: some View {
        switch result.type {
        case .user:
            if let user = result.user {
                UserProfileView(userId: user.id)
            }
        case .post:
            if let post = result.post {
                PostDetailView(post: post)
            }
        case .trade:
            if let trade = result.trade {
                TradeDetailView(trade: trade)
            }
        case .group:
            if let community = result.community {
                CommunityDetailView(community: community)
            }
        }
    }
}

// MARK: - User Profile View for Navigation
struct UserProfileView: View {
    let userId: String
    @StateObject private var viewModel = UserProfileViewModel()
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                ProfileHeaderView(user: viewModel.user)
                
                // Stats
                if let user = viewModel.user {
                    UserStatsView(user: user)
                }
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Activity")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if viewModel.userPosts.isEmpty {
                        Text("No posts yet")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(viewModel.userPosts) { post in
                            PostRowView(post: post)
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.user?.id != authService.currentUser?.id {
                    Button(viewModel.isFollowing ? "Following" : "Follow") {
                        viewModel.toggleFollow()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(viewModel.isFollowing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
            }
        }
        .onAppear {
            viewModel.loadUser(userId: userId)
        }
    }
}

// Simple view models for the profile
@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var userPosts: [Post] = []
    @Published var isFollowing = false
    
    private let authService = FirebaseAuthService.shared
    
    func loadUser(userId: String) {
        Task {
            do {
                self.user = try await authService.getUserById(userId: userId)
                self.userPosts = try await authService.getUserPosts(userId: userId)
                
                // Check if following
                if let currentUserId = authService.currentUser?.id {
                    let following = try await authService.getUserFollowing(userId: currentUserId)
                    self.isFollowing = following.contains(userId)
                }
            } catch {
                print("Error loading user: \(error)")
            }
        }
    }
    
    func toggleFollow() {
        guard let userId = user?.id,
              let currentUserId = authService.currentUser?.id else { return }
        
        Task {
            do {
                if isFollowing {
                    try await authService.unfollowUser(userId: userId, followerId: currentUserId)
                } else {
                    try await authService.followUser(userId: userId, followerId: currentUserId)
                }
                isFollowing.toggle()
            } catch {
                print("Error toggling follow: \(error)")
            }
        }
    }
}

// Placeholder views for other destinations
struct PostDetailView: View {
    let post: Post
    var body: some View {
        Text("Post Detail: \(post.content)")
    }
}

struct TradeDetailView: View {
    let trade: Trade
    var body: some View {
        Text("Trade Detail: \(trade.ticker)")
    }
}

struct CommunityDetailView: View {
    let community: Community
    var body: some View {
        Text("Community: \(community.name)")
    }
}

// Helper views
struct ProfileHeaderView: View {
    let user: User?
    
    var body: some View {
        VStack(spacing: 12) {
            // Profile picture
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(user?.fullName.prefix(1).uppercased() ?? "?")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                )
            
            // Name and username
            VStack(spacing: 4) {
                Text(user?.fullName ?? "Loading...")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("@\(user?.username ?? "...")")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // Bio
            if let bio = user?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

struct UserStatsView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 40) {
            StatColumn(value: "\(user.followersCount)", label: "Followers")
            StatColumn(value: "\(user.followingCount)", label: "Following")
            StatColumn(value: "\(user.postsCount)", label: "Posts")
        }
        .padding()
    }
}

struct StatColumn: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct PostRowView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.content)
                .font(.subheadline)
                .lineLimit(3)
            
            HStack {
                Label("\(post.likeCount)", systemImage: "heart")
                Label("\(post.commentCount)", systemImage: "bubble.right")
                Spacer()
                Text(post.createdAt.timeAgoDisplay())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// Extension for time ago display
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}