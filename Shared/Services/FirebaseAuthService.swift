// File: Shared/Services/FirebaseAuthService.swift
// Complete Firebase Auth Service with search wrapper methods

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
    
    func signIn(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        await loadCurrentUser(result.user.uid)
    }
    
    func signUp(email: String, password: String, fullName: String, username: String) async throws {
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
    
    // MARK: - User Management Wrapper Methods
    
    func getUserById(userId: String) async throws -> User? {
        return try await FirebaseServices.shared.getUserById(userId: userId)
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
    
    // MARK: - Post Management Wrapper Methods
    
    func createPost(_ post: Post) async throws {
        try await FirebaseServices.shared.createPost(post)
    }
    
    func getUserPosts(userId: String) async throws -> [Post] {
        return try await FirebaseServices.shared.getUserPosts(userId: userId)
    }
    
    func likePost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.likePost(postId: postId, userId: userId)
    }
    
    func unlikePost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.unlikePost(postId: postId, userId: userId)
    }
    
    func getUserLikedPosts(userId: String) async throws -> Set<String> {
        return try await FirebaseServices.shared.getUserLikedPosts(userId: userId)
    }
    
    func bookmarkPost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.bookmarkPost(postId: postId, userId: userId)
    }
    
    func unbookmarkPost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.unbookmarkPost(postId: postId, userId: userId)
    }
    
    func getUserBookmarkedPosts(userId: String) async throws -> Set<String> {
        return try await FirebaseServices.shared.getUserBookmarkedPosts(userId: userId)
    }
    
    func reportPost(postId: String, reportedBy: String, reason: String) async throws {
        try await FirebaseServices.shared.reportPost(postId: postId, reportedBy: reportedBy, reason: reason)
    }
    
    func blockUser(userId: String, blockedBy: String) async throws {
        try await FirebaseServices.shared.blockUser(userId: userId, blockedBy: blockedBy)
    }
    
    // MARK: - Community Management Wrapper Methods
    
    func createCommunity(_ community: Community) async throws {
        try await FirebaseServices.shared.createCommunity(community)
    }
    
    func getCommunities() async throws -> [Community] {
        return try await FirebaseServices.shared.getCommunities()
    }
    
    func joinCommunity(communityId: String, userId: String) async throws {
        try await FirebaseServices.shared.joinCommunity(communityId: communityId, userId: userId)
    }
    
    func leaveCommunity(communityId: String, userId: String) async throws {
        try await FirebaseServices.shared.leaveCommunity(communityId: communityId, userId: userId)
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
