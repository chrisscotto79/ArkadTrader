// File: Core/Home/Views/HomeView.swift
// Updated Home View with Market News replacing Trending

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var selectedTab: HomeFeedTab = .feed
    @State private var showCreatePost = false
    @State private var newPostContent = ""
    
    enum HomeFeedTab: CaseIterable {
        case feed, following, marketNews
        
        var title: String {
            switch self {
            case .feed: return "Feed"
            case .following: return "Following"
            case .marketNews: return "Market News"
            }
        }
        
        var icon: String {
            switch self {
            case .feed: return "house.fill"
            case .following: return "person.2.fill"
            case .marketNews: return "newspaper.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Simplified tab selector (icons with text)
                    simplifiedTabSelector
                    
                    // Content based on selected tab
                    if selectedTab == .marketNews {
                        // Market News Feed takes full space
                        MarketNewsFeedView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                switch selectedTab {
                                case .feed:
                                    allPostsContent
                                case .following:
                                    followingPostsContent
                                case .marketNews:
                                    EmptyView() // This won't be reached
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 80) // Space for floating button at bottom
                        }
                        .refreshable {
                            await refreshContent()
                        }
                    }
                }
                
                // Floating Action Button (very bottom right)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showCreatePost = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20) // Very bottom
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView { content in
                Task {
                    await homeViewModel.createPost(content: content)
                }
            }
        }
        .onAppear {
            Task {
                await homeViewModel.loadPosts()
            }
        }
    }
    
    // MARK: - Tab Selector (with text labels)
    private var simplifiedTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(HomeFeedTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                        // Trigger market news loading when tab is selected
                        if tab == .marketNews {
                            Task {
                                await homeViewModel.loadMarketNews()
                            }
                        }
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        
                        Text(tab.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Content Sections
    private var allPostsContent: some View {
        Group {
            if homeViewModel.isLoading {
                LoadingFeedView()
            } else if homeViewModel.posts.isEmpty {
                EmptyFeedView {
                    showCreatePost = true
                }
            } else {
                ForEach(homeViewModel.posts, id: \.id) { post in
                    UserPostCard(post: post, homeViewModel: homeViewModel)
                }
            }
        }
    }
    
    private var followingPostsContent: some View {
        Group {
            if homeViewModel.followingPosts.isEmpty {
                EmptyFollowingView()
            } else {
                ForEach(homeViewModel.followingPosts, id: \.id) { post in
                    UserPostCard(post: post, homeViewModel: homeViewModel)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    @MainActor
    private func refreshContent() async {
        await homeViewModel.loadPosts()
    }
}

// MARK: - User Post Card (existing)
struct UserPostCard: View {
    let post: Post
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var isLiked = false
    @State private var likesCount: Int
    @State private var showComments = false
    
    init(post: Post, homeViewModel: HomeViewModel) {
        self.post = post
        self.homeViewModel = homeViewModel
        self._likesCount = State(initialValue: post.likesCount)
        self._isLiked = State(initialValue: homeViewModel.likedPosts.contains(post.id))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User header
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(post.authorUsername.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(post.authorUsername)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(formatDate(post.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if post.postType != .text {
                    PostTypeLabel(type: post.postType)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                }
            }
            
            // Post content
            Text(post.content)
                .font(.body)
                .lineLimit(nil)
            
            // Engagement section
            HStack(spacing: 24) {
                // Like button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isLiked.toggle()
                        likesCount += isLiked ? 1 : -1
                        homeViewModel.toggleLike(for: post.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                            .scaleEffect(isLiked ? 1.2 : 1.0)
                        
                        Text("\(likesCount)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Comment button
                Button(action: { showComments = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .foregroundColor(.gray)
                        
                        Text("\(post.commentsCount)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Share button
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Bookmark button
                Button(action: {
                    homeViewModel.toggleBookmark(for: post.id)
                }) {
                    Image(systemName: homeViewModel.bookmarkedPosts.contains(post.id) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(homeViewModel.bookmarkedPosts.contains(post.id) ? .blue : .gray)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct PostTypeLabel: View {
    let type: PostType
    
    var body: some View {
        Text(type.displayName)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(typeColor)
            .cornerRadius(8)
    }
    
    private var typeColor: Color {
        switch type {
        case .text: return .clear
        case .tradeResult: return .green
        case .marketAnalysis: return .blue
        }
    }
}

// MARK: - Create Post View (existing)
struct CreatePostView: View {
    let onPost: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var content = ""
    @State private var isPosting = false
    @State private var characterCount = 0
    private let maxCharacters = 280
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Text("\(characterCount)/\(maxCharacters)")
                        .font(.caption)
                        .foregroundColor(characterCount > maxCharacters ? .red : .gray)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("What's happening in the markets?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onChange(of: content) { _, newValue in
                            characterCount = newValue.count
                        }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    isPosting = true
                    onPost(content)
                    dismiss()
                }) {
                    HStack {
                        if isPosting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isPosting ? "Posting..." : "Share Post")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canPost ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canPost || isPosting)
                .padding(.horizontal)
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        characterCount <= maxCharacters
    }
}

// MARK: - Empty State Views

struct EmptyFeedView: View {
    let onCreatePost: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("Welcome to ArkadTrader!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Share your trading insights and connect with other traders in the community.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: onCreatePost) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Create Your First Post")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
            }
        }
        .padding(.vertical, 40)
    }
}

struct EmptyFollowingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("No Posts from Following")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
                Text("Follow other traders to see their posts here. Discover traders in the search tab.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 40)
    }
}

struct LoadingFeedView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading posts...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

#Preview {
    HomeView()
        .environmentObject(FirebaseAuthService.shared)
}
