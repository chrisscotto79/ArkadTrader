// File: Core/Home/Views/Main/FeedTabView.swift
// Main feed tab with filtering and all post interactions

import SwiftUI

struct FeedTabView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var showFilterOptions = false
    @State private var scrollToTopId = UUID()
    
    var body: some View {
        VStack(spacing: 0) {
            // Quick filters bar
            if showFilterOptions || homeViewModel.selectedPostFilter != .all {
                quickFiltersBar
            }
            
            // Trending hashtags/tickers (when no search)
            if homeViewModel.searchQuery.isEmpty && homeViewModel.selectedPostFilter == .all {
                trendingSection
            }
            
            // Main feed content
            feedContent
        }
        .refreshable {
            await homeViewModel.refreshFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToTop"))) { _ in
            withAnimation {
                scrollToTopId = UUID()
            }
        }
    }
    
    // MARK: - Quick Filters Bar
    private var quickFiltersBar: some View {
        VStack(spacing: 0) {
            // Filter toggle button
            HStack {
                Button(action: {
                    withAnimation(.spring()) {
                        showFilterOptions.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.horizontal.3.decrease.circle")
                            .font(.subheadline)
                        Text("Filter")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.arkadGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Clear filters button (when filters active)
                if homeViewModel.selectedPostFilter != .all || !homeViewModel.searchQuery.isEmpty {
                    Button(action: {
                        homeViewModel.clearFilters()
                    }) {
                        HStack(spacing: 4) {
                            Text("Clear")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Filter options
            if showFilterOptions {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PostFilter.allCases, id: \.title) { filter in
                            FilterChip(
                                title: filter.title,
                                icon: filter.icon,
                                isSelected: homeViewModel.selectedPostFilter == filter
                            ) {
                                homeViewModel.applyFilter(filter)
                                withAnimation(.spring()) {
                                    showFilterOptions = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Trending Section
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Trending hashtags
            if !homeViewModel.trendingHashtags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "number.circle.fill")
                            .foregroundColor(.purple)
                        Text("Trending Hashtags")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(homeViewModel.trendingHashtags, id: \.self) { hashtag in
                                Button(action: {
                                    homeViewModel.applyHashtagFilter(hashtag)
                                }) {
                                    Text("#\(hashtag)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            // Trending tickers
            if !homeViewModel.trendingTickers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.green)
                        Text("Trending Tickers")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(homeViewModel.trendingTickers, id: \.self) { ticker in
                                Button(action: {
                                    homeViewModel.applyTickerFilter(ticker)
                                }) {
                                    Text("$\(ticker)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Feed Content
    private var feedContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Scroll to top anchor
                    Color.clear
                        .frame(height: 1)
                        .id(scrollToTopId)
                    
                    if homeViewModel.isLoading && homeViewModel.posts.isEmpty {
                        LoadingView(message: "Loading feed...")
                            .padding(.top, 50)
                    } else if homeViewModel.filteredPosts.isEmpty {
                        EmptyFeedView(
                            hasFilters: homeViewModel.selectedPostFilter != .all || !homeViewModel.searchQuery.isEmpty,
                            onClearFilters: {
                                homeViewModel.clearFilters()
                            }
                        )
                        .padding(.top, 50)
                    } else {
                        // Feed statistics (when no filters)
                        if homeViewModel.selectedPostFilter == .all && homeViewModel.searchQuery.isEmpty {
                            FeedStatsView()
                                .environmentObject(homeViewModel)
                        }
                        
                        // Posts
                        ForEach(homeViewModel.filteredPosts, id: \.id) { post in
                            PostCard(post: post)
                                .environmentObject(authService)
                                .environmentObject(homeViewModel)
                        }
                        
                        // Load more button
                        if homeViewModel.hasMorePosts && homeViewModel.selectedPostFilter == .all {
                            LoadMoreButton {
                                Task {
                                    await homeViewModel.loadMorePosts()
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
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .arkadGold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.arkadGold : Color.arkadGold.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty Feed View
struct EmptyFeedView: View {
    let hasFilters: Bool
    let onClearFilters: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasFilters ? "line.horizontal.3.decrease.circle" : "house")
                .font(.system(size: 50))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            Text(hasFilters ? "No Posts Found" : "Welcome to Arkad!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(hasFilters ?
                 "Try adjusting your filters or search terms to find more posts." :
                 "Start following other traders to see their posts in your feed, or create your first post to get started.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if hasFilters {
                Button(action: onClearFilters) {
                    Text("Clear Filters")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.arkadGold)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.arkadGold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading More View
struct LoadingMoreView: View {
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading more posts...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Load More Button
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
            .foregroundColor(.arkadGold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.arkadGold.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Feed Stats View
struct FeedStatsView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    var body: some View {
        let stats = homeViewModel.getEngagementStats()
        
        VStack(spacing: 12) {
            HStack {
                Text("Community Stats")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 20) {
                StatItem(title: "Posts", value: "\(stats.totalPosts)", icon: "doc.text")
                StatItem(title: "Likes", value: "\(stats.totalLikes)", icon: "heart")
                StatItem(title: "Comments", value: "\(stats.totalComments)", icon: "message")
                StatItem(title: "Shares", value: "\(stats.totalShares)", icon: "square.and.arrow.up")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.arkadGold.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.bottom, 8)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.arkadGold)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - User Engagement Card
struct UserEngagementCard: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Activity")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("Posts Liked")
                    Spacer()
                    Text("\(homeViewModel.likedPosts.count)")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.arkadGold)
                    Text("Posts Saved")
                    Spacer()
                    Text("\(homeViewModel.bookmarkedPosts.count)")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.blue)
                    Text("Posts Viewed")
                    Spacer()
                    Text("\(homeViewModel.viewedPosts.count)")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
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

// MARK: - Post Performance Insights
struct PostPerformanceInsights: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Post Performance")
                .font(.headline)
                .fontWeight(.bold)
            
            let stats = homeViewModel.getEngagementStats()
            
            VStack(spacing: 8) {
                HStack {
                    Text("Engagement Rate")
                    Spacer()
                    Text("\(String(format: "%.1f", stats.engagementRate * 100))%")
                        .fontWeight(.medium)
                        .foregroundColor(.arkadGold)
                }
                
                HStack {
                    Text("Avg. Likes per Post")
                    Spacer()
                    Text("\(stats.totalPosts > 0 ? stats.totalLikes / stats.totalPosts : 0)")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Avg. Comments per Post")
                    Spacer()
                    Text("\(stats.totalPosts > 0 ? stats.totalComments / stats.totalPosts : 0)")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
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
