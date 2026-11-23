// Fixed HomeViewModel.swift - No new files, just fix the existing code
import Foundation
import Combine
import Firebase
import FirebaseStorage

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
    
    // MARK: - Publish date
    // publishedUtc is an ISO 8601 UTC string (e.g. "2026-11-22T14:05:00Z"), which also
    // sorts correctly as a string in Firestore. Finnhub gives unix seconds.
    
    static func utcString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
    
    /// Parses publishedUtc with or without fractional seconds.
    static func date(fromUTCString string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
    
    var publishedDate: Date? {
        MarketNewsArticle.date(fromUTCString: publishedUtc)
    }
    
    /// "Just now", "5m ago", "2h ago", "3d ago", then a short date.
    var relativePublishedText: String {
        guard let date = publishedDate else { return "" }
        let seconds = max(0, Date().timeIntervalSince(date))
        switch seconds {
        case ..<60:
            return "Just now"
        case ..<3600:
            return "\(Int(seconds / 60))m ago"
        case ..<86_400:
            return "\(Int(seconds / 3600))h ago"
        case ..<(7 * 86_400):
            return "\(Int(seconds / 86_400))d ago"
        default:
            return date.formatted(date: .abbreviated, time: .omitted)
        }
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
    
    @Published var hiddenPosts: Set<String> = []
    @Published var reportedPostsByUser: Set<String> = []
    
    func hideReportedPost(postId: String, reportedBy: String) {
        // Hide immediately for the reporter
        reportedPostsByUser.insert(postId)
        
        // Remove from visible posts arrays
        posts.removeAll { $0.id == postId }
        followingPosts.removeAll { $0.id == postId }
        
        print("✅ Hidden post \(postId) from user \(reportedBy)")
    }

    func checkAndHidePost(postId: String) async {
        // This will be called by Firebase when report count threshold is reached
        hiddenPosts.insert(postId)
        
        await MainActor.run {
            // Remove from all local arrays
            posts.removeAll { $0.id == postId }
            followingPosts.removeAll { $0.id == postId }
        }
        
        print("🚨 Auto-hidden post \(postId) due to multiple reports")
    }

    // Filter posts to exclude hidden ones
    private func filterHiddenPosts() {
        posts = posts.filter { post in
            !hiddenPosts.contains(post.id) &&
            !reportedPostsByUser.contains(post.id)
        }
        
        followingPosts = followingPosts.filter { post in
            !hiddenPosts.contains(post.id) &&
            !reportedPostsByUser.contains(post.id)
        }
    }
    
    private let authService = FirebaseAuthService.shared
    private let blockStore = BlockStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 0
    private let postsPerPage = 20
    
    // Finnhub API configuration
    private var finnhubApiKey: String { AppConfig.finnhubAPIKey }
    private let finnhubBaseUrl = "https://finnhub.io/api/v1"
    
    // News caching - refresh every 30 minutes
    private let newsCacheInterval: TimeInterval = 30 * 60
    
    // MARK: - Initialization
    init() {
        // Drop a person's posts as soon as they're blocked (from a profile, chat, anywhere)
        blockStore.$blockedIds
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] blockedIds in
                MainActor.assumeIsolated {
                    self?.removePosts(fromAuthors: blockedIds)
                }
            }
            .store(in: &cancellables)

        // Monitor authentication state
        Task {
            // Wait for authentication to complete
            while !authService.isAuthenticated {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            // Now load user interactions
            await loadUserInteractions()
        }
    }
    
    // MARK: - Post Management
    func loadPosts() async {
        isLoading = true
        currentPage = 0
        
        do {
            await blockStore.loadIfNeeded()
            let allPosts = try await authService.getFeedPosts()
            posts = allPosts.filter(isVisible)
            
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
        
        // Pagination isn't implemented yet; the first load returns everything.
        hasMorePosts = false
        
        isLoadingMore = false
    }
    
    func createPost(_ draft: PostDraft) async {
        await createPost(content: draft.content, tickers: draft.tickers, images: draft.images,
                         postType: draft.postType, trade: draft.trade, sentiment: draft.sentiment)
    }

    /// Without a postType, it's guessed from the text (for callers that don't have the composer's choice).
    /// A trade-result post needs `trade`, one of the author's own closed trades: its numbers and proof
    /// label are copied into `tradeSnapshot` (no typed-in P&L). Without one it's posted as a text post.
    func createPost(content: String, tickers: [String] = [], images: [UIImage] = [],
                    postType chosenType: PostType? = nil, trade: Trade? = nil,
                    sentiment: PostSentiment? = nil) async {
        guard let currentUser = authService.currentUser else { return }
        let userId = currentUser.id
        let username = currentUser.username
        
        var postType = chosenType ?? determinePostType(from: content)
        let snapshot = trade.flatMap { $0.userId == userId ? TradeSnapshot(trade: $0) : nil }
        if postType == .tradeResult && snapshot == nil {
            postType = .text
        }
        
        // Photos stay off until Cloud Storage is available (AppConfig.mediaUploadsEnabled)
        var imageUrls: [String] = []
        
        if AppConfig.mediaUploadsEnabled && !images.isEmpty {
            print("📸 Uploading \(images.count) images...")
            
            // Create a unique post ID for consistent image naming
            let postId = UUID().uuidString
            
            // Upload each image
            for (index, image) in images.enumerated() {
                do {
                    if let imageUrl = try await uploadImage(image, postId: postId, imageIndex: index) {
                        imageUrls.append(imageUrl)
                        print("✅ Uploaded image \(index + 1): \(imageUrl)")
                    } else {
                        print("⚠️ Failed to upload image \(index + 1)")
                    }
                } catch {
                    print("❌ Error uploading image \(index + 1): \(error)")
                }
            }
            
            print("📸 Successfully uploaded \(imageUrls.count)/\(images.count) images")
        }
        
        // Create post with uploaded image URLs
        var newPost = Post(
            content: content,
            authorId: userId,
            authorUsername: username,
            postType: postType,
            tickers: tickers,
            imageUrls: imageUrls // ✅ FIXED: Use actual uploaded URLs
        )
        newPost.authorFullName = currentUser.fullName
        newPost.authorAvatarURL = currentUser.profileImageUrl
        newPost.sentiment = sentiment
        
        // Trade result: the chosen closed trade. FirebaseServices.createPost copies the snapshot
        // from the trade document so it matches what the rules check.
        if postType == .tradeResult, let trade, let snapshot {
            newPost.tradeId = trade.id
            newPost.tradeSnapshot = snapshot
            if !newPost.tickers.contains(snapshot.ticker) {
                newPost.tickers.insert(snapshot.ticker, at: 0)
            }
        }
        
        do {
            try await authService.createPost(newPost)
            posts.insert(newPost, at: 0)
            await filterPostsByCategory()
            print("✅ Post created successfully with \(imageUrls.count) images")
        } catch {
            errorMessage = "Failed to create post: \(error.localizedDescription)"
            showError = true
            print("❌ Failed to create post: \(error)")
        }
    }

    // ✅ Add image upload method
    private func uploadImage(_ image: UIImage, postId: String, imageIndex: Int) async throws -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to data")
            return nil
        }
        
        let fileName = "\(postId)_\(imageIndex).jpg"
        let storageRef = Storage.storage().reference().child("post_images/\(fileName)")
        
        do {
            print("🔄 Uploading image: \(fileName)")
            let _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            print("✅ Image uploaded successfully: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("❌ Image upload failed: \(error)")
            throw error // ✅ FIXED: Throw error instead of returning nil
        }
    }

    
    // MARK: - User Interactions
    func toggleLike(for postId: String) {
        let wasLiked = likedPosts.contains(postId)
        
        // Update UI immediately for responsiveness
        if wasLiked {
            likedPosts.remove(postId)
        } else {
            likedPosts.insert(postId)
        }
        
        // Update local count immediately
        updateLocalPostCount(postId: postId, increment: !wasLiked)
        
        // Sync with Firebase (don't update count again)
        Task {
            await syncLikeWithFirebase(postId: postId, isLiked: !wasLiked)
        }
    }
    func updatePostCommentCount(postId: String, newCount: Int) {
        // Update in main posts array
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].commentsCount = newCount
        }
        
        // Update in following posts array
        if let index = followingPosts.firstIndex(where: { $0.id == postId }) {
            followingPosts[index].commentsCount = newCount
        }
        
        print("✅ Updated comment count for post \(postId) to \(newCount)")
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
        do {
            // Also removes follows both ways; the store's update drops their posts here
            try await blockStore.block(userId)
            removePosts(fromAuthors: [userId])
        } catch {
            errorMessage = "Failed to block user: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // MARK: - Blocked and hidden posts

    /// Hidden by reports, reported by you, or written by someone you blocked
    private func isVisible(_ post: Post) -> Bool {
        !post.isHidden
            && !hiddenPosts.contains(post.id)
            && !reportedPostsByUser.contains(post.id)
            && !blockStore.isBlocked(post.authorId)
    }

    private func removePosts(fromAuthors authorIds: Set<String>) {
        guard !authorIds.isEmpty else { return }
        posts.removeAll { authorIds.contains($0.authorId) }
        followingPosts.removeAll { authorIds.contains($0.authorId) }
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
            
            // ❌ REMOVE THIS SECTION - it's causing double counting
            // await MainActor.run {
            //     updateLocalPostCount(postId: postId, increment: isLiked)
            // }
            
            print("✅ Firebase sync successful - count already updated in UI")
            
        } catch {
            // Revert local like state if Firebase sync fails
            await MainActor.run {
                if isLiked {
                    likedPosts.remove(postId)
                } else {
                    likedPosts.insert(postId)
                }
                
                // Revert the count change too
                updateLocalPostCount(postId: postId, increment: !isLiked)
            }
            
            errorMessage = "Failed to sync like: \(error.localizedDescription)"
            showError = true
        }
    }

    // ✅ ADD THIS NEW METHOD
    private func updateLocalPostCount(postId: String, increment: Bool) {
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
            likedPosts = try await authService.getUserLikedPosts(userId: userId)
            bookmarkedPosts = try await authService.getUserBookmarkedPosts(userId: userId)
        } catch {
            // Likes and bookmarks just show as unset; the feed itself still loads.
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
    
    /// The newest few articles that have a picture, shown as large cards.
    /// (Finnhub returns general news newest-first; there is no popularity signal.)
    func getTopStories() -> [MarketNewsArticle] {
        let articlesWithImages = marketNews.filter { article in
            if let imageUrl = article.imageUrl { return !imageUrl.isEmpty }
            return false
        }
        return Array(articlesWithImages.prefix(5))
    }
    
    /// Every other article, newest first.
    func getRegularNews() -> [MarketNewsArticle] {
        let topIds = Set(getTopStories().map { $0.id })
        return marketNews.filter { !topIds.contains($0.id) }
    }
    
    func getNewsStats() -> (totalArticles: Int, recentArticles: Int) {
        let totalArticles = marketNews.count
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        
        let recentArticles = marketNews.filter { article in
            guard let publishedDate = article.publishedDate else { return false }
            return publishedDate > oneDayAgo
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
        guard !finnhubApiKey.isEmpty else { return [] }
        let urlString = "\(finnhubBaseUrl)/news?category=general&token=\(finnhubApiKey)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let newsItems = try JSONDecoder().decode([NewsItem].self, from: data)
        
        return newsItems
            .sorted { $0.datetime > $1.datetime }
            .prefix(50)
            .compactMap { item in
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
        // Finnhub's datetime is unix seconds (UTC)
        let publishedDate = Date(timeIntervalSince1970: TimeInterval(item.datetime))
        let publishedUtc = MarketNewsArticle.utcString(from: publishedDate)
        
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
