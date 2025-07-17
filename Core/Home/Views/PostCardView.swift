//
//  PostCardView.swift
//  ArkadTrader
//
//  Enhanced with clickable profile navigation
//

import SwiftUI

struct PostCardView: View {
    let post: Post
    @State private var isLiked = false
    @State private var showComments = false
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - NOW CLICKABLE
            Button(action: {
                handleProfileTap()
            }) {
                HStack {
                    ZStack {
                        AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(post.authorUsername)")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Text(String(post.authorUsername.prefix(1)).uppercased())
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        if isLoadingUser {
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("@\(post.authorUsername)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Post type badge
            HStack {
                Spacer()
                Text(post.postType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(postTypeColor.opacity(0.1))
                    .foregroundColor(postTypeColor)
                    .cornerRadius(12)
            }
            
            // Content
            Text(post.content)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // Action buttons
            HStack {
                Button(action: {
                    withAnimation(.spring()) {
                        isLiked.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                        Text("\(post.likesCount + (isLiked ? 1 : 0))")
                            .font(.caption)
                    }
                }
                
                Button(action: {
                    showComments.toggle()
                }) {
                    HStack {
                        Image(systemName: "message")
                            .foregroundColor(.gray)
                        Text("\(post.commentsCount)")
                            .font(.caption)
                    }
                }
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.gray)
                        Text("Share")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "bookmark")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showOtherUserProfile) {
            if let profileUser = profileUser {
                OtherUserProfileView(user: profileUser)
                    .environmentObject(authService)
            }
        }
    }
    
    // MARK: - Profile Navigation Logic
    
    private func handleProfileTap() {
        // Check if this is the current user's post
        if let currentUser = authService.currentUser,
           currentUser.id == post.authorId {
            // Don't open modal for current user - they can use the Profile tab
            print("👤 Tapped own profile - user should use Profile tab")
            return
        }
        
        // Load other user's profile
        Task {
            await loadUserProfile()
        }
    }
    
    private func loadUserProfile() async {
        guard profileUser == nil else {
            // Already loaded, just show the profile
            await MainActor.run {
                showOtherUserProfile = true
            }
            return
        }
        
        await MainActor.run {
            isLoadingUser = true
        }
        
        do {
            // Try to get user by ID first (most reliable)
            if let user = try await authService.getUserById(userId: post.authorId) {
                await MainActor.run {
                    profileUser = user
                    isLoadingUser = false
                    showOtherUserProfile = true
                }
            } else {
                // Fallback: create a minimal user from post data
                await MainActor.run {
                    profileUser = createMinimalUser()
                    isLoadingUser = false
                    showOtherUserProfile = true
                }
            }
        } catch {
            print("❌ Error loading user profile: \(error)")
            
            // Fallback: create a minimal user from post data
            await MainActor.run {
                profileUser = createMinimalUser()
                isLoadingUser = false
                showOtherUserProfile = true
            }
        }
    }
    
    private func createMinimalUser() -> User {
        // Create a basic user with the info we have from the post
        var user = User(
            id: post.authorId,
            email: "\(post.authorUsername)@example.com", // Placeholder
            username: post.authorUsername,
            fullName: post.authorUsername.capitalized
        )
        
        // Set some reasonable defaults
        user.bio = "Trader on ArkadTrader"
        user.followersCount = 0
        user.followingCount = 0
        user.totalProfitLoss = 0.0
        user.winRate = 0.0
        
        return user
    }
    
    // MARK: - Helper Properties
    
    private var postTypeColor: Color {
        switch post.postType {
        case .text: return .gray
        case .tradeResult: return .green
        case .marketAnalysis: return .blue
        }
    }
}

#Preview {
    let samplePost = Post(content: "Just closed my AAPL position with a +15% gain! 📈", authorId: "sample1", authorUsername: "trader1")
    
    PostCardView(post: samplePost)
        .padding()
        .environmentObject(FirebaseAuthService.shared)
}
