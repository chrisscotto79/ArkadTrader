// Fixed HomeViewModel.swift - No new files, just fix the existing code
import Foundation
import Firebase

// Add MarketNewsArticle to existing HomeViewModel file instead of creating new file
struct MarketNewsArticle: Identifiable, Codable {
    let id: String
    let title: String
    let author: String?
    let publishedUtc: String
    let articleUrl: String
    let description: String?
    let keywords: [String]
    let imageUrl: String?
    let cachedAt: Date
    let source: String?
    let category: String?
    
    init(id: String, title: String, author: String?, publishedUtc: String, articleUrl: String, description: String?, keywords: [String], imageUrl: String?, cachedAt: Date, source: String?, category: String?) {
        self.id = id
        self.title = title
        self.author = author
        self.publishedUtc = publishedUtc
        self.articleUrl = articleUrl
        self.description = description
        self.keywords = keywords
        self.imageUrl = imageUrl
        self.cachedAt = cachedAt
        self.source = source
        self.category = category
    }
    
    // Firebase conversion methods
    func toFirestore() -> [String: Any] {
        return [
            "title": title,
            "author": author as Any,
            "publishedUtc": publishedUtc,
            "articleUrl": articleUrl,
            "description": description as Any,
            "keywords": keywords,
            "imageUrl": imageUrl as Any,
            "cachedAt": Timestamp(date: cachedAt),
            "source": source as Any,
            "category": category as Any
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> MarketNewsArticle {
        guard let title = data["title"] as? String,
              let publishedUtc = data["publishedUtc"] as? String,
              let articleUrl = data["articleUrl"] as? String,
              let keywords = data["keywords"] as? [String],
              let cachedAtTimestamp = data["cachedAt"] as? Timestamp else {
            throw NSError(domain: "MarketNewsArticleDecoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid market news article data"])
        }
        
        return MarketNewsArticle(
            id: id,
            title: title,
            author: data["author"] as? String,
            publishedUtc: publishedUtc,
            articleUrl: articleUrl,
            description: data["description"] as? String,
            keywords: keywords,
            imageUrl: data["imageUrl"] as? String,
            cachedAt: cachedAtTimestamp.dateValue(),
            source: data["source"] as? String,
            category: data["category"] as? String
        )
    }
}

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var posts: [Post] = []
    @Published var followingPosts: [Post] = []
    @Published var marketNews: [MarketNewsArticle] = []
    @Published var isLoading = false
    @Published var isLoadingNews = false
    @Published var isRefreshing = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    // Feed management
    @Published var hasMorePosts = true
    @Published var isLoadingMore = false
    
    // User interactions - loaded from Firebase
    @Published var likedPosts: Set<String> = []
    @Published var bookmarkedPosts: Set<String> = []
    
    private let authService = FirebaseAuthService.shared
    private var currentPage = 0
    private let postsPerPage = 20
    
    // Finnhub API configuration
    private let finnhubApiKey = "ct73so9r01qr3sdtkf20ct73so9r01qr3sdtkf2g"
    private let finnhubBaseUrl = "https://finnhub.io/api/v1"
    
    // News caching - refresh every 30 minutes
    private let newsCacheInterval: TimeInterval = 30 * 60
    
    // MARK: - Initialization
    init() {
        Task {
            await loadUserInteractions()
        }
    }
    
    // MARK: - Post Management
    func loadPosts() async {
        isLoading = true
        currentPage = 0
        
        do {
            // FIXED: Complete the getFeedPosts() method call
            let allPosts = try await authService.getFeedPosts()
            posts = allPosts
            
            // Load user interactions
            await loadUserInteractions()
            
            // Filter posts for different tabs
            await filterPostsByCategory()
            
        } catch {
            errorMessage = "Failed to load posts: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    func refreshPosts() async {
        isRefreshing = true
        await loadPosts()
        isRefreshing = false
    }
    
    func loadMorePosts() async {
        guard !isLoadingMore && hasMorePosts else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            // In a real implementation, you'd implement pagination in Firebase
            // For now, we'll just indicate there are no more posts after first load
            hasMorePosts = false
            
        } catch {
            errorMessage = "Failed to load more posts: \(error.localizedDescription)"
            showError = true
        }
        
        isLoadingMore = false
    }
    
