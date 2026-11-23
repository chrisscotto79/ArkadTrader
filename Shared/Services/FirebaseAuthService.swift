// File: Shared/Services/FirebaseAuthService.swift
// Sign-in state and the signed-in user's profile, plus thin wrappers around FirebaseServices.
// Also tells PushNotificationManager and Crashlytics who is signed in.

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCrashlytics
import Combine
import FirebaseStorage
import UIKit

@MainActor
class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    
    private var handle: AuthStateDidChangeListenerHandle?
    private let auth = Auth.auth()
    /// True while `register` is creating the account, so the auth listener doesn't load a
    /// profile that doesn't exist yet
    private var isRegistering = false
    /// When the user last confirmed their password in this session (`reauthenticate`)
    private var lastReauthenticatedAt: Date?

    /// How recent a sign-in must be before free mode starts deleting an account's data.
    /// Firebase asks for a sign-in within about 5 minutes to delete the sign-in itself, and
    /// the cleanup runs first, so this leaves time for it.
    private static let recentSignInWindow: TimeInterval = 3 * 60
    
    private init() {
        setupAuthListener()
    }
    
    // MARK: - Auth State Management
            
        private func setupAuthListener() {
            handle = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
                Task { @MainActor in
                    guard let self else { return }
                    if let firebaseUser = firebaseUser {
                        if !self.isRegistering {
                            await self.loadCurrentUser(firebaseUser.uid)
                            self.isAuthenticated = true
                            self.didSignIn(userId: firebaseUser.uid)
                        }
                    } else {
                        self.isAuthenticated = false
                        self.currentUser = nil
                        self.didSignOut()
                    }
                    self.isLoading = false
                }
            }
        }
        
        private func loadCurrentUser(_ userId: String) async {
            do {
                currentUser = try await FirebaseServices.shared.getUserById(userId: userId)
            } catch {
                currentUser = nil
            }
        }

        /// Crash reports and push notifications follow the signed-in user.
        private func didSignIn(userId: String) {
            Crashlytics.crashlytics().setUserID(userId)
            PushNotificationManager.shared.userDidSignIn(userId: userId)
        }

        private func didSignOut() {
            Crashlytics.crashlytics().setUserID("")
            PushNotificationManager.shared.userDidSignOut()
        }
        
        // MARK: - User Refresh Method
        /// Reloads the current user from Firebase (useful after updates)
        func refreshCurrentUser() async {
            guard let userId = currentUser?.id else { return }
            
            if let refreshedUser = try? await FirebaseServices.shared.getUserById(userId: userId) {
                self.currentUser = refreshedUser
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
        
        /// Creates the sign-in, checks the username, then writes the profile. If any step fails
        /// the new sign-in is removed again so the email can be reused. New accounts start
        /// with `onboardingCompleted = false`, which shows onboarding next.
        func register(email: String, password: String, username: String, fullName: String) async throws {
            isRegistering = true
            defer { isRegistering = false }

            let result = try await auth.createUser(withEmail: email, password: password)
            let firebaseUser = result.user

            do {
                guard try await isUsernameAvailable(username) else {
                    throw AuthError.usernameTaken
                }

                var newUser = User(
                    id: firebaseUser.uid,
                    email: email,
                    username: username,
                    fullName: fullName
                )
                newUser.onboardingCompleted = false

                try await FirebaseServices.shared.createUser(newUser)
                currentUser = newUser
                isAuthenticated = true
                didSignIn(userId: newUser.id)
            } catch {
                try? await firebaseUser.delete()
                throw error
            }
        }
        
        func signUp(email: String, password: String, fullName: String, username: String) async throws {
            try await register(email: email, password: password, username: username, fullName: fullName)
        }
        
        /// Signs out, first removing this device's push token while the user can still write it.
        func logout() async {
            await PushNotificationManager.shared.unregisterDevice()
            do {
                try auth.signOut()
                currentUser = nil
                isAuthenticated = false
            } catch {
                // Firebase only fails here if the keychain is unavailable; stay signed in.
            }
        }
        
        /// Prefer `logout()`. Kept for existing callers; signs out in the background.
        func signOut() throws {
            Task { await logout() }
        }
        
        /// Deletes the account.
        ///
        /// With Cloud Functions deployed it only deletes the Firebase sign-in; an Auth onDelete
        /// trigger then removes everything else (docs/backend-contracts.md, section 8).
        ///
        /// In free mode (section 0) the app cleans up first: posts, follows, memberships, owned
        /// communities, `users/{uid}` subcollections, `traderStats/{uid}`, the inbox and the
        /// profile photo, then `users/{uid}` and the trades, then deletes the sign-in. So that
        /// data isn't removed while the sign-in survives, it requires a recent sign-in up front.
        ///
        /// Throws `AuthError.recentLoginRequired` or `AuthErrorCode.requiresRecentLogin` if the
        /// user must confirm their password first; call `reauthenticate(password:)` and try again.
        func deleteAccount() async throws {
            guard let user = auth.currentUser else {
                throw AuthError.notAuthenticated
            }

            if AppConfig.serverFunctionsEnabled {
                try await user.delete()
                currentUser = nil
                isAuthenticated = false
                return
            }

            guard hasRecentSignIn(user) else {
                throw AuthError.recentLoginRequired
            }

            await FirebaseServices.shared.deleteAccountData(userId: user.uid)

            // Delete the profile while still signed in (the rules need auth), but keep a copy
            // to put back if Firebase refuses to delete the sign-in, so the user isn't left
            // with an account that has no profile.
            let userDoc = Firestore.firestore().collection("users").document(user.uid)
            let savedProfile = try? await userDoc.getDocument().data()
            try? await userDoc.delete()

            // After the profile, which the rules need gone to delete older price-checked trades
            await FirebaseServices.shared.deleteAccountTrades(userId: user.uid)

            do {
                try await user.delete()
            } catch {
                if let savedProfile {
                    try? await userDoc.setData(savedProfile)
                }
                throw error
            }

            lastReauthenticatedAt = nil
            currentUser = nil
            isAuthenticated = false
        }

        /// Whether the user signed in, or confirmed their password, in the last few minutes.
        private func hasRecentSignIn(_ user: FirebaseAuth.User) -> Bool {
            let latest = [user.metadata.lastSignInDate, lastReauthenticatedAt]
                .compactMap { $0 }
                .max()
            guard let latest else { return false }
            return Date().timeIntervalSince(latest) < Self.recentSignInWindow
        }

        /// Confirms the signed-in user's password, which Firebase needs before sensitive
        /// changes such as deleting the account.
        func reauthenticate(password: String) async throws {
            guard let user = auth.currentUser, let email = user.email else {
                throw AuthError.notAuthenticated
            }
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            _ = try await user.reauthenticate(with: credential)
            lastReauthenticatedAt = Date()
        }

        // MARK: - Onboarding

        /// Saves the onboarding answers and marks onboarding as done. The local profile is
        /// updated first, so the app moves on straight away even on a slow connection.
        func completeOnboarding(experienceLevel: String?, interests: [String]) async throws {
            guard var user = currentUser else {
                throw AuthError.notAuthenticated
            }

            var data: [String: Any] = [
                "onboardingCompleted": true,
                "interests": interests,
                "updatedAt": Timestamp(date: Date())
            ]
            if let experienceLevel {
                data["experienceLevel"] = experienceLevel
                user.experienceLevel = experienceLevel
            }
            user.interests = interests
            user.onboardingCompleted = true
            currentUser = user

            try await Firestore.firestore().collection("users").document(user.id)
                .setData(data, merge: true)
        }

        // MARK: - Notification Preferences

        /// Turns one push preference on or off, locally and in `users/{uid}.notificationPrefs`.
        /// Reverts the local value if the write fails.
        func setNotificationPreference(_ preference: NotificationPreference, enabled: Bool) async throws {
            guard let userId = currentUser?.id else {
                throw AuthError.notAuthenticated
            }

            let previous = currentUser?.notificationPrefs[preference.rawValue]
            currentUser?.notificationPrefs[preference.rawValue] = enabled
            do {
                try await FirebaseServices.shared.setNotificationPreference(
                    preference.rawValue,
                    enabled: enabled,
                    userId: userId
                )
            } catch {
                currentUser?.notificationPrefs[preference.rawValue] = previous
                throw error
            }
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
        
        func updateProfile(
            fullName: String? = nil,
            bio: String? = nil,
            username: String? = nil,
            profileImage: UIImage? = nil  // ✅ ADD THIS PARAMETER
        ) async throws {
            
            guard var user = currentUser else {
                throw AuthError.notAuthenticated
            }
            
            // Update basic profile fields
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
            
            // Profile photo: saved as images/avatar_{uid} in Firestore (no Cloud Storage on the
            // free plan). The same doc is overwritten each time, so there's nothing old to delete.
            // The returned arkad-image:// string changes on every upload, which busts caches.
            if let profileImage = profileImage {
                user.profileImageUrl = try await ImageStore.shared.uploadAvatar(profileImage)
            }
            
            // Update timestamp
            user.updatedAt = Date()
            
            // Save to Firestore
            do {
                try await FirebaseServices.shared.updateUser(user)
                self.currentUser = user
            } catch {
                throw error
            }
        }
    func updateProfileImage(_ image: UIImage) async throws {
        guard currentUser != nil else {
            throw AuthError.notAuthenticated
        }
        
        try await updateProfile(profileImage: image)
    }

    func removeProfileImage() async throws {
        guard var user = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        let oldImageUrl = user.profileImageUrl

        // Update user record first, so the profile never points at a deleted photo
        user.profileImageUrl = nil
        user.updatedAt = Date()
        
        try await FirebaseServices.shared.updateUser(user)
        self.currentUser = user

        // Then remove the photo itself (best-effort)
        if let oldImageUrl {
            if ImageStore.imageId(from: oldImageUrl) != nil {
                try? await ImageStore.shared.deleteImage(urlString: oldImageUrl)
            } else if AppConfig.mediaUploadsEnabled {
                try? await FirebaseServices.shared.deleteProfileImage(imageUrl: oldImageUrl)
            }
        }
        
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
        return try await FirebaseServices.shared.getUserTradesSimple(userId: userId)
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
    
    func getFollowingPosts(userId: String, limit: Int = 20) async throws -> [Post] {
        return try await FirebaseServices.shared.getFollowingPosts(userId: userId, limit: limit)
    }

    func getFollowingTrades(userId: String, limit: Int = 20) async throws -> [Trade] {
        return try await FirebaseServices.shared.getFollowingTrades(userId: userId, limit: limit)
    }

    func getFollowingActivity(userId: String, limit: Int = 50) async throws -> [ActivityItem] {
        return try await FirebaseServices.shared.getFollowingActivity(userId: userId, limit: limit)
    }

    func createActivity(userId: String, type: ActivityItem.ActivityType, content: String, relatedId: String? = nil) async throws {
        guard let currentUser = currentUser else { return }
        
        let activity = ActivityItem(
            id: UUID().uuidString,
            userId: userId,
            username: currentUser.username,
            activityType: type,
            content: content,
            relatedId: relatedId,
            createdAt: Date()
        )
        
        try await FirebaseServices.shared.createActivity(activity)
    }
    func createActivity(_ activity: ActivityItem) async throws {
        try await FirebaseServices.shared.createActivity(activity)
    }

    func getComments(postId: String) async throws -> [Comment] {
        return try await FirebaseServices.shared.getComments(postId: postId)
    }
    func checkAuthState() async {
        if let user = auth.currentUser {
            // User is signed in, load their data
            do {
                if let userData = try await FirebaseServices.shared.getUserById(userId: user.uid) {
                    await MainActor.run {
                        self.currentUser = userData
                        self.isAuthenticated = true
                    }
                }
            } catch {
            }
        } else {
            // No user signed in
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
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
    func getUserCommunitiesIds(userId: String) async throws -> [Community] {
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
    
    func addComment(postId: String, content: String, authorId: String, authorUsername: String, parentCommentId: String? = nil) async throws {
        try await FirebaseServices.shared.addComment(postId: postId, content: content, authorId: authorId, authorUsername: authorUsername, parentCommentId: parentCommentId)
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
    
    
    func searchUsers(query: String, limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.searchUsers(query: query, limit: limit)
    }

    func searchPosts(query: String, limit: Int = 20) async throws -> [Post] {
        return try await FirebaseServices.shared.searchPosts(query: query, limit: limit)
    }

    func searchTrades(query: String, limit: Int = 20) async throws -> [Trade] {
        return try await FirebaseServices.shared.searchTrades(query: query, limit: limit)
    }

    func searchCommunities(query: String, limit: Int = 20) async throws -> [Community] {
        return try await FirebaseServices.shared.searchCommunities(query: query, limit: limit)
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
    // Add this to FirebaseAuthService.swift
    func getUserLikedComments(userId: String) async throws -> Set<String> {
        return try await FirebaseServices.shared.getUserLikedComments(userId: userId)
    }
    // MARK: - Comment Like Wrapper Methods

    // MARK: - Comment Like Wrapper Methods (add to FirebaseAuthService.swift)

    func likeComment(commentId: String, userId: String) async throws {
        try await FirebaseServices.shared.likeComment(commentId: commentId, userId: userId)
    }

    func unlikeComment(commentId: String, userId: String) async throws {
        try await FirebaseServices.shared.unlikeComment(commentId: commentId, userId: userId)
    }
    
    func getUnreadMessageCount(userId: String) async throws -> Int {
        return try await FirebaseServices.shared.getUnreadMessageCount(userId: userId)
    }
    func getUserTradesSimple(userId: String) async throws -> [Trade] {
        return try await FirebaseServices.shared.getUserTradesSimple(userId: userId)
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
    
    // MARK: - Clean up
    
    deinit {
        if let handle = handle {
            auth.removeStateDidChangeListener(handle)
        }
    }
}
extension FirebaseAuthService {
    
    /// Updates the user's starting capital in Firebase and locally
    func updateUserStartingCapital(userId: String, startingCapital: Double) async throws {
        // Update in Firebase
        try await FirebaseServices.shared.updateUserStartingCapital(userId: userId, startingCapital: startingCapital)
        
        // Update local user object
        if var user = currentUser, user.id == userId {
            user.startingCapital = startingCapital
            user.updatedAt = Date()
            currentUser = user
        }
    }
    
    /// Convenience method to update current user's starting capital
    func updateCurrentUserStartingCapital(_ amount: Double) async throws {
        guard let userId = currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        try await updateUserStartingCapital(userId: userId, startingCapital: amount)
    }
    
    /// Reloads the current user from Firebase (useful after updates)
    
}

// MARK: - AuthError enum (if not already defined)
enum AuthError: LocalizedError {
    case notAuthenticated
    case usernameTaken
    case invalidCredentials
    case networkError
    case unknownError
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case invalidData      // ✅ ADD THIS
    case uploadFailed     // ✅ ADD THIS
    case custom(String)   // ✅ ADD THIS
    /// The user must confirm their password before this (deleting the account in free mode)
    case recentLoginRequired
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .usernameTaken:
            return "Username is already taken"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection error"
        case .unknownError:
            return "An unknown error occurred"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 6 characters"
        case .emailAlreadyInUse:
            return "An account with this email already exists"
        case .invalidData:
            return "Invalid data provided"
        case .uploadFailed:
            return "Failed to upload file"
        case .custom(let message):
            return message
        case .recentLoginRequired:
            return "Please confirm your password to continue."
        }
    }
}
