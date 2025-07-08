// File: Core/Home/Views/HomeView.swift
// Enhanced Home View with better organization, animations, and UX

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var selectedTab: HomeFeedTab = .feed
    @State private var showCreatePost = false
    @State private var scrollOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    @State private var showScrollToTop = false
    
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
            ZStack {
                // Background
                Color.gray.opacity(0.05)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Enhanced Tab Selector
                    enhancedTabSelector
                        .background(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    // Content with scroll detection
                    GeometryReader { geometry in
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                LazyVStack(spacing: 0) {
                                    // Content based on selected tab
                                    contentForSelectedTab
                                        .padding(.top, 16)
                                        .padding(.bottom, 100) // Space for floating button
                                }
                                .background(
                                    GeometryReader { contentGeometry in
                                        Color.clear
                                            .preference(key: ScrollOffsetPreferenceKey.self, value: contentGeometry.frame(in: .named("scroll")).minY)
                                    }
                                )
                                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                                    handleScrollOffset(value)
                                }
                            }
                            .coordinateSpace(name: "scroll")
                            .refreshable {
                                await refreshContent()
                            }
                            .overlay(
                                // Scroll to top button
                                scrollToTopButton(proxy: proxy),
                                alignment: .topTrailing
                            )
                        }
                    }
                }
                
                // Enhanced Floating Action Button
                floatingActionButton
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await homeViewModel.loadPosts()
                }
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView { content in
                Task {
                    await homeViewModel.createPost(content: content)
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }
    
    // MARK: - Enhanced Tab Selector
    private var enhancedTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(HomeFeedTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        selectedTab = tab
                        
                        // Trigger market news loading when tab is selected
                        if tab == .marketNews {
                            Task {
                                await homeViewModel.loadMarketNews()
                            }
                        }
                        
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: selectedTab == tab ? tab.activeIcon : tab.icon)
                                .font(.title3)
                                .symbolEffect(.bounce, value: selectedTab == tab)
                            
                            if selectedTab == tab {
                                Text(tab.title)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                        removal: .opacity.combined(with: .scale(scale: 0.8))
                                    ))
                            }
                        }
                        .foregroundColor(selectedTab == tab ? .white : .gray)
                        .padding(.horizontal, selectedTab == tab ? 16 : 8)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color.arkadGold : Color.clear)
                                .shadow(color: selectedTab == tab ? Color.arkadGold.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                        )
                        
                        // Indicator dot
                        Circle()
                            .fill(selectedTab == tab ? Color.arkadGold : Color.clear)
                            .frame(width: 4, height: 4)
                            .scaleEffect(selectedTab == tab ? 1.0 : 0.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab == tab)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Color.white)
    }
    
    // MARK: - Content for Selected Tab
    @ViewBuilder
    private var contentForSelectedTab: some View {
        switch selectedTab {
        case .feed:
            feedContent
        case .following:
            followingContent
        case .marketNews:
            MarketNewsFeedView()
        }
    }
    
    // MARK: - Feed Content
    private var feedContent: some View {
        LazyVStack(spacing: 16) {
            if homeViewModel.isLoading {
                EnhancedLoadingView(message: "Loading latest posts...")
            } else if homeViewModel.posts.isEmpty {
                EnhancedEmptyFeedView {
                    withAnimation(.spring()) {
                        showCreatePost = true
                    }
                }
            } else {
                // Welcome banner for new users
                if homeViewModel.posts.count < 5 {
                    WelcomeBanner()
                }
                
                ForEach(homeViewModel.posts, id: \.id) { post in
                    EnhancedUserPostCard(post: post, homeViewModel: homeViewModel)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
                
                // Load more indicator
                if homeViewModel.hasMorePosts && !homeViewModel.isLoadingMore {
                    LoadMoreButton {
                        Task {
                            await homeViewModel.loadMorePosts()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Following Content
    private var followingContent: some View {
        LazyVStack(spacing: 16) {
            if homeViewModel.followingPosts.isEmpty {
                EnhancedEmptyFollowingView()
            } else {
                ForEach(homeViewModel.followingPosts, id: \.id) { post in
                    EnhancedUserPostCard(post: post, homeViewModel: homeViewModel)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showCreatePost = true
                    }
                    
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Post")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.arkadBlack)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.arkadGold, Color.arkadGold.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .arkadGold.opacity(0.4), radius: 12, x: 0, y: 6)
                    .scaleEffect(showCreatePost ? 0.95 : 1.0)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100) // Account for tab bar
            }
        }
    }
    
    // MARK: - Scroll to Top Button
    private func scrollToTopButton(proxy: ScrollViewReader) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.8)) {
                proxy.scrollTo("top", anchor: .top)
            }
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundColor(.arkadGold)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
        }
        .padding(.trailing, 20)
        .padding(.top, 20)
        .opacity(showScrollToTop ? 1.0 : 0.0)
        .scaleEffect(showScrollToTop ? 1.0 : 0.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showScrollToTop)
    }
    
    // MARK: - Helper Methods
    private func handleScrollOffset(_ offset: CGFloat) {
        let currentOffset = offset
        let threshold: CGFloat = 100
        
        // Show/hide scroll to top button
        DispatchQueue.main.async {
            showScrollToTop = currentOffset < -threshold
            lastScrollOffset = currentOffset
        }
    }
    
    @MainActor
    private func refreshContent() async {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        await homeViewModel.refreshPosts()
        
        if selectedTab == .marketNews {
            await homeViewModel.loadMarketNews()
        }
    }
}

// MARK: - Enhanced Components

struct WelcomeBanner: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to ArkadTrader! 🎉")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Share your trading insights and connect with the community")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title)
                    .foregroundColor(.arkadGold)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.arkadGold.opacity(0.1), Color.arkadGold.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
        )
    }
}

