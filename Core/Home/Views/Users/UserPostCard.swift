// File: Core/Home/Views/UserPostCard.swift
// Enhanced User Post Card with Clickable Profile Navigation

import SwiftUI

struct UserPostCard: View {
    let post: Post
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    @State private var debugMessage = ""
    @State private var showComments = false

    
    @EnvironmentObject var authService: FirebaseAuthService
    
    init(post: Post, homeViewModel: HomeViewModel) {
        self.post = post
        self.homeViewModel = homeViewModel
        
        
    }
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            // User Header - CLICKABLE with Debug
            Button(action: {
                print("🔴 Profile button tapped for: \(post.authorUsername)")
                handleProfileTap()
            }
            ) {
                HStack(spacing: 12) {
                    // Profile Avatar - Clickable
                    ZStack {
                        Circle()
                            .fill(Color.arkadGold.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(post.authorUsername.prefix(1)).uppercased())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.arkadGold)
                            )
                        
                        if isLoadingUser {
                            ProgressView()
                                .scaleEffect(0.6)
                                .foregroundColor(.arkadGold)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // Username - Clickable with tap indicator
                        HStack {
                            Text("@\(post.authorUsername)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            // Debug indicator
                            if !debugMessage.isEmpty {
                                Text(debugMessage)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Text(formatDate(post.createdAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Tap indicator
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            
                
            .buttonStyle(PlainButtonStyle())
            
            // Post type badge (if not text)
            if post.postType != .text {
                HStack {
                    Spacer()
                    Text(post.postType.displayName)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(postTypeColor(for: post.postType))
                        .cornerRadius(8)
                }
            }
            
            // Post Content
            Text(post.content)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.primary)
            
            // Engagement Section
            HStack(spacing: 24) {
                // Like button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        homeViewModel.toggleLike(for: post.id)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: homeViewModel.likedPosts.contains(post.id) ? "heart.fill" : "heart")
                            .foregroundColor(homeViewModel.likedPosts.contains(post.id) ? .red : .gray)
                        
                        Text("\(post.likesCount)")  // ✅ Just the actual count
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(homeViewModel.likedPosts.contains(post.id) ? .red : .gray)
                    }
                }
                
                // Comment button
                // Comment button
                Button(action: {
                    showComments = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "message")
                            .foregroundColor(.gray)
                        
                        Text("\(post.commentsCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                    }
                }
                
                // Share button
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.gray)
                        
                        Text("Share")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Bookmark button
                Button(action: {
                    homeViewModel.toggleBookmark(for: post.id)
                }) {
                    Image(systemName: homeViewModel.bookmarkedPosts.contains(post.id) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(homeViewModel.bookmarkedPosts.contains(post.id) ? .arkadGold : .gray)
                }
            }
            .font(.subheadline)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showOtherUserProfile) {
            if let profileUser = profileUser {
                OtherUserProfileView(user: profileUser)
                    .environmentObject(authService)
            } else {
                // Fallback view if user loading failed
                VStack(spacing: 20) {
                    Text("Unable to load profile")
                        .font(.headline)
                    
                    Text("User: @\(post.authorUsername)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Dismiss") {
                        showOtherUserProfile = false
                    }
                    .foregroundColor(.blue)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsView(
                postId: post.id,
                onCommentCountChanged: { newCount in
                    // Update the post's comment count locally
                    homeViewModel.updatePostCommentCount(postId: post.id, newCount: newCount)
                }
            )
            .environmentObject(authService)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        
        .onAppear {
            // Debug info on appear
            debugMessage = authService.isAuthenticated ? "✓" : "✗"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                debugMessage = ""
            }
        }
    }
    
    // MARK: - Profile Navigation Logic
    
    private func handleProfileTap() {
        print("🔄 handleProfileTap() called")
        print("📋 Post Author ID: \(post.authorId)")
        print("👤 Post Author Username: \(post.authorUsername)")
        print("🔐 Auth Service Current User: \(authService.currentUser?.id ?? "nil")")
        print("✅ Is Authenticated: \(authService.isAuthenticated)")
        
        debugMessage = "Loading..."
        
        // Check if this is the current user's post
        if let currentUser = authService.currentUser,
           currentUser.id == post.authorId {
            print("👤 User tapped their own profile - not opening modal")
            debugMessage = "Your post"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                debugMessage = ""
            }
            return
        }
        
        // Load other user's profile
        Task {
            await loadUserProfile()
        }
    }
    
    private func loadUserProfile() async {
        print("🔄 loadUserProfile() started")
        
        guard profileUser == nil else {
            print("✅ Profile already loaded, showing modal")
            await MainActor.run {
                showOtherUserProfile = true
                debugMessage = ""
            }
            return
        }
        
        await MainActor.run {
            isLoadingUser = true
            debugMessage = "Loading..."
        }
        
        do {
            print("🔍 Fetching user by ID: \(post.authorId)")
            
            if let user = try await authService.getUserById(userId: post.authorId) {
                print("✅ User found: \(user.username)")
                await MainActor.run {
                    profileUser = user
                    isLoadingUser = false
                    debugMessage = "Found!"
                    showOtherUserProfile = true
                }
            } else {
                print("⚠️ User not found, creating minimal user")
                await MainActor.run {
                    profileUser = createMinimalUser()
                    isLoadingUser = false
                    debugMessage = "Minimal"
                    showOtherUserProfile = true
                }
            }
        } catch {
            print("❌ Error loading user profile: \(error)")
            
            await MainActor.run {
                profileUser = createMinimalUser()
                isLoadingUser = false
                debugMessage = "Error"
                showOtherUserProfile = true
            }
        }
        
        // Clear debug message after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            debugMessage = ""
        }
    }
    
    private func createMinimalUser() -> User {
        print("🔨 Creating minimal user for: \(post.authorUsername)")
        
        var user = User(
            id: post.authorId,
            email: "\(post.authorUsername)@example.com",
            username: post.authorUsername,
            fullName: post.authorUsername.capitalized
        )
        
        user.bio = "Trader on ArkadTrader"
        user.followersCount = 0
        user.followingCount = 0
        user.totalProfitLoss = 0.0
        user.winRate = 0.0
        
        return user
    }
    
    // MARK: - Helper Methods
    
    private func postTypeColor(for type: PostType) -> Color {
        switch type {
        case .text: return .clear
        case .tradeResult: return .green
        case .marketAnalysis: return .blue
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    let samplePost = Post(content: "Just made a great trade on AAPL! 📈", authorId: "1", authorUsername: "trader1")
    
    UserPostCard(post: samplePost, homeViewModel: HomeViewModel())
        .padding()
        .environmentObject(FirebaseAuthService.shared)
}
