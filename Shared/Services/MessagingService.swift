//
//  MessagingService.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//


// File: Shared/Services/MessagingService.swift

import Foundation

@MainActor
class MessagingService: ObservableObject {
    static let shared = MessagingService()
    private let networkService = NetworkService.shared
    
    @Published var conversations: [Conversation] = []
    @Published var messages: [String: [Message]] = [:] // conversationId -> messages
    @Published var unreadCount: Int = 0
    
    private init() {
        Task {
            await loadConversations()
        }
    }
    
    // MARK: - Conversations
    func loadConversations() async {
        do {
            self.conversations = try await networkService.getConversations()
            updateUnreadCount()
        } catch {
            print("Failed to load conversations: \(error)")
        }
    }
    
    func createConversation(with userId: String) async throws -> Conversation {
        // This would be handled by sending the first message
        // For now, create a local conversation
        guard let currentUserId = AuthService.shared.currentUser?.id else {
            throw MessagingError.userNotAuthenticated
        }
        
        let participantIds = [currentUserId, UUID(uuidString: userId) ?? UUID()]
        let conversation = Conversation(participantIds: participantIds)
        
        // In a real implementation, this would be created on the server
        // when the first message is sent
        return conversation
    }
    
    // MARK: - Messages
    func loadMessages(for conversationId: String) async {
        do {
            let messages = try await networkService.getMessages(conversationId: conversationId)
            self.messages[conversationId] = messages
        } catch {
            print("Failed to load messages: \(error)")
        }
    }
    
    func sendMessage(to recipientId: String, content: String, conversationId: String? = nil) async throws -> Message {
        let messageRequest = SendMessageRequest(
            recipientId: recipientId,
            content: content,
            conversationId: conversationId
        )
        
        do {
            let message = try await networkService.sendMessage(messageRequest)
            
            // Update local messages
            let convId = message.conversationId.uuidString
            if messages[convId] == nil {
                messages[convId] = []
            }
            messages[convId]?.append(message)
            
            // Reload conversations to update last message
            await loadConversations()
            
            return message
        } catch {
            print("Failed to send message: \(error)")
            throw error
        }
    }
    
    func markAsRead(conversationId: String) async {
        // Implement mark as read functionality
        // This would typically update the server and then reload conversations
        do {
            // Call API to mark messages as read
            // For now, just update local state
            if let conversationIndex = conversations.firstIndex(where: { $0.id.uuidString == conversationId }) {
                // Update unread count locally
                updateUnreadCount()
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateUnreadCount() {
        unreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
    }
    
    func getMessages(for conversationId: String) -> [Message] {
        return messages[conversationId] ?? []
    }
    
    func getConversation(with userId: String) -> Conversation? {
        let userUUID = UUID(uuidString: userId)
        return conversations.first { conversation in
            conversation.participantIds.contains(userUUID ?? UUID())
        }
    }
}

// MARK: - Messaging Errors
enum MessagingError: Error, LocalizedError {
    case userNotAuthenticated
    case conversationNotFound
    case messageSendFailed
    case invalidRecipient
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .conversationNotFound:
            return "Conversation not found"
        case .messageSendFailed:
            return "Failed to send message"
        case .invalidRecipient:
            return "Invalid recipient"
        }
    }
}

// File: Shared/Services/SearchService.swift

@MainActor
class SearchService: ObservableObject {
    static let shared = SearchService()
    private let networkService = NetworkService.shared
    
    @Published var searchResults: [SearchResult] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching = false
    
    private init() {
        loadRecentSearches()
    }
    
    // MARK: - Search Methods
    func searchUsers(query: String) async throws -> [User] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        isSearching = true
        
        do {
            let response = try await networkService.searchUsers(query: query)
            
            // Add to recent searches
            addToRecentSearches(query)
            
            isSearching = false
            return response.users
        } catch {
            isSearching = false
            print("User search failed: \(error)")
            throw error
        }
    }
    
    func searchAll(query: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return []
        }
        
        isSearching = true
        
