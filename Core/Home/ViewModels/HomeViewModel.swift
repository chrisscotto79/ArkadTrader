// File: Core/Home/ViewModels/HomeViewModel.swift
// Updated Home View Model with Market News from Finnhub API

import Foundation
import SwiftUI
import Firebase

// MARK: - Market News Article Model (Updated for Finnhub)
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
    
    // For creating from Finnhub API response
    init(from finnhubData: [String: Any]) {
        self.id = finnhubData["id"] as? String ?? UUID().uuidString
        self.title = finnhubData["headline"] as? String ?? "Market Update"
        self.author = finnhubData["source"] as? String
        
        // Convert Unix timestamp to ISO string for consistency
        if let unixTime = finnhubData["datetime"] as? TimeInterval {
            let date = Date(timeIntervalSince1970: unixTime)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.publishedUtc = formatter.string(from: date)
        } else {
            self.publishedUtc = ISO8601DateFormatter().string(from: Date())
        }
        
        self.articleUrl = finnhubData["url"] as? String ?? ""
        self.description = finnhubData["summary"] as? String
        
        // Finnhub doesn't provide keywords, so we'll extract from category/source
        var extractedKeywords: [String] = []
        if let category = finnhubData["category"] as? String {
            extractedKeywords.append(category)
        }
        if let source = finnhubData["source"] as? String {
            extractedKeywords.append(source)
        }
        // Add some default financial keywords
        extractedKeywords.append(contentsOf: ["finance", "market", "news"])
        self.keywords = extractedKeywords
        
        self.imageUrl = finnhubData["image"] as? String
        self.source = finnhubData["source"] as? String
        self.category = finnhubData["category"] as? String
        self.cachedAt = Date()
        
        print("📰 Created Finnhub article: \(title)")
        print("🖼️ Image URL: \(imageUrl ?? "none")")
    }
    
    // For Firebase storage/retrieval
    func toFirestore() -> [String: Any] {
        return [
            "title": title,
            "author": author as Any,
            "publishedUtc": publishedUtc,
            "articleUrl": articleUrl,
            "description": description as Any,
            "keywords": keywords,
            "imageUrl": imageUrl as Any,
            "source": source as Any,
            "category": category as Any,
            "cachedAt": Timestamp(date: cachedAt)
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> MarketNewsArticle {
        guard let title = data["title"] as? String,
              let publishedUtc = data["publishedUtc"] as? String,
              let articleUrl = data["articleUrl"] as? String,
              let keywords = data["keywords"] as? [String] else {
            throw NSError(domain: "MarketNewsDecoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid news data"])
        }
        
        let cachedAt: Date
        if let timestamp = data["cachedAt"] as? Timestamp {
            cachedAt = timestamp.dateValue()
        } else if let date = data["cachedAt"] as? Date {
            cachedAt = date
        } else {
            cachedAt = Date()
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
            cachedAt: cachedAt,
            source: data["source"] as? String,
            category: data["category"] as? String
        )
    }
    
    private init(id: String, title: String, author: String?, publishedUtc: String, articleUrl: String, description: String?, keywords: [String], imageUrl: String?, cachedAt: Date, source: String?, category: String?) {
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
            // Load all posts from Firebase
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
    
    // MARK: - Market News Management (Updated for Finnhub)
    func loadMarketNews() async {
        isLoadingNews = true
        
        do {
            // First, try to load cached news from Firebase
            let cachedNews = try await authService.getCachedMarketNews()
            
            // Check if cached news is still fresh (less than 30 minutes old)
            if let latestNews = cachedNews.first,
               Date().timeIntervalSince(latestNews.cachedAt) < newsCacheInterval {
                marketNews = cachedNews
                isLoadingNews = false
                return
            }
            
            // If no fresh cached news, fetch from Finnhub API
            await fetchMarketNewsFromFinnhub()
            
        } catch {
            print("Error loading cached news, fetching fresh: \(error)")
            await fetchMarketNewsFromFinnhub()
        }
        
        isLoadingNews = false
    }
    
    private func fetchMarketNewsFromFinnhub() async {
        print("🔄 Fetching news from Finnhub API...")
        
        // Finnhub general news endpoint
        guard let url = URL(string: "\(finnhubBaseUrl)/news?category=general&token=\(finnhubApiKey)") else {
            print("❌ Invalid URL")
            errorMessage = "Invalid news URL"
            showError = true
            return
        }
        
        print("🌐 Finnhub API URL: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    errorMessage = "API returned status code: \(httpResponse.statusCode)"
                    showError = true
                    return
                }
            }
            
            // Parse JSON response - Finnhub returns an array directly
            guard let newsArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("❌ Failed to parse JSON array")
                errorMessage = "Invalid JSON response"
                showError = true
                return
            }
            
            print("✅ Found \(newsArray.count) articles from Finnhub")
            
            // Convert API response to MarketNewsArticle objects
            let newsArticles = newsArray.compactMap { articleData in
                print("📰 Processing article: \(articleData["headline"] ?? "No headline")")
                return MarketNewsArticle(from: articleData)
            }
            
            print("✅ Successfully created \(newsArticles.count) articles")
            
            // Sort by recency and relevance
            let sortedArticles = newsArticles.sorted { article1, article2 in
                let score1 = calculateTrendingScore(for: article1)
                let score2 = calculateTrendingScore(for: article2)
                return score1 > score2
            }
            
            // Update local state
            marketNews = sortedArticles
            print("🎉 Market news updated with \(sortedArticles.count) articles")
            
            // Cache news in Firebase for future use
            await cacheNewsInFirebase(articles: sortedArticles)
            
        } catch {
            print("❌ Network error: \(error)")
            print("🔍 Error details: \(error.localizedDescription)")
            errorMessage = "Network error: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func calculateTrendingScore(for article: MarketNewsArticle) -> Int {
        var score = 0
        
        // Boost for having an image
        if article.imageUrl != nil && !article.imageUrl!.isEmpty {
            score += 10
        }
        
        // Boost for trending keywords and sources
        let trendingKeywords = ["earnings", "stock", "market", "trading", "investment", "financial", "nasdaq", "sp500", "dow", "tesla", "apple", "microsoft", "amazon"]
        let trendingSources = ["Reuters", "Bloomberg", "MarketWatch", "CNBC", "Yahoo Finance"]
        
        for keyword in article.keywords {
            if trendingKeywords.contains(keyword.lowercased()) {
                score += 5
            }
        }
        
        if let source = article.source, trendingSources.contains(source) {
            score += 8
        }
        
        // Boost for recent articles (within last 6 hours)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let publishedDate = isoFormatter.date(from: article.publishedUtc) {
            let hoursAgo = Date().timeIntervalSince(publishedDate) / 3600
            if hoursAgo < 6 {
                score += 8
            } else if hoursAgo < 24 {
                score += 3
            }
        }
        
        return score
    }
    
    private func cacheNewsInFirebase(articles: [MarketNewsArticle]) async {
        do {
            try await authService.cacheMarketNews(articles: articles)
        } catch {
            print("Failed to cache news in Firebase: \(error)")
            // Don't show error to user since this is just caching
        }
    }
    
    // MARK: - Post Interactions (Firebase Storage)
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
}
