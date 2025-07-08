// File: Core/Home/Views/SocialFeedView.swift
// Clean Social Feed View - Real User Content Only

import SwiftUI

struct SocialFeedView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var showCreatePost = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Feed content
                feedContent
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
            Text("Social Feed")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: { showCreatePost = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Feed Content
    private var feedContent: some View {
        Group {
            if homeViewModel.isLoading {
                LoadingView()
            } else if homeViewModel.posts.isEmpty {
                EmptyFeedView {
                    showCreatePost = true
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(homeViewModel.posts, id: \.id) { post in
                            UserPostCard(post: post, homeViewModel: homeViewModel)
                        }
                        
                        // Load more indicator
                        if homeViewModel.hasMorePosts {
                            LoadMoreButton {
                                Task {
                                    await homeViewModel.loadMorePosts()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                .refreshable {
                    await homeViewModel.refreshPosts()
                }
            }
        }
    }
    
    // MARK: - Supporting Views
    
    struct LoadingView: View {
        var body: some View {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Loading posts...")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 100)
        }
    }
    
    struct LoadMoreButton: View {
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Text("Load More Posts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Image(systemName: "arrow.down.circle")
                        .font(.subheadline)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Feed Statistics View
struct FeedStatsView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    
    var body: some View {
        let stats = homeViewModel.getEngagementStats()
        
        HStack {
            StatItem(title: "Posts", value: "\(stats.totalPosts)")
            StatItem(title: "Likes", value: "\(stats.totalLikes)")
            StatItem(title: "Comments", value: "\(stats.totalComments)")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    struct StatItem: View {
        let title: String
        let value: String
        
        var body: some View {
            VStack(spacing: 4) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - User Engagement Card
struct UserEngagementCard: View {
    @ObservedObject var homeViewModel: HomeViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Activity")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Posts Liked")
                    Spacer()
                    Text("\(homeViewModel.likedPosts.count)")
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
                
                HStack {
                    Text("Posts Bookmarked")
                    Spacer()
                    Text("\(homeViewModel.bookmarkedPosts.count)")
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Post Filter Options
struct PostFilterView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var selectedFilter: PostTypeFilter = .all
    
    enum PostTypeFilter: CaseIterable {
        case all, trades, analysis, discussions
        
        var title: String {
            switch self {
            case .all: return "All"
            case .trades: return "Trades"
            case .analysis: return "Analysis"
            case .discussions: return "Discussions"
            }
        }
        
        var postType: PostType? {
            switch self {
            case .all: return nil
            case .trades: return .tradeResult
            case .analysis: return .marketAnalysis
            case .discussions: return .text
            }
        }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PostTypeFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.title,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        // Apply filter logic here
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    struct FilterChip: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
                    .cornerRadius(16)
            }
        }
    }
}

#Preview {
    SocialFeedView()
        .environmentObject(FirebaseAuthService.shared)
}