        do {
            // Search users
            let userResponse = try await networkService.searchUsers(query: query)
            let userResults = userResponse.users.map { SearchResult(user: $0) }
            
            // In a real implementation, you'd also search posts, trades, etc.
            // For now, just return user results
            searchResults = userResults
            
            // Add to recent searches
            addToRecentSearches(query)
            
            isSearching = false
            return searchResults
        } catch {
            isSearching = false
            print("Search failed: \(error)")
            throw error
        }
    }
    
    func clearSearchResults() {
        searchResults = []
    }
    
    // MARK: - Recent Searches
    private func addToRecentSearches(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove if already exists
        recentSearches.removeAll { $0.lowercased() == trimmedQuery.lowercased() }
        
        // Add to beginning
        recentSearches.insert(trimmedQuery, at: 0)
        
        // Keep only last 10 searches
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        saveRecentSearches()
    }
    
    func clearRecentSearches() {
        recentSearches = []
        saveRecentSearches()
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "recent_searches")
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "recent_searches") ?? []
    }
    
    // MARK: - Search Suggestions
    func getSearchSuggestions(for query: String) -> [String] {
        let lowercaseQuery = query.lowercased()
        return recentSearches.filter { $0.lowercased().contains(lowercaseQuery) }
    }
    
    // MARK: - Popular Searches
    func getPopularSearches() -> [String] {
        // In a real implementation, this would come from the server
        return [
            "AAPL", "TSLA", "NVDA", "SPY", "QQQ",
            "day trading", "swing trading", "options",
            "crypto", "earnings"
        ]
    }
}

// File: Shared/Services/PostService.swift

@MainActor
class PostService: ObservableObject {
    static let shared = PostService()
    private let networkService = NetworkService.shared
    
    @Published var feedPosts: [Post] = []
    @Published var userPosts: [Post] = []
    @Published var isLoadingFeed = false
    @Published var isLoadingUserPosts = false
    
    private init() {}
    
    // MARK: - Feed Management
    func loadFeed(refresh: Bool = false) async {
        if refresh {
            isLoadingFeed = true
        }
        
        do {
            let posts = try await networkService.fetchFeed()
            self.feedPosts = posts
        } catch {
            print("Failed to load feed: \(error)")
        }
        
        isLoadingFeed = false
    }
    
    func loadUserPosts(for userId: String) async {
        isLoadingUserPosts = true
        
        do {
            // In a real implementation, you'd have a separate endpoint for user posts
            // For now, filter feed posts by user
            let allPosts = try await networkService.fetchFeed()
            self.userPosts = allPosts.filter { $0.authorId.uuidString == userId }
        } catch {
            print("Failed to load user posts: \(error)")
        }
        
        isLoadingUserPosts = false
    }
    
    // MARK: - Post Creation
    func createPost(content: String, imageURL: String? = nil, postType: PostType = .text, tradeId: String? = nil) async throws -> Post {
        let postRequest = CreatePostRequest(
            content: content,
            imageURL: imageURL,
            postType: postType,
            tradeId: tradeId
        )
        
        do {
            let post = try await networkService.createPost(postRequest)
            
            // Add to local feed
            feedPosts.insert(post, at: 0)
            
            return post
        } catch {
            print("Failed to create post: \(error)")
            throw error
        }
    }
    
    func createTradePost(for trade: Trade) async throws -> Post {
        let content = trade.shareableContent
        return try await createPost(
            content: content,
            postType: .tradeResult,
            tradeId: trade.id.uuidString
        )
    }
    
    // MARK: - Post Interactions
    func likePost(_ postId: String) async throws -> LikeResponse {
        do {
            let response = try await networkService.likePost(postId: postId)
            
            // Update local post
            updatePostLikes(postId: postId, isLiked: response.isLiked, likesCount: response.likesCount)
            
            return response
        } catch {
            print("Failed to like post: \(error)")
            throw error
        }
    }
    
    func unlikePost(_ postId: String) async throws -> LikeResponse {
        do {
            let response = try await networkService.unlikePost(postId: postId)
            
            // Update local post
            updatePostLikes(postId: postId, isLiked: response.isLiked, likesCount: response.likesCount)
            
            return response
        } catch {
            print("Failed to unlike post: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    private func updatePostLikes(postId: String, isLiked: Bool, likesCount: Int) {
        // Update in feed posts
        if let index = feedPosts.firstIndex(where: { $0.id.uuidString == postId }) {
            feedPosts[index].likesCount = likesCount
        }
        
        // Update in user posts
        if let index = userPosts.firstIndex(where: { $0.id.uuidString == postId }) {
            userPosts[index].likesCount = likesCount
        }
    }
    
    func getPost(by id: String) -> Post? {
        return feedPosts.first { $0.id.uuidString == id } ??
               userPosts.first { $0.id.uuidString == id }
    }
}

// MARK: - Post Errors
enum PostError: Error, LocalizedError {
    case contentTooLong
    case contentEmpty
    case imageUploadFailed
    case postCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .contentTooLong:
            return "Post content is too long"
        case .contentEmpty:
            return "Post content cannot be empty"
        case .imageUploadFailed:
            return "Failed to upload image"
        case .postCreationFailed:
            return "Failed to create post"
        }
    }
}