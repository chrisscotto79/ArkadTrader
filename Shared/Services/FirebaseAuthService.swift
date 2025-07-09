// File: Shared/Services/FirebaseAuthService.swift
// Complete Firebase Auth Service with all required wrapper methods

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    
    private var handle: AuthStateDidChangeListenerHandle?
    private let auth = Auth.auth()
    
    private init() {
        setupAuthListener()
    }
    
    // MARK: - Auth State Management
    
    private func setupAuthListener() {
        handle = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                if let firebaseUser = firebaseUser {
                    self?.isAuthenticated = true
                    await self?.loadCurrentUser(firebaseUser.uid)
                } else {
                    self?.isAuthenticated = false
                    self?.currentUser = nil
                }
                self?.isLoading = false
            }
        }
    }
    
    private func loadCurrentUser(_ userId: String) async {
        do {
            currentUser = try await FirebaseServices.shared.getUserById(userId: userId)
        } catch {
            print("Error loading current user: \(error)")
            currentUser = nil
        }
    }
    
    // MARK: - Authentication Methods
    
    func login(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        await loadCurrentUser(result.user.uid)
    }
    
    func signIn(email: String, password: String) async throws {
        try await login(email: email, password: password)
    }
    
    func register(email: String, password: String, username: String, fullName: String) async throws {
        // Check if username is available
        let usernameAvailable = try await isUsernameAvailable(username)
        guard usernameAvailable else {
            throw AuthError.usernameTaken
        }
        
        // Create auth user
        let result = try await auth.createUser(withEmail: email, password: password)
        
        // Create user document
        let newUser = User(
            id: result.user.uid,
            email: email,
            username: username,
            fullName: fullName
        )
        
        try await FirebaseServices.shared.createUser(newUser)
        currentUser = newUser
    }
    
    func signUp(email: String, password: String, fullName: String, username: String) async throws {
        try await register(email: email, password: password, username: username, fullName: fullName)
    }
    
    func logout() async {
        do {
            try auth.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    func signOut() throws {
        try auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }
    
    func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.notAuthenticated
        }
        
        // Delete user data from Firestore
        if let currentUser = currentUser {
            // Delete user document
            try await Firestore.firestore().collection("users").document(currentUser.id).delete()
        }
        
        // Delete auth account
        try await user.delete()
        
        self.currentUser = nil
        isAuthenticated = false
    }
    
    // MARK: - Username Validation
    
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .whereField("username", isEqualTo: username.lowercased())
            .getDocuments()
        
        return snapshot.documents.isEmpty
    }
    
    // MARK: - Password Reset
    
    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    func resetPassword(email: String) async throws {
        try await sendPasswordReset(email: email)
    }
    
    // MARK: - Profile Updates
    
    func updateProfile(fullName: String? = nil, bio: String? = nil, username: String? = nil) async throws {
        guard var user = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        if let fullName = fullName {
            user.fullName = fullName
        }
        
        if let bio = bio {
            user.bio = bio
        }
        
        if let username = username, username != user.username {
            let available = try await isUsernameAvailable(username)
            guard available else {
                throw AuthError.usernameTaken
            }
            user.username = username
        }
        
        try await FirebaseServices.shared.updateUser(user)
        currentUser = user
    }
    
    // MARK: - User Management Wrapper Methods
    
    func getUserById(userId: String) async throws -> User? {
        return try await FirebaseServices.shared.getUserById(userId: userId)
    }
    
    func updateUserStats(userId: String, totalProfitLoss: Double, winRate: Double) async throws {
        try await FirebaseServices.shared.updateUserStats(userId: userId, totalProfitLoss: totalProfitLoss, winRate: winRate)
    }
    
    func followUser(userId: String, followerId: String) async throws {
        try await FirebaseServices.shared.followUser(userId: userId, followerId: followerId)
    }
    
    func unfollowUser(userId: String, followerId: String) async throws {
        try await FirebaseServices.shared.unfollowUser(userId: userId, followerId: followerId)
    }
    
    func getUserFollowing(userId: String) async throws -> Set<String> {
        return try await FirebaseServices.shared.getUserFollowing(userId: userId)
    }
    
    func getUserFollowers(userId: String) async throws -> Set<String> {
        return try await FirebaseServices.shared.getUserFollowers(userId: userId)
    }
    
    func isFollowing(userId: String, targetUserId: String) async throws -> Bool {
        return try await FirebaseServices.shared.isFollowing(userId: userId, targetUserId: targetUserId)
    }
    
    // MARK: - Trade Management Wrapper Methods
    
    func addTrade(_ trade: Trade) async throws {
        try await FirebaseServices.shared.addTrade(trade)
    }
    
    func updateTrade(_ trade: Trade) async throws {
        try await FirebaseServices.shared.updateTrade(trade)
    }
    
    func deleteTrade(tradeId: String) async throws {
        try await FirebaseServices.shared.deleteTrade(tradeId: tradeId)
    }
    
    func getUserTrades(userId: String) async throws -> [Trade] {
        return try await FirebaseServices.shared.getUserTrades(userId: userId)
    }
    
    func listenToUserTrades(userId: String, completion: @escaping ([Trade]) -> Void) {
        FirebaseServices.shared.listenToUserTrades(userId: userId, completion: completion)
    }
    
    func getTradeById(tradeId: String) async throws -> Trade? {
        return try await FirebaseServices.shared.getTradeById(tradeId: tradeId)
    }
    
    func copyTrade(tradeId: String, userId: String) async throws {
        try await FirebaseServices.shared.copyTrade(tradeId: tradeId, userId: userId)
    }
    
    // MARK: - Post Management Wrapper Methods
    
    func createPost(_ post: Post) async throws {
        try await FirebaseServices.shared.createPost(post)
    }
    
    func updatePost(_ post: Post) async throws {
        try await FirebaseServices.shared.updatePost(post)
    }
    
    func deletePost(postId: String) async throws {
        try await FirebaseServices.shared.deletePost(postId: postId)
    }
    
    func getFeedPosts(limit: Int = 50) async throws -> [Post] {
        return try await FirebaseServices.shared.getFeedPosts(limit: limit)
    }
    
    func getUserPosts(userId: String) async throws -> [Post] {
        return try await FirebaseServices.shared.getUserPosts(userId: userId)
    }
    
    func getFollowingPosts(userId: String) async throws -> [Post] {
        return try await FirebaseServices.shared.getFollowingPosts(userId: userId)
    }
    
    // MARK: - Like/Unlike Wrapper Methods
    
    func likePost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.likePost(postId: postId, userId: userId)
    }
    
    func unlikePost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.unlikePost(postId: postId, userId: userId)
    }
    
    func getUserLikedPosts(userId: String) async throws -> Set<String> {
        return try await FirebaseServices.shared.getUserLikedPosts(userId: userId)
    }
    
    // MARK: - Bookmark Wrapper Methods
    
    func bookmarkPost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.bookmarkPost(postId: postId, userId: userId)
    }
    
    func unbookmarkPost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.unbookmarkPost(postId: postId, userId: userId)
    }
    
    func getUserBookmarkedPosts(userId: String) async throws -> Set<String> {
        return try await FirebaseServices.shared.getUserBookmarkedPosts(userId: userId)
    }
    
    // MARK: - Community Management Wrapper Methods
    
    func createCommunity(_ community: Community) async throws {
        try await FirebaseServices.shared.createCommunity(community)
    }
    
    func updateCommunity(_ community: Community) async throws {
        try await FirebaseServices.shared.updateCommunity(community)
    }
    
    func deleteCommunity(communityId: String) async throws {
        try await FirebaseServices.shared.deleteCommunity(communityId: communityId)
    }
    
    func getCommunities(limit: Int = 20) async throws -> [Community] {
        return try await FirebaseServices.shared.getCommunities(limit: limit)
    }
    
    func getUserCommunities(userId: String) async throws -> [Community] {
        return try await FirebaseServices.shared.getUserCommunities(userId: userId)
    }
    
    func joinCommunity(communityId: String, userId: String) async throws {
        try await FirebaseServices.shared.joinCommunity(communityId: communityId, userId: userId)
    }
    
    func leaveCommunity(communityId: String, userId: String) async throws {
        try await FirebaseServices.shared.leaveCommunity(communityId: communityId, userId: userId)
    }
    
    func getCommunityMembers(communityId: String) async throws -> [User] {
        return try await FirebaseServices.shared.getCommunityMembers(communityId: communityId)
    }
    
    func updateCommunityMemberRole(communityId: String, userId: String, role: String) async throws {
        try await FirebaseServices.shared.updateCommunityMemberRole(communityId: communityId, userId: userId, role: role)
    }
    
    // MARK: - Comment Wrapper Methods
    
    func addComment(postId: String, content: String, authorId: String, authorUsername: String) async throws {
        try await FirebaseServices.shared.addComment(postId: postId, content: content, authorId: authorId, authorUsername: authorUsername)
    }
    
    func getCommentsForPost(postId: String) async throws -> [Comment] {
        return try await FirebaseServices.shared.getCommentsForPost(postId: postId)
    }
    
    func deleteComment(commentId: String, postId: String) async throws {
        try await FirebaseServices.shared.deleteComment(commentId: commentId, postId: postId)
    }
    
    // MARK: - Report and Block Wrapper Methods
    
    func reportPost(postId: String, reportedBy: String, reason: String) async throws {
        try await FirebaseServices.shared.reportPost(postId: postId, reportedBy: reportedBy, reason: reason)
    }
    
    func reportUser(userId: String, reportedBy: String, reason: String) async throws {
        try await FirebaseServices.shared.reportUser(userId: userId, reportedBy: reportedBy, reason: reason)
    }
    
    func blockUser(userId: String, blockedBy: String) async throws {
        try await FirebaseServices.shared.blockUser(userId: userId, blockedBy: blockedBy)
    }
    
    func unblockUser(userId: String, unblockedBy: String) async throws {
        try await FirebaseServices.shared.unblockUser(userId: userId, unblockedBy: unblockedBy)
    }
    
    func getUserBlockedUsers(userId: String) async throws -> Set<String> {
        return try await FirebaseServices.shared.getUserBlockedUsers(userId: userId)
    }
    
    func isUserBlocked(userId: String, by blockedBy: String) async throws -> Bool {
        return try await FirebaseServices.shared.isUserBlocked(userId: userId, by: blockedBy)
    }
    
    // MARK: - Search Wrapper Methods
    
    func searchUsers(query: String) async throws -> [User] {
        return try await FirebaseServices.shared.searchUsers(query: query)
    }
    
    func searchPosts(query: String) async throws -> [Post] {
        return try await FirebaseServices.shared.searchPosts(query: query)
    }
    
    func searchTrades(query: String) async throws -> [Trade] {
        return try await FirebaseServices.shared.searchTrades(query: query)
    }
    
    func searchCommunities(query: String) async throws -> [Community] {
        return try await FirebaseServices.shared.searchCommunities(query: query)
    }
    
    // MARK: - Messaging Wrapper Methods
    
    func sendMessage(to recipientId: String, content: String, senderId: String) async throws {
        try await FirebaseServices.shared.sendMessage(to: recipientId, content: content, senderId: senderId)
    }
    
    func getConversations(userId: String) async throws -> [Conversation] {
        return try await FirebaseServices.shared.getConversations(userId: userId)
    }
    
    func getMessages(conversationId: String, limit: Int = 50) async throws -> [Message] {
        return try await FirebaseServices.shared.getMessages(conversationId: conversationId, limit: limit)
    }
    
    func markMessagesAsRead(conversationId: String, userId: String) async throws {
        try await FirebaseServices.shared.markMessagesAsRead(conversationId: conversationId, userId: userId)
    }
    
    func listenToConversation(conversationId: String, completion: @escaping ([Message]) -> Void) {
        FirebaseServices.shared.listenToConversation(conversationId: conversationId, completion: completion)
    }
    
    func deleteMessage(messageId: String) async throws {
        try await FirebaseServices.shared.deleteMessage(messageId: messageId)
    }
    
    func getUnreadMessageCount(userId: String) async throws -> Int {
        return try await FirebaseServices.shared.getUnreadMessageCount(userId: userId)
    }
    
    // MARK: - Market News Wrapper Methods
    
    func cacheMarketNews(articles: [MarketNewsArticle]) async throws {
        try await FirebaseServices.shared.cacheMarketNews(articles: articles)
    }
    
    func getCachedMarketNews() async throws -> [MarketNewsArticle] {
        return try await FirebaseServices.shared.getCachedMarketNews()
    }
    
    func clearOldMarketNews() async throws {
        try await FirebaseServices.shared.clearOldMarketNews()
    }
    
    func searchMarketNews(query: String) async throws -> [MarketNewsArticle] {
        return try await FirebaseServices.shared.searchMarketNews(query: query)
    }
    
    // MARK: - Notification Wrapper Methods
    
    func sendNotification(to userId: String, type: String, title: String, body: String, data: [String: Any] = [:]) async throws {
        try await FirebaseServices.shared.sendNotification(to: userId, type: type, title: title, body: body, data: data)
    }
    
    func getUserNotifications(userId: String, limit: Int = 50) async throws -> [UserNotification] {
        return try await FirebaseServices.shared.getUserNotifications(userId: userId, limit: limit)
    }
    
    func markNotificationAsRead(notificationId: String) async throws {
        try await FirebaseServices.shared.markNotificationAsRead(notificationId: notificationId)
    }
    
    func getUnreadNotificationCount(userId: String) async throws -> Int {
        return try await FirebaseServices.shared.getUnreadNotificationCount(userId: userId)
    }
    
    // MARK: - Analytics Wrapper Methods
    
    func getMarketNewsAnalytics() async throws -> NewsAnalytics {
        return try await FirebaseServices.shared.getMarketNewsAnalytics()
    }
    
    func trackUserActivity(userId: String, action: String, details: [String: Any] = [:]) async throws {
        try await FirebaseServices.shared.trackUserActivity(userId: userId, action: action, details: details)
    }
    
    // MARK: - Clean up
    
    deinit {
        if let handle = handle {
            auth.removeStateDidChangeListener(handle)
        }
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case notAuthenticated
    case usernameTaken
    case invalidEmail
    case weakPassword
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to perform this action"
        case .usernameTaken:
            return "This username is already taken"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 6 characters"
        case .networkError:
            return "Network error. Please check your connection"
        }
    }
}
