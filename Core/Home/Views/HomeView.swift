// File: Core/Home/Views/HomeView.swift
// Clean Home View - Real User Content Only, No Mock Data

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var selectedTab: HomeFeedTab = .feed
    @State private var showCreatePost = false
    @State private var newPostContent = ""
    
    enum HomeFeedTab: CaseIterable {
        case feed, following, trending
        
        var title: String {
            switch self {
            case .feed: return "Feed"
            case .following: return "Following"
            case .trending: return "Trending"
            }
        }
        
        var icon: String {
            switch self {
            case .feed: return "house.fill"
            case .following: return "person.2.fill"
            case .trending: return "flame.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with greeting and actions
                headerSection
                
                // Tab selector
                tabSelectorSection
                
                // Content based on selected tab
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedTab {
                        case .feed:
                            allPostsContent
                        case .following:
                            followingPostsContent
                        case .trending:
                            trendingPostsContent
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                .refreshable {
                    await refreshContent()
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
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(getGreeting())
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(authService.currentUser?.fullName ?? "Trader")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: { showCreatePost = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Button(action: {}) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(getInitials())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            )
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Tab Selector
    private var tabSelectorSection: some View {
        HStack(spacing: 0) {
            ForEach(HomeFeedTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
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
    
    private var trendingPostsContent: some View {
        Group {
            if homeViewModel.trendingPosts.isEmpty {
                EmptyTrendingView()
            } else {
                ForEach(homeViewModel.trendingPosts, id: \.id) { post in
                    UserPostCard(post: post, homeViewModel: homeViewModel)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    private func getInitials() -> String {
        guard let user = authService.currentUser else { return "U" }
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return String(firstInitial) + String(lastInitial)
    }
    
    @MainActor
    private func refreshContent() async {
        await homeViewModel.loadPosts()
    }
}

// MARK: - User Post Card
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

// MARK: - Create Post View
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

struct EmptyTrendingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "flame")
                .font(.system(size: 48))
                .foregroundColor(.orange.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("No Trending Posts Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
                Text("Posts that get lots of engagement will appear here. Be the first to start a trend!")
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