    func createPost(content: String) async {
        guard let userId = authService.currentUser?.id,
              let username = authService.currentUser?.username else { return }
        
        // Determine post type based on content
        let postType = determinePostType(from: content)
        
        var newPost = Post(content: content, authorId: userId, authorUsername: username)
        newPost.postType = postType
        
        do {
            try await authService.createPost(newPost)
            
            // Add to local posts immediately for better UX
            posts.insert(newPost, at: 0)
            
            // Re-filter posts for different tabs
            await filterPostsByCategory()
            
        } catch {
            errorMessage = "Failed to create post: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // MARK: - User Interactions
    func toggleLike(for postId: String) {
        let wasLiked = likedPosts.contains(postId)
        
        if wasLiked {
            likedPosts.remove(postId)
            updateLikeCount(postId: postId, increment: false)
        } else {
            likedPosts.insert(postId)
            updateLikeCount(postId: postId, increment: true)
        }
        
        // Sync with Firebase immediately
        Task {
            await syncLikeWithFirebase(postId: postId, isLiked: !wasLiked)
        }
    }
    
    func toggleBookmark(for postId: String) {
        let wasBookmarked = bookmarkedPosts.contains(postId)
        
        if wasBookmarked {
            bookmarkedPosts.remove(postId)
        } else {
            bookmarkedPosts.insert(postId)
        }
        
        // Sync with Firebase immediately
        Task {
            await syncBookmarkWithFirebase(postId: postId, isBookmarked: !wasBookmarked)
        }
    }
    
    func reportPost(_ postId: String, reason: String) async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            // Store report in Firebase
            try await authService.reportPost(postId: postId, reportedBy: userId, reason: reason)
            
            // Remove post from local arrays
            posts.removeAll { $0.id == postId }
            followingPosts.removeAll { $0.id == postId }
            
        } catch {
            errorMessage = "Failed to report post: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func blockUser(_ userId: String) async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        do {
            // Store block in Firebase
            try await authService.blockUser(userId: userId, blockedBy: currentUserId)
            
            // Remove posts from blocked user
            posts.removeAll { $0.authorId == userId }
            followingPosts.removeAll { $0.authorId == userId }
            
        } catch {
            errorMessage = "Failed to block user: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // MARK: - Firebase Sync Methods
    private func syncLikeWithFirebase(postId: String, isLiked: Bool) async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            if isLiked {
                try await authService.likePost(postId: postId, userId: userId)
            } else {
                try await authService.unlikePost(postId: postId, userId: userId)
            }
        } catch {
            // Revert local change if Firebase sync fails
            if isLiked {
                likedPosts.remove(postId)
                updateLikeCount(postId: postId, increment: false)
            } else {
                likedPosts.insert(postId)
                updateLikeCount(postId: postId, increment: true)
            }
            
            errorMessage = "Failed to sync like: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func syncBookmarkWithFirebase(postId: String, isBookmarked: Bool) async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            if isBookmarked {
                try await authService.bookmarkPost(postId: postId, userId: userId)
            } else {
                try await authService.unbookmarkPost(postId: postId, userId: userId)
            }
        } catch {
            // Revert local change if Firebase sync fails
            if isBookmarked {
                bookmarkedPosts.remove(postId)
            } else {
                bookmarkedPosts.insert(postId)
            }
            
            errorMessage = "Failed to sync bookmark: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func loadUserInteractions() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            // Load liked posts from Firebase
            likedPosts = try await authService.getUserLikedPosts(userId: userId)
            
            // Load bookmarked posts from Firebase
            bookmarkedPosts = try await authService.getUserBookmarkedPosts(userId: userId)
            
        } catch {
            print("Failed to load user interactions: \(error)")
            // Don't show error to user for this, just log it
        }
    }
    
    // MARK: - Post Filtering and Categorization
    private func filterPostsByCategory() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        do {
            // Get user's following list from Firebase
            let followingUserIds = try await authService.getUserFollowing(userId: currentUserId)
            
            // Filter following posts
            followingPosts = posts.filter { post in
                followingUserIds.contains(post.authorId)
            }
            
        } catch {
            print("Failed to filter posts: \(error)")
            // Fallback to empty arrays if Firebase call fails
            followingPosts = []
        }
    }
    
    // MARK: - Helper Methods
    private func determinePostType(from content: String) -> PostType {
        let lowercaseContent = content.lowercased()
        
        if lowercaseContent.contains("#trade") ||
           lowercaseContent.contains("profit") ||
           lowercaseContent.contains("loss") ||
           lowercaseContent.contains("position") ||
           lowercaseContent.contains("buy") ||
           lowercaseContent.contains("sell") {
            return .tradeResult
        } else if lowercaseContent.contains("#analysis") ||
                  lowercaseContent.contains("market") ||
                  lowercaseContent.contains("bullish") ||
                  lowercaseContent.contains("bearish") ||
                  lowercaseContent.contains("technical") ||
                  lowercaseContent.contains("chart") {
            return .marketAnalysis
        } else {
            return .text
        }
    }
    
    private func updateLikeCount(postId: String, increment: Bool) {
        let change = increment ? 1 : -1
        
        // Update in main posts array
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].likesCount = max(0, posts[index].likesCount + change)
        }
        
        // Update in following posts array
        if let index = followingPosts.firstIndex(where: { $0.id == postId }) {
            followingPosts[index].likesCount = max(0, followingPosts[index].likesCount + change)
        }
    }
    
    // MARK: - Search and Filter
    func searchPosts(query: String) -> [Post] {
        guard !query.isEmpty else { return posts }
        
        return posts.filter { post in
            post.content.localizedCaseInsensitiveContains(query) ||
            post.authorUsername.localizedCaseInsensitiveContains(query)
        }
    }
    
    func searchNews(query: String) -> [MarketNewsArticle] {
        guard !query.isEmpty else { return marketNews }
        
        return marketNews.filter { article in
            article.title.localizedCaseInsensitiveContains(query) ||
            (article.description?.localizedCaseInsensitiveContains(query) ?? false) ||
            article.keywords.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    func filterPosts(by type: PostType) -> [Post] {
        return posts.filter { $0.postType == type }
    }
    
    func getPostsByUser(userId: String) -> [Post] {
        return posts.filter { $0.authorId == userId }
    }
    
    // MARK: - Analytics and Insights
    func getEngagementStats() -> (totalLikes: Int, totalComments: Int, totalPosts: Int) {
        let totalLikes = posts.reduce(0) { $0 + $1.likesCount }
        let totalComments = posts.reduce(0) { $0 + $1.commentsCount }
        let totalPosts = posts.count
        
        return (totalLikes, totalComments, totalPosts)
    }
    
    func getMostEngagedPost() -> Post? {
        return posts.max { post1, post2 in
            let engagement1 = post1.likesCount + post1.commentsCount
            let engagement2 = post2.likesCount + post2.commentsCount
            return engagement1 < engagement2
        }
    }
    
    func getTrendingNews() -> [MarketNewsArticle] {
        // For trending, prioritize articles with images but don't exclude others
        let articlesWithImages = marketNews.filter { article in
            article.imageUrl != nil && !article.imageUrl!.isEmpty
        }
        
        // If we have articles with images, use those, otherwise use all articles
        let trendingSource = articlesWithImages.isEmpty ? marketNews : articlesWithImages
        
        return Array(trendingSource.prefix(10))
    }
    
    func getRegularNews() -> [MarketNewsArticle] {
        // Return all news for the main feed
        return marketNews
    }
    
    func getNewsStats() -> (totalArticles: Int, recentArticles: Int) {
        let totalArticles = marketNews.count
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        
        let recentArticles = marketNews.filter { article in
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let publishedDate = isoFormatter.date(from: article.publishedUtc) {
                return publishedDate > oneDayAgo
            }
            return false
        }.count
        
        return (totalArticles, recentArticles)
    }
    
    // MARK: - Market News Management
    func loadMarketNews() async {
        isLoadingNews = true
        
        do {
            let articles = try await fetchMarketNews()
            marketNews = articles
        } catch {
            errorMessage = "Failed to load market news: \(error.localizedDescription)"
            showError = true
        }
        
        isLoadingNews = false
    }
    
    fileprivate func fetchMarketNews() async throws -> [MarketNewsArticle] {
        let urlString = "\(finnhubBaseUrl)/news?category=general&token=\(finnhubApiKey)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let newsItems = try JSONDecoder().decode([NewsItem].self, from: data)
        
        return newsItems.prefix(50).compactMap { item in
            MarketNewsArticle.fromNewsItem(item)
        }
    }
}

// MARK: - Supporting Structures for News (add to existing file)
fileprivate struct NewsItem: Codable {
    let id: Int
    let headline: String
    let summary: String
    let url: String
    let image: String
    let datetime: Int
    let source: String
    let category: String
    let related: String?
}

extension MarketNewsArticle {
    fileprivate static func fromNewsItem(_ item: NewsItem) -> MarketNewsArticle? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        let publishedDate = Date(timeIntervalSince1970: TimeInterval(item.datetime))
        let publishedUtc = formatter.string(from: publishedDate)
        
        let keywords = item.related?.components(separatedBy: ",") ?? []
        
        return MarketNewsArticle(
            id: String(item.id),
            title: item.headline,
            author: nil,
            publishedUtc: publishedUtc,
            articleUrl: item.url,
            description: item.summary,
            keywords: keywords,
            imageUrl: item.image.isEmpty ? nil : item.image,
            cachedAt: Date(),
            source: item.source,
            category: item.category
        )
    }
}