struct EnhancedUserPostCard: View {
    let post: Post
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var isLiked = false
    @State private var likesCount: Int
    @State private var showComments = false
    @State private var showActions = false
    
    init(post: Post, homeViewModel: HomeViewModel) {
        self.post = post
        self.homeViewModel = homeViewModel
        self._likesCount = State(initialValue: post.likesCount)
        self._isLiked = State(initialValue: homeViewModel.likedPosts.contains(post.id))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enhanced User Header
            HStack(spacing: 12) {
                // Profile Avatar with gradient border
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.arkadGold, Color.arkadGold.opacity(0.6)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Text(String(post.authorUsername.prefix(1)).uppercased())
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadGold)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("@\(post.authorUsername)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // Verified badge (placeholder)
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.arkadGold)
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Text(formatDate(post.createdAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if post.postType != .text {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            EnhancedPostTypeLabel(type: post.postType)
                        }
                    }
                }
                
                Spacer()
                
                // More actions button
                Button(action: { showActions.toggle() }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .font(.title3)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // Enhanced Post Content
            Text(post.content)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.primary)
            
            // Enhanced Engagement Section
            HStack(spacing: 24) {
                // Like button with animation
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked.toggle()
                        likesCount += isLiked ? 1 : -1
                        homeViewModel.toggleLike(for: post.id)
                    }
                    
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                            .scaleEffect(isLiked ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                        
                        Text("\(likesCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isLiked ? .red : .gray)
                    }
                }
                
                // Comment button
                Button(action: { showComments = true }) {
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        homeViewModel.toggleBookmark(for: post.id)
                    }
                    
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    Image(systemName: homeViewModel.bookmarkedPosts.contains(post.id) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(homeViewModel.bookmarkedPosts.contains(post.id) ? .arkadGold : .gray)
                        .scaleEffect(homeViewModel.bookmarkedPosts.contains(post.id) ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: homeViewModel.bookmarkedPosts.contains(post.id))
                }
            }
            .font(.subheadline)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EnhancedPostTypeLabel: View {
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

struct EnhancedLoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .arkadGold))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

struct EnhancedEmptyFeedView: View {
    let onCreatePost: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.arkadGold.opacity(0.7))
                
                Text("Welcome to Your Feed!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Share your trading insights and connect with other traders in the community.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: onCreatePost) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Your First Post")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.arkadBlack)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.arkadGold)
                .cornerRadius(25)
                .shadow(color: .arkadGold.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.vertical, 60)
    }
}

struct EnhancedEmptyFollowingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("No Posts from Following")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Follow other traders to see their posts here. Discover traders in the search tab.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Discover Traders")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.arkadBlack)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.arkadGold)
                .cornerRadius(25)
            }
        }
        .padding(.vertical, 60)
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
            .foregroundColor(.arkadGold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.arkadGold.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    HomeView()
        .environmentObject(FirebaseAuthService.shared)
}
