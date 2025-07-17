// File: Core/Home/ViewModels/HomeViewModel.swift
// SIMPLIFY - Just get it working

import Foundation
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Basic Properties Only
    @Published var posts: [Post] = []
    @Published var followingPosts: [Post] = []
    @Published var marketNews: [MarketNewsArticle] = []
    @Published var notifications: [UserNotification] = []
    
    // Basic loading states
    @Published var isLoading = false
    @Published var isLoadingNews = false
    @Published var isLoadingFollowing = false
    
    // Basic error handling
    @Published var errorMessage = ""
    @Published var showError = false
    
    // Basic search
    @Published var searchQuery = ""
    
    // Basic UI states
    @Published var showingCreatePost = false
    @Published var showingPostDetail = false
    @Published var showingNotifications = false
    @Published var selectedPost: Post?
    
    // Basic notification state
    @Published var hasUnreadNotifications = false
    
    private let authService = FirebaseAuthService.shared
    
    // MARK: - Basic Init
    init() {
        // Load some basic data
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Basic Data Loading
    func loadInitialData() async {
        await loadFeed()
        await loadFollowingFeed()
        await loadMarketNews()
    }
    
    func loadFeed() async {
        isLoading = true
        
        do {
            posts = try await authService.getFeedPosts(limit: 20)
        } catch {
            errorMessage = "Failed to load feed"
            showError = true
        }
        
        isLoading = false
    }
    
    func loadFollowingFeed() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoadingFollowing = true
        
        do {
            followingPosts = try await authService.getFollowingPosts(userId: userId, limit: 20)
        } catch {
            print("Failed to load following feed")
        }
        
        isLoadingFollowing = false
    }
    
    func loadMarketNews() async {
        isLoadingNews = true
        
        do {
            marketNews = try await authService.getCachedMarketNews()
        } catch {
            print("Failed to load market news")
        }
        
        isLoadingNews = false
    }
    
    // MARK: - Basic Post Creation
    func createPost(content: String, postType: PostType, imageUrls: [String] = []) async {
        guard let currentUser = authService.currentUser else { return }
        
        let newPost = Post(content: content, authorId: currentUser.id, authorUsername: currentUser.username)
        
        do {
            try await authService.createPost(newPost)
            posts.insert(newPost, at: 0)
        } catch {
            errorMessage = "Failed to create post"
            showError = true
        }
    }
    
    // MARK: - Basic Navigation
    func showCreatePost() {
        showingCreatePost = true
    }
    
    func showPostDetail(post: Post) {
        selectedPost = post
        showingPostDetail = true
    }
    
    // MARK: - Basic Search
    func clearSearch() {
        searchQuery = ""
    }
    
    // MARK: - Basic Computed Properties
    var filteredPosts: [Post] {
        if searchQuery.isEmpty {
            return posts
        }
        return posts.filter { $0.content.lowercased().contains(searchQuery.lowercased()) }
    }
    
    // MARK: - Basic News Helpers
    func getTrendingNews() -> [MarketNewsArticle] {
        return Array(marketNews.prefix(3))
    }
    
    func getRegularNews() -> [MarketNewsArticle] {
        return Array(marketNews.dropFirst(3))
    }
    
    // MARK: - Basic Scroll
    func scrollToTop() {
        // Just trigger refresh
        objectWillChange.send()
    }
}
