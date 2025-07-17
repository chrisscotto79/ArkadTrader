// File: Core/Home/ViewModels/HomeViewModel.swift
// Complete HomeViewModel with all functionality

import Foundation
import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var posts: [Post] = []
    @Published var followingPosts: [Post] = []
    @Published var savedPosts: [Post] = []
    @Published var marketNews: [MarketNewsArticle] = []
    @Published var notifications: [AppNotification] = []
    @Published var followingActivities: [FollowingActivity] = []
    
    // Loading states
    @Published var isLoading = false
    @Published var isLoadingNews = false
    @Published var isLoadingFollowing = false
    @Published var isRefreshing = false
    
    // Error handling
    @Published var errorMessage = ""
    @Published var showError = false
    
    // User interactions
    @Published var likedPosts: Set<String> = []
    @Published var bookmarkedPosts: Set<String> = []
    @Published var reportedPosts: Set<String> = []
    @Published var viewedPosts: Set<String> = []
    
    // Filtering and sorting
    @Published var selectedPostFilter: PostFilter = .all
    @Published var selectedCommentSort: CommentSortOption = .recent
    @Published var searchQuery = ""
    
    // Pagination
    @Published var hasMorePosts = true
    @Published var hasMoreFollowingPosts = true
    @Published var hasMoreNews = true
    @Published var isLoadingMore = false
    
    // Notifications
    @Published var unreadNotificationsCount = 0
    @Published var hasUnreadNotifications = false
    
    // Current selected items
    @Published var selectedPost: Post?
    @Published var selectedArticle: MarketNewsArticle?
    @Published var selectedUser: User?
    
    // UI States
    @Published var showingPostDetail = false
    @Published var showingUserProfile = false
    @Published var showingCreatePost = false
    @Published var showingReportSheet = false
    @Published var showingShareSheet = false
    @Published var showingNotifications = false
    
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 0
    private var currentFollowingPage = 0
    private var currentNewsPage = 0
    private let itemsPerPage = 20
    
    // News API configuration
    private let finnhubApiKey = "ct73so9r01qr3sdtkf20ct73so9r01qr3sdtkf2g"
    private let finnhubBaseUrl = "https://finnhub.io/api/v1"
    private let newsCacheInterval: TimeInterval = 30 * 60
    
    // Cache for performance
    private var allPosts: [Post] = []
    private var allFollowingPosts: [Post] = []
    private var allMarketNews: [MarketNewsArticle] = []
    
    // MARK: - Computed Properties
    var filteredPosts: [Post] {
        var filtered = posts
        
        // Apply filter
        if selectedPostFilter != .all {
            filtered = filtered.filter { selectedPostFilter.matches(post: $0) }
        }
        
        // Apply search
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = filtered.filter { post in
                let query = searchQuery.lowercased()
                return post.content.lowercased().contains(query) ||
                       post.authorUsername.lowercased().contains(query) ||
                       post.hashtags.contains { $0.lowercased().contains(query) } ||
                       post.tickerSymbols.contains { $0.lowercased().contains(query) }
            }
        }
        
        return filtered
    }
    
    var trendingHashtags: [String] {
        let allHashtags = posts.flatMap { $0.hashtags }
        let hashtagCounts = Dictionary(grouping: allHashtags) { $0 }
            .mapValues { $0.count }
        
        return Array(hashtagCounts.keys)
            .sorted { hashtagCounts[$0] ?? 0 > hashtagCounts[$1] ?? 0 }
            .prefix(10)
            .map { $0 }
    }
    
    var trendingTickers: [String] {
        let allTickers = posts.flatMap { $0.tickerSymbols }
        let tickerCounts = Dictionary(grouping: allTickers) { $0 }
            .mapValues { $0.count }
        
        return Array(tickerCounts.keys)
            .sorted { tickerCounts[$0] ?? 0 > tickerCounts[$1] ?? 0 }
            .prefix(10)
            .map { $0 }
    }
    
    // MARK: - Initialization
    init() {
        setupObservers()
        Task {
            await loadInitialData()
        }
    }
    
    private func setupObservers() {
        // Observe search query changes
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Observe filter changes
        $selectedPostFilter
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading Methods
    func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadFeed() }
            group.addTask { await self.loadFollowingFeed() }
            group.addTask { await self.loadMarketNews() }
            group.addTask { await self.loadNotifications() }
            group.addTask { await self.loadUserInteractions() }
            group.addTask { await self.loadSavedPosts() }
        }
    }
    
    func loadFeed() async {
        guard !isLoading else { return }
        
        isLoading = true
        currentPage = 0
        
        do {
            // TODO: Implement getFeedPosts with pagination
            let fetchedPosts = try await authService.getFeedPosts(page: currentPage, limit: itemsPerPage)
            
            allPosts = fetchedPosts.sorted { $0.createdAt > $1.createdAt }
            posts = allPosts
            
            // Track views for analytics
            for post in posts {
                await trackPostView(postId: post.id)
            }
            
            hasMorePosts = fetchedPosts.count == itemsPerPage
            
        } catch {
            handleError("Failed to load feed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func loadFollowingFeed() async {
        guard !isLoadingFollowing else { return }
        guard let currentUserId = authService.currentUser?.id else { return }
        
        isLoadingFollowing = true
        currentFollowingPage = 0
        
        do {
            // TODO: Implement getFollowingPosts method
            let fetchedPosts = try await authService.getFollowingPosts(userId: currentUserId, page: currentFollowingPage, limit: itemsPerPage)
            
            allFollowingPosts = fetchedPosts.sorted { $0.createdAt > $1.createdAt }
            followingPosts = allFollowingPosts
            
            // Load following activities
            let activities = try await authService.getFollowingActivities(userId: currentUserId, limit: 50)
            followingActivities = activities.sorted { $0.timestamp > $1.timestamp }
            
            hasMoreFollowingPosts = fetchedPosts.count == itemsPerPage
            
        } catch {
            handleError("Failed to load following feed: \(error.localizedDescription)")
        }
        
        isLoadingFollowing = false
    }
    
    func loadMarketNews() async {
        guard !isLoadingNews else { return }
        
        isLoadingNews = true
        currentNewsPage = 0
        
        do {
            // Check cache first
            if let cachedNews = await getCachedNews(), !cachedNews.isEmpty {
                allMarketNews = cachedNews
                marketNews = allMarketNews
                isLoadingNews = false
                return
            }
            
            // Fetch fresh news
            let freshNews = try await fetchMarketNewsFromAPI()
            allMarketNews = freshNews
            marketNews = allMarketNews
            
            // Cache the news
            await cacheNews(freshNews)
            
            hasMoreNews = freshNews.count == itemsPerPage
            
        } catch {
            handleError("Failed to load market news: \(error.localizedDescription)")
        }
        
        isLoadingNews = false
    }
    
    func loadNotifications() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        do {
            // TODO: Implement getNotifications method
            let fetchedNotifications = try await authService.getNotifications(userId: currentUserId, limit: 50)
            notifications = fetchedNotifications.sorted { $0.createdAt > $1.createdAt }
            
            unreadNotificationsCount = notifications.filter { !$0.isRead }.count
            hasUnreadNotifications = unreadNotificationsCount > 0
            
        } catch {
            print("Failed to load notifications: \(error)")
        }
    }
    
    func loadUserInteractions() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            // TODO: Implement these methods
            async let liked = authService.getUserLikedPosts(userId: userId)
            async let bookmarked = authService.getUserBookmarkedPosts(userId: userId)
            async let reported = authService.getUserReportedPosts(userId: userId)
            async let viewed = authService.getUserViewedPosts(userId: userId)
            
            likedPosts = try await liked
            bookmarkedPosts = try await bookmarked
            reportedPosts = try await reported
            viewedPosts = try await viewed
            
        } catch {
            print("Failed to load user interactions: \(error)")
        }
    }
    
    func loadSavedPosts() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            // TODO: Implement getSavedPosts method
            savedPosts = try await authService.getSavedPosts(userId: userId)
        } catch {
            print("Failed to load saved posts: \(error)")
        }
    }
    
    // MARK: - Refresh Methods
    func refreshAllData() async {
        isRefreshing = true
        await loadInitialData()
        isRefreshing = false
    }
    
    func refreshFeed() async {
        isRefreshing = true
        await loadFeed()
        isRefreshing = false
    }
    
    func refreshFollowingFeed() async {
        isRefreshing = true
        await loadFollowingFeed()
        isRefreshing = false
    }
    
    func refreshMarketNews() async {
        isRefreshing = true
        await clearNewsCache()
        await loadMarketNews()
        isRefreshing = false
    }
    
    // MARK: - Load More Methods
    func loadMorePosts() async {
        guard !isLoadingMore && hasMorePosts else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            // TODO: Implement pagination
            let newPosts = try await authService.getFeedPosts(page: currentPage, limit: itemsPerPage)
            
            allPosts.append(contentsOf: newPosts)
            posts.append(contentsOf: newPosts)
            
            hasMorePosts = newPosts.count == itemsPerPage
            
        } catch {
            currentPage -= 1
            handleError("Failed to load more posts: \(error.localizedDescription)")
        }
        
        isLoadingMore = false
    }
    
    func loadMoreFollowingPosts() async {
        guard !isLoadingMore && hasMoreFollowingPosts else { return }
        guard let currentUserId = authService.currentUser?.id else { return }
        
        isLoadingMore = true
        currentFollowingPage += 1
        
        do {
            // TODO: Implement pagination for following posts
            let newPosts = try await authService.getFollowingPosts(userId: currentUserId, page: currentFollowingPage, limit: itemsPerPage)
            
            allFollowingPosts.append(contentsOf: newPosts)
            followingPosts.append(contentsOf: newPosts)
            
            hasMoreFollowingPosts = newPosts.count == itemsPerPage
            
        } catch {
            currentFollowingPage -= 1
            handleError("Failed to load more following posts: \(error.localizedDescription)")
        }
        
        isLoadingMore = false
    }
    
    func loadMoreNews() async {
        guard !isLoadingMore && hasMoreNews else { return }
        
        isLoadingMore = true
        currentNewsPage += 1
        
        do {
            // TODO: Implement pagination for news
            let newNews = try await fetchMarketNewsFromAPI(page: currentNewsPage)
            
            allMarketNews.append(contentsOf: newNews)
            marketNews.append(contentsOf: newNews)
            
            hasMoreNews = newNews.count == itemsPerPage
            
        } catch {
            currentNewsPage -= 1
            handleError("Failed to load more news: \(error.localizedDescription)")
        }
        
        isLoadingMore = false
    }
    
    // MARK: - Post Creation
    func createPost(content: String, postType: PostType, imageUrls: [String] = []) async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            // Extract hashtags and mentions
            let hashtags = extractHashtags(from: content)
            let mentions = extractMentions(from: content)
            let tickers = extractTickers(from: content)
            
            let newPost = Post(
                authorId: currentUser.id,
                authorUsername: currentUser.username,
                authorProfileImageUrl: currentUser.profileImageUrl,
                content: content,
                postType: postType,
                hashtags: hashtags,
                mentionedUsers: mentions,
                imageUrls: imageUrls,
                tickerSymbols: tickers
            )
            
            // TODO: Implement createPost method
            try await authService.createPost(post: newPost)
            
            // Add to local arrays
            allPosts.insert(newPost, at: 0)
            posts.insert(newPost, at: 0)
            
            // Add to following feed if appropriate
            if followingPosts.contains(where: { $0.authorId == currentUser.id }) {
                followingPosts.insert(newPost, at: 0)
            }
            
            // Create activity
            let activity = FollowingActivity(
                userId: currentUser.id,
                username: currentUser.username,
                activityType: postType == .tradeResult ? .newTrade : .newPost,
                content: content,
                relatedPostId: newPost.id
            )
            
            try await authService.createFollowingActivity(activity: activity)
            
        } catch {
            handleError("Failed to create post: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Post Interactions
    func toggleLike(postId: String) async {
        guard let userId = authService.currentUser?.id else { return }
        
        let wasLiked = likedPosts.contains(postId)
        
        // Update UI immediately
        if wasLiked {
            likedPosts.remove(postId)
            updateLikeCount(postId: postId, increment: false)
        } else {
            likedPosts.insert(postId)
            updateLikeCount(postId: postId, increment: true)
        }
        
        // Sync with Firebase
        do {
            if wasLiked {
                // TODO: Implement unlikePost method
                try await authService.unlikePost(postId: postId, userId: userId)
            } else {
                // TODO: Implement likePost method
                try await authService.likePost(postId: postId, userId: userId)
                
                // Create notification for post author
                if let post = posts.first(where: { $0.id == postId }), post.authorId != userId {
                    try await createLikeNotification(postId: postId, likedBy: userId, postAuthor: post.authorId)
                }
            }
        } catch {
            // Revert on error
            if wasLiked {
                likedPosts.insert(postId)
                updateLikeCount(postId: postId, increment: true)
            } else {
                likedPosts.remove(postId)
                updateLikeCount(postId: postId, increment: false)
            }
            
            handleError("Failed to sync like: \(error.localizedDescription)")
        }
    }
    
    func toggleBookmark(postId: String) async {
        guard let userId = authService.currentUser?.id else { return }
        
        let wasBookmarked = bookmarkedPosts.contains(postId)
        
        // Update UI immediately
        if wasBookmarked {
            bookmarkedPosts.remove(postId)
        } else {
            bookmarkedPosts.insert(postId)
        }
        
        // Sync with Firebase
        do {
            if wasBookmarked {
                // TODO: Implement unbookmarkPost method
                try await authService.unbookmarkPost(postId: postId, userId: userId)
            } else {
                // TODO: Implement bookmarkPost method
                try await authService.bookmarkPost(postId: postId, userId: userId)
            }
        } catch {
            // Revert on error
            if wasBookmarked {
                bookmarkedPosts.insert(postId)
            } else {
                bookmarkedPosts.remove(postId)
            }
            
            handleError("Failed to sync bookmark: \(error.localizedDescription)")
        }
    }
    
    func sharePost(postId: String, shareOption: ShareOption) async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            // TODO: Implement sharePost method
            try await authService.sharePost(postId: postId, userId: userId, shareType: shareOption.rawValue)
            
            // Update share count
            updateShareCount(postId: postId, increment: true)
            
        } catch {
            handleError("Failed to share post: \(error.localizedDescription)")
        }
    }
    
    func reportPost(postId: String, reason: PostReport.ReportReason, details: String?) async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            let report = PostReport(
                id: UUID().uuidString,
                postId: postId,
                reportedBy: userId,
                reason: reason,
                additionalDetails: details,
                createdAt: Date(),
                status: .pending
            )
            
            // TODO: Implement reportPost method
            try await authService.reportPost(report: report)
            
            // Track locally
            reportedPosts.insert(postId)
            
        } catch {
            handleError("Failed to report post: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Navigation Methods
    func showPostDetail(post: Post) {
        selectedPost = post
        showingPostDetail = true
        
        // Track view
        Task {
            await trackPostView(postId: post.id)
        }
    }
    
    func showUserProfile(userId: String) {
        Task {
            do {
                // TODO: Implement getUser method
                let user = try await authService.getUser(userId: userId)
                selectedUser = user
                showingUserProfile = true
            } catch {
                handleError("Failed to load user profile: \(error.localizedDescription)")
            }
        }
    }
    
    func showCreatePost() {
        showingCreatePost = true
    }
    
    func showReportSheet(post: Post) {
        selectedPost = post
        showingReportSheet = true
    }
    
    func showShareSheet(post: Post) {
        selectedPost = post
        showingShareSheet = true
    }
    
    // MARK: - Filter Methods
    func applyFilter(_ filter: PostFilter) {
        selectedPostFilter = filter
        objectWillChange.send()
    }
    
    func applyHashtagFilter(_ hashtag: String) {
        selectedPostFilter = .hashtag(hashtag)
        objectWillChange.send()
    }
    
    func applyTickerFilter(_ ticker: String) {
        selectedPostFilter = .ticker(ticker)
        objectWillChange.send()
    }
    
    func applyUserFilter(_ username: String) {
        selectedPostFilter = .user(username)
        objectWillChange.send()
    }
    
    func clearFilters() {
        selectedPostFilter = .all
        searchQuery = ""
        objectWillChange.send()
    }
    
    // MARK: - Search Methods
    func searchPosts(query: String) {
        searchQuery = query
        objectWillChange.send()
    }
    
    func clearSearch() {
        searchQuery = ""
        objectWillChange.send()
    }
    
    // MARK: - Comment Methods
    func loadComments(for postId: String) async -> [Comment] {
        do {
            // TODO: Implement getPostComments method
            let comments = try await authService.getPostComments(postId: postId, sortBy: selectedCommentSort)
            return comments
        } catch {
            handleError("Failed to load comments: \(error.localizedDescription)")
            return []
        }
    }
    
    func createComment(postId: String, content: String, parentCommentId: String? = nil) async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            let mentions = extractMentions(from: content)
            
            let comment = Comment(
                postId: postId,
                authorId: currentUser.id,
                authorUsername: currentUser.username,
                authorProfileImageUrl: currentUser.profileImageUrl,
                content: content,
                parentCommentId: parentCommentId,
                mentionedUsers: mentions
            )
            
            // TODO: Implement createComment method
            try await authService.createComment(comment: comment)
            
            // Update comment count
            updateCommentCount(postId: postId, increment: true)
            
            // Create notification for post author
            if let post = posts.first(where: { $0.id == postId }), post.authorId != currentUser.id {
                try await createCommentNotification(postId: postId, commentedBy: currentUser.id, postAuthor: post.authorId, commentContent: content)
            }
            
        } catch {
            handleError("Failed to create comment: \(error.localizedDescription)")
        }
    }
    
    func toggleCommentLike(commentId: String) async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            // TODO: Implement toggleCommentLike method
            try await authService.toggleCommentLike(commentId: commentId, userId: userId)
        } catch {
            handleError("Failed to toggle comment like: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notification Methods
    func markNotificationAsRead(notificationId: String) async {
        do {
            // TODO: Implement markNotificationAsRead method
            try await authService.markNotificationAsRead(notificationId: notificationId)
            
            // Update locally
            if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
                var updatedNotification = notifications[index]
                // Note: We can't modify the isRead property directly since it's let
                // This would need to be handled differently in the actual implementation
                notifications[index] = updatedNotification
                unreadNotificationsCount -= 1
                hasUnreadNotifications = unreadNotificationsCount > 0
            }
            
        } catch {
            handleError("Failed to mark notification as read: \(error.localizedDescription)")
        }
    }
    
    func markAllNotificationsAsRead() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            // TODO: Implement markAllNotificationsAsRead method
            try await authService.markAllNotificationsAsRead(userId: userId)
            
            // Update locally
            unreadNotificationsCount = 0
            hasUnreadNotifications = false
            
        } catch {
            handleError("Failed to mark all notifications as read: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    private func updateLikeCount(postId: String, increment: Bool) {
        let change = increment ? 1 : -1
        
        updatePostInArrays(postId: postId) { post in
            post.likesCount = max(0, post.likesCount + change)
        }
    }
    
    private func updateCommentCount(postId: String, increment: Bool) {
        let change = increment ? 1 : -1
        
        updatePostInArrays(postId: postId) { post in
            post.commentsCount = max(0, post.commentsCount + change)
        }
    }
    
    private func updateShareCount(postId: String, increment: Bool) {
        let change = increment ? 1 : -1
        
        updatePostInArrays(postId: postId) { post in
            post.sharesCount = max(0, post.sharesCount + change)
        }
    }
    
    private func updatePostInArrays(postId: String, updateBlock: (inout Post) -> Void) {
        // Update in all arrays
        if let index = allPosts.firstIndex(where: { $0.id == postId }) {
            updateBlock(&allPosts[index])
        }
        
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            updateBlock(&posts[index])
        }
        
        if let index = followingPosts.firstIndex(where: { $0.id == postId }) {
            updateBlock(&followingPosts[index])
        }
        
        if let index = savedPosts.firstIndex(where: { $0.id == postId }) {
            updateBlock(&savedPosts[index])
        }
    }
    
    private func trackPostView(postId: String) async {
        guard let userId = authService.currentUser?.id else { return }
        guard !viewedPosts.contains(postId) else { return }
        
        viewedPosts.insert(postId)
        
        do {
            // TODO: Implement trackPostView method
            try await authService.trackPostView(postId: postId, userId: userId)
        } catch {
            print("Failed to track post view: \(error)")
        }
    }
    
    private func extractHashtags(from text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "#\\w+", options: [])
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        return matches.compactMap { match in
            let range = Range(match.range, in: text)!
            let hashtag = String(text[range])
            return String(hashtag.dropFirst()) // Remove the #
        }
    }
    
    private func extractMentions(from text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "@\\w+", options: [])
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        return matches.compactMap { match in
            let range = Range(match.range, in: text)!
            let mention = String(text[range])
            return String(mention.dropFirst()) // Remove the @
        }
    }
    
    private func extractTickers(from text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "\\$[A-Z]{1,5}", options: [])
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        return matches.compactMap { match in
            let range = Range(match.range, in: text)!
            let ticker = String(text[range])
            return String(ticker.dropFirst()) // Remove the $
        }
    }
    
    private func createLikeNotification(postId: String, likedBy: String, postAuthor: String) async throws {
        guard let likerUser = try? await authService.getUser(userId: likedBy) else { return }
        
        let notification = AppNotification(
            id: UUID().uuidString,
            userId: postAuthor,
            type: .like,
            title: "New Like",
            message: "@\(likerUser.username) liked your post",
            relatedPostId: postId,
            relatedUserId: likedBy,
            relatedUsername: likerUser.username,
            createdAt: Date(),
            isRead: false,
            actionUrl: "app://post/\(postId)"
        )
        
        // TODO: Implement createNotification method
        try await authService.createNotification(notification: notification)
    }
    
    private func createCommentNotification(postId: String, commentedBy: String, postAuthor: String, commentContent: String) async throws {
        guard let commenterUser = try? await authService.getUser(userId: commentedBy) else { return }
        
        let notification = AppNotification(
            id: UUID().uuidString,
            userId: postAuthor,
            type: .comment,
            title: "New Comment",
            message: "@\(commenterUser.username) commented on your post",
            relatedPostId: postId,
            relatedUserId: commentedBy,
            relatedUsername: commenterUser.username,
            createdAt: Date(),
            isRead: false,
            actionUrl: "app://post/\(postId)"
        )
        
        // TODO: Implement createNotification method
        try await authService.createNotification(notification: notification)
    }
    
    private func handleError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Market News Helpers
    private func getCachedNews() async -> [MarketNewsArticle]? {
        let cacheKey = "market_news_cache"
        let timestampKey = "market_news_timestamp"
        
        guard let timestamp = UserDefaults.standard.object(forKey: timestampKey) as? Date,
              Date().timeIntervalSince(timestamp) < newsCacheInterval,
              let data = UserDefaults.standard.data(forKey: cacheKey),
              let cachedNews = try? JSONDecoder().decode([MarketNewsArticle].self, from: data) else {
            return nil
        }
        
        return cachedNews
    }
    
    private func cacheNews(_ news: [MarketNewsArticle]) async {
        let cacheKey = "market_news_cache"
        let timestampKey = "market_news_timestamp"
        
        if let data = try? JSONEncoder().encode(news) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: timestampKey)
        }
    }
    
    private func clearNewsCache() async {
        UserDefaults.standard.removeObject(forKey: "market_news_cache")
        UserDefaults.standard.removeObject(forKey: "market_news_timestamp")
    }
    
    private func fetchMarketNewsFromAPI(page: Int = 0) async throws -> [MarketNewsArticle] {
        let url = URL(string: "\(finnhubBaseUrl)/news?category=general&token=\(finnhubApiKey)&from=\(Date().addingTimeInterval(-86400 * 7).timeIntervalSince1970)&to=\(Date().timeIntervalSince1970)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let newsResponse = try JSONDecoder().decode([FinnhubNewsResponse].self, from: data)
        
        return newsResponse.compactMap { response in
            MarketNewsArticle(
                title: response.headline,
                summary: response.summary,
                publishedUtc: Date(timeIntervalSince1970: TimeInterval(response.datetime)),
                articleUrl: response.url,
                description: response.summary,
                imageUrl: response.image,
                source: response.source,
                category: response.category,
                tickerSymbols: response.related?.components(separatedBy: ",") ?? []
            )
        }
    }
    
    // MARK: - Statistics Methods
    func getEngagementStats() -> EngagementStats {
        let totalPosts = posts.count
        let totalLikes = posts.reduce(0) { $0 + $1.likesCount }
        let totalComments = posts.reduce(0) { $0 + $1.commentsCount }
        let totalShares = posts.reduce(0) { $0 + $1.sharesCount }
        let totalViews = viewedPosts.count
        
        return EngagementStats(
            totalPosts: totalPosts,
            totalLikes: totalLikes,
            totalComments: totalComments,
            totalShares: totalShares,
            totalViews: totalViews
        )
    }
    
    func getTrendingNews() -> [MarketNewsArticle] {
        return Array(marketNews.prefix(5))
    }
    
    func getRegularNews() -> [MarketNewsArticle] {
        return Array(marketNews.dropFirst(5))
    }
    
    func getSuggestedUsers() async -> [User] {
        // TODO: Implement user suggestion logic
        return []
    }
    
    // MARK: - Scroll to Top
    func scrollToTop() {
        // This would be handled by the views
        objectWillChange.send()
    }
}
