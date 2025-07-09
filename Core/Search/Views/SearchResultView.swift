// File: Core/Search/Views/SearchResultView.swift
// Clean Search Result View without conflicting dependencies

import SwiftUI

struct SearchResultView: View {
    let result: SearchResult
    @State private var showDetail = false
    
    var body: some View {
        Button(action: { showDetail = true }) {
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
        .sheet(isPresented: $showDetail) {
            NavigationView {
                destinationView
                    .navigationBarTitle("Details", displayMode: .inline)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showDetail = false }
                        }
                    }
            }
        }
    }
    
    // MARK: - Content Properties
    
    private var primaryText: String {
        switch result.type {
        case .user:
            return result.user?.fullName ?? "Unknown User"
        case .post:
            return String(result.post?.content.prefix(50) ?? "Post")
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
    
    // MARK: - Destination Views
    
    @ViewBuilder
    private var destinationView: some View {
        switch result.type {
        case .user:
            if let user = result.user {
                SimpleUserProfileView(user: user)
            } else {
                Text("User not found")
            }
        case .post:
            if let post = result.post {
                SimplePostDetailView(post: post)
            } else {
                Text("Post not found")
            }
        case .trade:
            if let trade = result.trade {
                SimpleTradeDetailView(trade: trade)
            } else {
                Text("Trade not found")
            }
        case .group:
            if let community = result.community {
                SimpleCommunityDetailView(community: community)
            } else {
                Text("Community not found")
            }
        }
    }
}

// MARK: - Simple Detail Views

struct SimpleUserProfileView: View {
    let user: User
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isFollowing = false
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(user.fullName.prefix(1).uppercased())
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                        )
                    
                    Text(user.fullName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Stats
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("\(user.followersCount)")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Followers")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack(spacing: 4) {
                        Text("\(user.followingCount)")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Following")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f%%", user.winRate))
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Win Rate")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                // Follow Button (if not current user)
                if user.id != authService.currentUser?.id {
                    Button(action: toggleFollow) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isFollowing ? "Following" : "Follow")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(isFollowing ? Color.gray : Color.blue)
                        .cornerRadius(20)
                    }
                    .disabled(isLoading)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            checkFollowingStatus()
        }
    }
    
    private func checkFollowingStatus() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        Task {
            do {
                let following = try await authService.getUserFollowing(userId: currentUserId)
                await MainActor.run {
                    isFollowing = following.contains(user.id)
                }
            } catch {
                print("Error checking follow status: \(error)")
            }
        }
    }
    
    private func toggleFollow() {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        isLoading = true
        Task {
            do {
                if isFollowing {
                    try await authService.unfollowUser(userId: user.id, followerId: currentUserId)
                } else {
                    try await authService.followUser(userId: user.id, followerId: currentUserId)
                }
                
                await MainActor.run {
                    isFollowing.toggle()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
                print("Error toggling follow: \(error)")
            }
        }
    }
}

struct SimplePostDetailView: View {
    let post: Post
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Author info
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(post.authorUsername.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("@\(post.authorUsername)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(post.createdAt.timeAgoDisplay)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                
                // Post content
                Text(post.content)
                    .font(.body)
                
                // Post stats
                HStack(spacing: 20) {
                    Label("\(post.likesCount)", systemImage: "heart")
                        .foregroundColor(.red)
                    
                    Label("\(post.commentsCount)", systemImage: "bubble.right")
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
                .font(.caption)
                
                Spacer()
            }
            .padding()
        }
    }
}

struct SimpleTradeDetailView: View {
    let trade: Trade
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Trade header
                HStack {
                    Text(trade.ticker)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text(trade.isOpen ? "OPEN" : "CLOSED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(trade.isOpen ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                // Trade details
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(label: "Type", value: trade.tradeType.displayName)
                    DetailRow(label: "Entry Price", value: "$\(String(format: "%.2f", trade.entryPrice))")
                    DetailRow(label: "Quantity", value: "\(trade.quantity)")
                    DetailRow(label: "Entry Date", value: trade.formattedEntryDate)
                    
                    if let notes = trade.notes {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.headline)
                            Text(notes)
                                .font(.body)
                        }
                    }
                    
                    if !trade.isOpen {
                        DetailRow(label: "P&L", value: String(format: "%.2f%%", trade.profitLossPercentage))
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct SimpleCommunityDetailView: View {
    let community: Community
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Community header
                VStack(alignment: .leading, spacing: 8) {
                    Text(community.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(community.description)
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Text("\(community.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Helper Views

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}
