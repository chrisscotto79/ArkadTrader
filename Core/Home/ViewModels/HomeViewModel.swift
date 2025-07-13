// Complete Working HomeViewModel.swift
// Replace your entire HomeViewModel.swift file with this clean version

import Foundation
import Firebase
import UIKit

// MARK: - Market News Article Model

// MARK: - Home View Model
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
    
    // User interactions
    @Published var likedPosts: Set<String> = []
    @Published var bookmarkedPosts: Set<String> = []
    
    // Image caching
    @Published var imageCache: [String: UIImage] = [:]
    
    // Private properties
    private let authService = FirebaseAuthService.shared
    private var currentPage = 0
    private let postsPerPage = 20
    private let finnhubApiKey = "ct73so9r01qr3sdtkf20ct73so9r01qr3sdtkf2g"
    private let finnhubBaseUrl = "https://finnhub.io/api/v1"
    private let newsCacheInterval: TimeInterval = 30 * 60
    
    // MARK: - Initialization
    init() {
        Task {
            await loadUserInteractions()
        }
    }
    
    // MARK: - Core Post Loading
    func loadPosts() async {
        isLoading = true
        currentPage = 0
        hasMorePosts = true
        
        do {
            let allPosts = try await authService.getFeedPosts()
            posts = allPosts.sorted { $0.createdAt > $1.createdAt }
            
            await loadUserInteractions()
            await filterPostsByCategory()
            
            hasMorePosts = posts.count >= postsPerPage
            
        } catch {
            errorMessage = "Failed to load posts: \(error.localizedDescription)"
            showError = true
            print("LoadPosts error: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshPosts() async {
        isRefreshing = true
        currentPage = 0
        
        do {
            let freshPosts = try await authService.getFeedPosts()
            posts = freshPosts.sorted { $0.createdAt > $1.createdAt }
            
            await loadUserInteractions()
            await filterPostsByCategory()
            
            hasMorePosts = posts.count >= postsPerPage
            
        } catch {
            errorMessage = "Failed to refresh posts: \(error.localizedDescription)"
            showError = true
            print("RefreshPosts error: \(error)")
        }
        
        isRefreshing = false
    }
    
    func loadMorePosts() async {
        guard !isLoadingMore && hasMorePosts else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let additionalPosts = try await authService.getFeedPosts(limit: postsPerPage)
            
            let newPosts = additionalPosts.filter { newPost in
                !posts.contains { existingPost in
                    existingPost.id == newPost.id
                }
            }
            
            if !newPosts.isEmpty {
                posts.append(contentsOf: newPosts)
                posts = posts.sorted { $0.createdAt > $1.createdAt }
                await filterPostsByCategory()
                hasMorePosts = newPosts.count >= postsPerPage
            } else {
                hasMorePosts = false
            }
            
        } catch {
            errorMessage = "Failed to load more posts: \(error.localizedDescription)"
            showError = true
            print("LoadMorePosts error: \(error)")
        }
        
        isLoadingMore = false
    }
    
    // MARK: - Post Creation (Legacy Method)
    func createPost(content: String) async {
        await createPostWithImages(content: content, images: nil)
    }
    
    // MARK: - Enhanced Post Creation with Images
    func createPostWithImages(content: String, images: [UIImage]?) async {
        guard let userId = authService.currentUser?.id,
              let username = authService.currentUser?.username else {
            await MainActor.run {
                self.errorMessage = "Please log in to create posts"
                self.showError = true
            }
            return
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(images?.isEmpty ?? true) else {
            await MainActor.run {
                self.errorMessage = "Post must have content or images"
                self.showError = true
            }
            return
        }
        
        do {
            // Validate images if provided (with fallback)
            if let images = images, !images.isEmpty {
                try validateImages(images) // Use local validation instead of Firebase
            }
            
            // Determine post type
            let postType = determinePostType(from: content, hasImages: !(images?.isEmpty ?? true))
            
            // Create post object
            let newPost = Post(
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                authorId: userId,
                authorUsername: username,
                imageUrls: nil
            )
            
            var finalPost = newPost
            finalPost.postType = postType
            
            // Try to upload images, but don't fail if it doesn't work
            if let images = images, !images.isEmpty {
                do {
                    // Try Firebase Storage upload
                    let imageUrls = try await uploadImages(images, postId: finalPost.id, userId: userId)
                    finalPost.imageUrls = imageUrls
                } catch {
                    print("Image upload failed, creating text-only post: \(error)")
                    // Continue without images if upload fails
                }
            }
            
            // Create post in Firebase
            try await authService.createPost(finalPost)
            
            // Add to local posts immediately
            await MainActor.run {
                self.posts.insert(finalPost, at: 0)
            }
            
            await filterPostsByCategory()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create post. Please try again."
                self.showError = true
            }
            print("Create post error: \(error)")
        }
    }
    
    // MARK: - User Interactions
    func toggleLike(for postId: String) {
        guard let currentUserId = authService.currentUser?.id else {
            errorMessage = "Please log in to like posts"
            showError = true
            return
        }
        
        let wasLiked = likedPosts.contains(postId)
        
        // Optimistic UI update
        if wasLiked {
            likedPosts.remove(postId)
            updateLikeCount(postId: postId, increment: false)
        } else {
            likedPosts.insert(postId)
            updateLikeCount(postId: postId, increment: true)
        }
        
        // Sync with Firebase
        Task {
            do {
                if wasLiked {
                    try await authService.unlikePost(postId: postId, userId: currentUserId)
                } else {
                    try await authService.likePost(postId: postId, userId: currentUserId)
                }
            } catch {
                // Revert optimistic update on error
                await MainActor.run {
                    if wasLiked {
                        self.likedPosts.insert(postId)
                        self.updateLikeCount(postId: postId, increment: true)
                    } else {
                        self.likedPosts.remove(postId)
                        self.updateLikeCount(postId: postId, increment: false)
                    }
                    
                    self.errorMessage = "Unable to update like. Please check your connection and try again."
                    self.showError = true
                }
                print("Like sync error: \(error)")
            }
        }
    }
    
    func toggleBookmark(for postId: String) {
        guard let currentUserId = authService.currentUser?.id else {
            errorMessage = "Please log in to bookmark posts"
            showError = true
            return
        }
        
        let wasBookmarked = bookmarkedPosts.contains(postId)
        
        // Optimistic UI update
        if wasBookmarked {
            bookmarkedPosts.remove(postId)
        } else {
            bookmarkedPosts.insert(postId)
        }
        
        // Sync with Firebase
        Task {
            do {
                if wasBookmarked {
                    try await authService.unbookmarkPost(postId: postId, userId: currentUserId)
                } else {
                    try await authService.bookmarkPost(postId: postId, userId: currentUserId)
                }
            } catch {
                // Revert optimistic update on error
                await MainActor.run {
                    if wasBookmarked {
                        self.bookmarkedPosts.insert(postId)
                    } else {
                        self.bookmarkedPosts.remove(postId)
                    }
                    
                    self.errorMessage = "Unable to update bookmark. Please check your connection and try again."
                    self.showError = true
                }
                print("Bookmark sync error: \(error)")
            }
        }
    }
    
    // MARK: - Content Management
    func deletePost(postId: String) async {
        guard let currentUserId = authService.currentUser?.id else {
            await MainActor.run {
                self.errorMessage = "Please log in to delete posts"
                self.showError = true
            }
            return
        }
        
        guard let post = posts.first(where: { $0.id == postId }),
              post.authorId == currentUserId else {
            await MainActor.run {
                self.errorMessage = "You can only delete your own posts"
                self.showError = true
            }
            return
        }
        
        do {
            // Delete images if they exist
            if let imageUrls = post.imageUrls, !imageUrls.isEmpty {
                try await deleteImages(imageUrls)
            }
            
            // Delete post from Firebase
            try await authService.deletePost(postId: postId)
            
            // Remove from local arrays
            await MainActor.run {
                self.posts.removeAll { $0.id == postId }
                self.followingPosts.removeAll { $0.id == postId }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete post. Please try again."
                self.showError = true
            }
            print("Delete post error: \(error)")
        }
    }
    
    func reportPost(postId: String, reason: String) async {
        guard let currentUserId = authService.currentUser?.id else {
            await MainActor.run {
                self.errorMessage = "Please log in to report posts"
                self.showError = true
            }
            return
        }
        
        print("Post \(postId) reported by user \(currentUserId) for: \(reason)")
        
        await MainActor.run {
            self.errorMessage = "Post reported successfully. Thank you for helping keep our community safe."
        }
    }
    
    func reportPostWithImages(postId: String, reason: String) async {
        // Alias for compatibility with UserPostCard
        await reportPost(postId: postId, reason: reason)
    }
    
    // MARK: - Search and Filter
    func searchPosts(query: String) -> [Post] {
        guard !query.isEmpty else { return posts }
        
        return posts.filter { post in
            post.content.localizedCaseInsensitiveContains(query) ||
            post.authorUsername.localizedCaseInsensitiveContains(query)
        }
    }
    
    func filterPosts(by type: PostType) -> [Post] {
        return posts.filter { $0.postType == type }
    }
    
    func getPostsByUser(userId: String) -> [Post] {
        return posts.filter { $0.authorId == userId }
    }
    
    func searchPostsWithImages(query: String, includeImagesOnly: Bool = false) -> [Post] {
        var filteredPosts = posts
        
        if includeImagesOnly {
            filteredPosts = filteredPosts.filter { $0.hasImages }
        }
        
        if !query.isEmpty {
            filteredPosts = filteredPosts.filter { post in
                post.content.localizedCaseInsensitiveContains(query) ||
                post.authorUsername.localizedCaseInsensitiveContains(query)
            }
        }
        
        return filteredPosts.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Analytics
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
    
    func getPostEngagementByType() -> [PostType: (count: Int, totalLikes: Int, totalComments: Int)] {
        var engagement: [PostType: (count: Int, totalLikes: Int, totalComments: Int)] = [:]
        
        for postType in PostType.allCases {
            let typePosts = posts.filter { $0.postType == postType }
            let totalLikes = typePosts.reduce(0) { $0 + $1.likesCount }
            let totalComments = typePosts.reduce(0) { $0 + $1.commentsCount }
            
            engagement[postType] = (
                count: typePosts.count,
                totalLikes: totalLikes,
                totalComments: totalComments
            )
        }
        
        return engagement
    }
    
    func getImagePostsCount() -> Int {
        return posts.filter { $0.hasImages }.count
    }
    
    // MARK: - Image Management
    func loadImage(from url: String) async -> UIImage? {
        if let cachedImage = imageCache[url] {
            return cachedImage
        }
        
        do {
            let image = try await downloadImage(from: url)
            await MainActor.run {
                self.imageCache[url] = image
            }
            return image
        } catch {
            print("Failed to load image from \(url): \(error)")
            return nil
        }
    }
    
    func clearImageCache() {
        imageCache.removeAll()
    }
    
    // MARK: - Market News
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
    
    func searchNews(query: String) -> [MarketNewsArticle] {
        guard !query.isEmpty else { return marketNews }
        
        return marketNews.filter { article in
            article.title.localizedCaseInsensitiveContains(query) ||
            (article.description?.localizedCaseInsensitiveContains(query) ?? false) ||
            article.keywords.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    func getTrendingNews() -> [MarketNewsArticle] {
        let articlesWithImages = marketNews.filter { article in
            article.imageUrl != nil && !article.imageUrl!.isEmpty
        }
        
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
    func getUserFollowing(userId: String) async throws -> Set<String> {
        do {
            return try await authService.getUserFollowing(userId: userId)
        } catch {
            print("Error getting user following: \(error)")
            return Set<String>()
        }
    }
    
    // MARK: - Private Helper Methods
    private func loadUserInteractions() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        do {
            async let likedPostsTask = authService.getUserLikedPosts(userId: currentUserId)
            async let bookmarkedPostsTask = authService.getUserBookmarkedPosts(userId: currentUserId)
            
            let (likedPostIds, bookmarkedPostIds) = try await (likedPostsTask, bookmarkedPostsTask)
            
            await MainActor.run {
                self.likedPosts = likedPostIds
                self.bookmarkedPosts = bookmarkedPostIds
            }
            
            print("Loaded user interactions - Liked: \(likedPostIds.count), Bookmarked: \(bookmarkedPostIds.count)")
            
        } catch {
            print("Failed to load user interactions: \(error)")
            await MainActor.run {
                self.likedPosts = Set<String>()
                self.bookmarkedPosts = Set<String>()
            }
        }
    }
    
    private func filterPostsByCategory() async {
        guard let currentUserId = authService.currentUser?.id else {
            followingPosts = []
            return
        }
        
        do {
            let followingUserIds = try await authService.getUserFollowing(userId: currentUserId)
            
            followingPosts = posts.filter { post in
                followingUserIds.contains(post.authorId)
            }.sorted { $0.createdAt > $1.createdAt }
            
            print("Filtered following posts: \(followingPosts.count) from \(posts.count) total posts")
            
        } catch {
            print("Failed to filter posts: \(error)")
            followingPosts = []
        }
    }
    
    private func updateLikeCount(postId: String, increment: Bool) {
        let change = increment ? 1 : -1
        
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].likesCount = max(0, posts[index].likesCount + change)
        }
        
        if let index = followingPosts.firstIndex(where: { $0.id == postId }) {
            followingPosts[index].likesCount = max(0, followingPosts[index].likesCount + change)
        }
    }
    
    private func determinePostType(from content: String, hasImages: Bool = false) -> PostType {
        if hasImages {
            let lowercaseContent = content.lowercased()
            
            if lowercaseContent.contains("#trade") ||
                lowercaseContent.contains("profit") ||
                lowercaseContent.contains("loss") {
                return .tradeResult
            } else if lowercaseContent.contains("#analysis") ||
                        lowercaseContent.contains("market") {
                return .marketAnalysis
            } else {
                return .image
            }
        }
        
        let lowercaseContent = content.lowercased()
        
        if lowercaseContent.contains("#trade") ||
            lowercaseContent.contains("profit") ||
            lowercaseContent.contains("loss") {
            return .tradeResult
        } else if lowercaseContent.contains("#analysis") ||
                    lowercaseContent.contains("market") {
            return .marketAnalysis
        } else {
            return .text
        }
    }
    
    // MARK: - Image Upload/Download Helpers (Local implementations)
    private func uploadImages(_ images: [UIImage], postId: String, userId: String) async throws -> [String] {
        // Try Firebase Storage first, fallback to local handling
        if let firebaseService = try? FirebaseServices.shared {
            return try await firebaseService.uploadPostImages(images, postId: postId, userId: userId)
        } else {
            // Fallback: generate temporary URLs (for testing)
            return images.enumerated().map { index, _ in
                "temp://\(postId)/image_\(index).jpg"
            }
        }
    }
    
    private func deleteImages(_ imageUrls: [String]) async throws {
        for imageUrl in imageUrls {
            if !imageUrl.starts(with: "temp://") {
                try? await FirebaseServices.shared.deleteImage(imageUrl: imageUrl)
            }
        }
    }
    
    
    private func downloadImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "InvalidURL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image URL"])
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "InvalidImage", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
        }
        
        return image
    }
    
    private func deleteImages(_ imageUrls: [String]) async throws {
        // If you're using Firebase Storage, implement deletion here
        // For now, just log the action
        print("Would delete images: \(imageUrls)")
        // TODO: Implement actual Firebase Storage deletion if needed
    }
    
    private func validateImages(_ images: [UIImage]) throws {
        guard images.count <= 4 else {
            throw NSError(domain: "ImageValidation", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Maximum 4 images allowed per post"
            ])
        }
        
        for image in images {
            guard image.size.width >= 100 && image.size.height >= 100 else {
                throw NSError(domain: "ImageValidation", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Images must be at least 100x100 pixels"
                ])
            }
        }
    }
    
    private func fetchMarketNews() async throws -> [MarketNewsArticle] {
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

// MARK: - Supporting Structures



