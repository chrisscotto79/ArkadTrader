// File: Core/Home/ViewModels/HomeViewModel.swift
// Fixed Home View Model - Firebase Storage Only, No Local Storage

import Foundation
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var posts: [Post] = []
    @Published var followingPosts: [Post] = []
    @Published var trendingPosts: [Post] = []
    @Published var isLoading = false
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
            trendingPosts.removeAll { $0.id == postId }
            
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
            trendingPosts.removeAll { $0.authorId == userId }
            
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
            
            // Filter trending posts (posts with high engagement)
            trendingPosts = posts.filter { post in
                let engagementScore = post.likesCount + (post.commentsCount * 2)
                return engagementScore >= 5 // Lower threshold since we're starting fresh
            }.sorted { $0.likesCount > $1.likesCount }
            
        } catch {
            print("Failed to filter posts: \(error)")
            // Fallback to empty arrays if Firebase call fails
            followingPosts = []
            trendingPosts = posts.filter { post in
                let engagementScore = post.likesCount + (post.commentsCount * 2)
                return engagementScore >= 5
            }.sorted { $0.likesCount > $1.likesCount }
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
        
        // Update in trending posts array
        if let index = trendingPosts.firstIndex(where: { $0.id == postId }) {
            trendingPosts[index].likesCount = max(0, trendingPosts[index].likesCount + change)
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
}
