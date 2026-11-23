// File: Shared/Services/FirebaseAuthService.swift
// Sign-in state and the signed-in user's profile, plus thin wrappers around FirebaseServices.
// Also tells PushNotificationManager and Crashlytics who is signed in, and clears per-user
// state on sign-out.

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCrashlytics
import Combine
import UIKit

@MainActor
class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    /// Signed in, but the profile couldn't be loaded (missing, offline or refused).
    /// ContentView shows Retry and Sign out instead of the tabs.
    @Published private(set) var profileLoadFailed = false
    /// Shown once on the sign-in screen after an account deletion that left something behind
    @Published var accountDeletionNotice: String?

    private var handle: AuthStateDidChangeListenerHandle?
    private let auth = Auth.auth()
    /// While `register` is creating an account, the auth listener leaves it alone:
    /// `register` sets the new profile itself once it exists.
    private var registrationsInProgress = 0
    /// The account whose session (push, Crashlytics, per-user stores) is set up
    private var sessionUserId: String?
    /// One profile load at a time per account; later callers wait for it
    private var profileLoad: (userId: String, task: Task<Void, Never>)?

    private init() {
        setupAuthListener()
    }

    deinit {
        if let handle {
            auth.removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth State

    private func setupAuthListener() {
        handle = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                guard let self else { return }
                await self.handleAuthChange(firebaseUser)
                self.isLoading = false
            }
        }
    }

    private func handleAuthChange(_ firebaseUser: FirebaseAuth.User?) async {
        guard let firebaseUser else {
            handleSignedOut()
            return
        }
        if registrationsInProgress > 0 { return }
        // Already set up (for example by login or register)
        if currentUser?.id == firebaseUser.uid && sessionUserId == firebaseUser.uid { return }
        // A different account without a sign-out in between: drop the old one's state first
        if let sessionUserId, sessionUserId != firebaseUser.uid {
            handleSignedOut()
        }
        await loadProfile(for: firebaseUser.uid)
    }

    /// Loads the signed-in user's profile. A late answer is dropped if the user signed out or
    /// switched accounts while it loaded.
    private func loadProfile(for userId: String) async {
        if let profileLoad, profileLoad.userId == userId {
            await profileLoad.task.value
            return
        }
        let task = Task { @MainActor in
            let user = try? await FirebaseServices.shared.getSignedInProfile(userId: userId)
            guard self.auth.currentUser?.uid == userId else { return }
            self.currentUser = user
            self.profileLoadFailed = user == nil
            self.isAuthenticated = true
            if user != nil {
                self.startSession(userId: userId)
            }
        }
        profileLoad = (userId, task)
        await task.value
        if profileLoad?.userId == userId {
            profileLoad = nil
        }
    }

    /// Retry after `profileLoadFailed`.
    func retryLoadingProfile() async {
        guard let userId = auth.currentUser?.uid else { return }
        await loadProfile(for: userId)
    }

    /// Crash reports and push notifications follow the signed-in user.
    private func startSession(userId: String) {
        guard sessionUserId != userId else { return }
        sessionUserId = userId
        Crashlytics.crashlytics().setUserID(userId)
        PushNotificationManager.shared.userDidSignIn(userId: userId)
    }

    /// Forgets everything about the previous account. Safe to call more than once.
    /// Stores that follow `currentUser` (BlockStore and others) reset themselves when it
    /// becomes nil; Firestore's on-device cache is wiped at the next launch.
    private func handleSignedOut() {
        let hadSession = sessionUserId != nil || currentUser != nil
        profileLoad?.task.cancel()
        profileLoad = nil
        currentUser = nil
        isAuthenticated = false
        profileLoadFailed = false
        sessionUserId = nil
        guard hadSession else { return }

        Crashlytics.crashlytics().setUserID("")
        PushNotificationManager.shared.userDidSignOut()
        PriceAlertChecker.shared.reset()
        PostStore.shared.reset()
        WatchlistStore.shared.reset()
        FirebaseServices.requestCacheClearOnNextLaunch()
    }

    /// Reloads the current user from Firebase (after changes made elsewhere)
    func refreshCurrentUser() async {
        guard let userId = currentUser?.id else { return }
        if let refreshed = try? await FirebaseServices.shared.getSignedInProfile(userId: userId),
           auth.currentUser?.uid == userId {
            currentUser = refreshed
        }
    }

    // MARK: - Sign In, Sign Up, Sign Out

    /// Signs in and waits for the profile.
    func login(email: String, password: String) async throws {
        let result = try await auth.signIn(
            withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        if currentUser?.id != result.user.uid {
            await loadProfile(for: result.user.uid)
        }
    }

    /// Creates the sign-in, checks the username, then writes the profile, the private profile
    /// and the username claim together. If any step fails the new sign-in is removed again so
    /// the email can be reused. New accounts start with `onboardingCompleted = false`.
    func register(email: String, password: String, username: String, fullName: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = FirebaseServices.normalizedUsername(username)
        let fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)

        registrationsInProgress += 1
        defer { registrationsInProgress -= 1 }

        let result = try await auth.createUser(withEmail: email, password: password)
        let firebaseUser = result.user
        let services = FirebaseServices.shared

        do {
            guard try await services.isUsernameAvailable(username, for: firebaseUser.uid) else {
                throw AuthError.usernameTaken
            }

            var newUser = User(id: firebaseUser.uid, email: email, username: username, fullName: fullName)
            newUser.onboardingCompleted = false

            do {
                try await services.createUser(newUser)
            } catch {
                // Someone may have taken the name a moment ago (the rules refuse the claim)
                if (try? await services.isUsernameAvailable(username, for: firebaseUser.uid)) == false {
                    throw AuthError.usernameTaken
                }
                throw error
            }

            guard auth.currentUser?.uid == firebaseUser.uid else { throw AuthError.notAuthenticated }
            currentUser = newUser
            profileLoadFailed = false
            isAuthenticated = true
            startSession(userId: newUser.id)
        } catch {
            try? await firebaseUser.delete()
            throw error
        }
    }

    /// Signs out, first removing this device's push token while the user can still write it.
    func logout() async {
        await PushNotificationManager.shared.unregisterDevice()
        do {
            try auth.signOut()
        } catch {
            // Firebase only fails here if the keychain is unavailable; stay signed in.
            return
        }
        handleSignedOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func resetPassword(email: String) async throws {
        try await sendPasswordReset(email: email)
    }

    // MARK: - Account Deletion

    /// Deletes the account after confirming the password (Arkad only has email sign-in).
    ///
    /// With Cloud Functions deployed it only deletes the Firebase sign-in; an Auth onDelete
    /// trigger then removes everything else (docs/backend-contracts.md, section 8).
    ///
    /// In free mode (section 0) the app cleans up first: it creates deletionRequests/{uid},
    /// removes posts, comments and likes on other posts, follows, memberships, owned
    /// communities, `users/{uid}` subcollections, `traderStats/{uid}`, the inbox, photos and
    /// trades, then the private profile, username and `users/{uid}`, then confirms the password
    /// again and deletes the sign-in. If that last step fails, the profile is put back.
    /// Anything that couldn't be removed is listed in `accountDeletionNotice`.
    func deleteAccount(password: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthError.notAuthenticated
        }

        // Nothing is deleted unless the password is right
        try await reauthenticate(password: password)

        if AppConfig.serverFunctionsEnabled {
            try await user.delete()
            handleSignedOut()
            return
        }

        let userId = user.uid
        let services = FirebaseServices.shared
        try await services.createDeletionRequest(userId: userId)

        let failed = await services.deleteAccountData(userId: userId)
        let saved = await services.deleteProfileDocuments(userId: userId, username: currentUser?.username ?? "")

        do {
            // A fresh sign-in right before deleting it: the cleanup above can take a while
            try await reauthenticate(password: password)
            try await user.delete()
        } catch {
            await services.restoreProfileDocuments(userId: userId, saved: saved)
            throw error
        }

        if !failed.isEmpty {
            accountDeletionNotice = "Your account is deleted, but some of your data couldn't be removed: "
                + failed.joined(separator: ", ")
                + ". Email \(AppInfo.supportEmail) and we'll remove it for you."
        }
        handleSignedOut()
    }

    /// Confirms the signed-in user's password, which Firebase needs before sensitive changes
    /// such as deleting the account.
    func reauthenticate(password: String) async throws {
        guard let user = auth.currentUser, let email = user.email else {
            throw AuthError.notAuthenticated
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        _ = try await user.reauthenticate(with: credential)
    }

    // MARK: - Onboarding

    /// Saves the onboarding answers (private profile) and marks onboarding as done (public
    /// profile). The local profile is updated first, so the app moves on straight away even
    /// on a slow connection.
    func completeOnboarding(experienceLevel: String?, interests: [String]) async throws {
        guard var user = currentUser else {
            throw AuthError.notAuthenticated
        }

        var privateData: [String: Any] = ["interests": interests]
        if let experienceLevel {
            privateData["experienceLevel"] = experienceLevel
            user.experienceLevel = experienceLevel
        }
        user.interests = interests
        user.onboardingCompleted = true
        currentUser = user

        let services = FirebaseServices.shared
        let batch = services.db.batch()
        batch.setData(privateData, forDocument: services.privateProfileRef(user.id), merge: true)
        batch.updateData([
            "onboardingCompleted": true,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: services.userRef(user.id))
        try await batch.commit()
    }

    // MARK: - Notification Preferences

    /// Turns one push preference on or off, locally and in the private profile's
    /// `notificationPrefs`. Reverts the local value if the write fails.
    func setNotificationPreference(_ preference: NotificationPreference, enabled: Bool) async throws {
        guard let userId = currentUser?.id else {
            throw AuthError.notAuthenticated
        }

        let previous = currentUser?.notificationPrefs[preference.rawValue]
        currentUser?.notificationPrefs[preference.rawValue] = enabled
        do {
            try await FirebaseServices.shared.updatePrivateProfile(
                userId: userId,
                fields: ["notificationPrefs": [preference.rawValue: enabled]]
            )
        } catch {
            currentUser?.notificationPrefs[preference.rawValue] = previous
            throw error
        }
    }

    // MARK: - Starting balance

    /// Saves the starting balance (owner-only, in the private profile) and updates it locally.
    /// Read it back as `currentUser?.startingCapital`.
    func updateCurrentUserStartingCapital(_ amount: Double) async throws {
        guard let userId = currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        try await FirebaseServices.shared.updateUserStartingCapital(userId: userId, startingCapital: amount)
        if currentUser?.id == userId {
            currentUser?.startingCapital = amount
        }
    }

    // MARK: - Username

    /// Whether `username` is free. Your own current username counts as free.
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        try await FirebaseServices.shared.isUsernameAvailable(username, for: auth.currentUser?.uid)
    }

    // MARK: - Profile

    /// Saves only what changed. An empty `bio` removes it. Usernames are saved lowercase.
    /// Throws `AuthError.usernameTaken`.
    func updateProfile(
        fullName: String? = nil,
        bio: String? = nil,
        username: String? = nil,
        profileImage: UIImage? = nil
    ) async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }

        var changes = ProfileChanges()
        if let fullName {
            let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != user.fullName { changes.fullName = trimmed }
        }
        if let bio {
            let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != (user.bio ?? "") { changes.bio = trimmed }
        }
        if let username {
            let name = FirebaseServices.normalizedUsername(username)
            guard !name.isEmpty else { throw AuthError.invalidData }
            if name != user.username { changes.username = name }
        }

        // Profile photo: saved as images/avatar_{uid} in Firestore (no Cloud Storage on the
        // free plan). The same doc is overwritten each time, so there's nothing old to delete.
        // The returned arkad-image:// string changes on every upload, which busts caches.
        if let profileImage {
            changes.profileImageUrl = try await ImageStore.shared.uploadAvatar(profileImage)
        }

        guard changes.fullName != nil || changes.bio != nil
                || changes.username != nil || changes.profileImageUrl != nil else { return }

        try await FirebaseServices.shared.updateProfile(
            userId: user.id,
            currentUsername: user.username,
            changes: changes
        )

        guard var updated = currentUser, updated.id == user.id else { return }
        if let fullName = changes.fullName { updated.fullName = fullName }
        if let bio = changes.bio { updated.bio = bio.isEmpty ? nil : bio }
        if let name = changes.username { updated.username = name }
        if let url = changes.profileImageUrl { updated.profileImageUrl = url }
        updated.updatedAt = Date()
        currentUser = updated
    }

    /// Keeps the signed-in user's following count in step after a follow or unfollow, without
    /// reloading the profile.
    func adjustFollowingCount(by delta: Int) {
        guard let count = currentUser?.followingCount else { return }
        currentUser?.followingCount = max(0, count + delta)
    }
}

// MARK: - Wrappers around FirebaseServices

extension FirebaseAuthService {
    // Users and follows

    func getUserById(userId: String) async throws -> User? {
        try await FirebaseServices.shared.getUserById(userId: userId)
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
        try await FirebaseServices.shared.getUserFollowing(userId: userId)
    }

    func getUserFollowers(userId: String) async throws -> Set<String> {
        try await FirebaseServices.shared.getUserFollowers(userId: userId)
    }

    func isFollowing(userId: String, targetUserId: String) async throws -> Bool {
        try await FirebaseServices.shared.isFollowing(userId: userId, targetUserId: targetUserId)
    }

    func searchUsers(query: String, limit: Int = 20) async throws -> [User] {
        try await FirebaseServices.shared.searchUsers(query: query, limit: limit)
    }

    // Trades

    func addTrade(_ trade: Trade) async throws {
        try await FirebaseServices.shared.addTrade(trade)
    }

    func updateTrade(_ trade: Trade) async throws {
        try await FirebaseServices.shared.updateTrade(trade)
    }

    func deleteTrade(tradeId: String) async throws {
        try await FirebaseServices.shared.deleteTrade(tradeId: tradeId)
    }

    /// Your own trades, or someone else's public ones
    func getUserTrades(userId: String) async throws -> [Trade] {
        try await FirebaseServices.shared.getUserTradesSimple(userId: userId)
    }

    func getFollowingTrades(userId: String, limit: Int = 20) async throws -> [Trade] {
        try await FirebaseServices.shared.getFollowingTrades(userId: userId, limit: limit)
    }

    func searchTrades(query: String, limit: Int = 20) async throws -> [Trade] {
        try await FirebaseServices.shared.searchTrades(query: query, limit: limit)
    }

    // Posts, likes, bookmarks and comments

    func createPost(_ post: Post) async throws {
        try await FirebaseServices.shared.createPost(post)
    }

    func deletePost(postId: String) async throws {
        try await FirebaseServices.shared.deletePost(postId: postId)
    }

    func getFeedPosts(limit: Int = 50) async throws -> [Post] {
        try await FirebaseServices.shared.getFeedPosts(limit: limit)
    }

    func getUserPosts(userId: String) async throws -> [Post] {
        try await FirebaseServices.shared.getUserPosts(userId: userId)
    }

    func getFollowingPosts(userId: String) async throws -> [Post] {
        try await FirebaseServices.shared.getFollowingPosts(userId: userId)
    }

    func getFollowingPosts(userId: String, limit: Int = 20) async throws -> [Post] {
        try await FirebaseServices.shared.getFollowingPosts(userId: userId, limit: limit)
    }

    func searchPosts(query: String, limit: Int = 20) async throws -> [Post] {
        try await FirebaseServices.shared.searchPosts(query: query, limit: limit)
    }

    func likePost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.likePost(postId: postId, userId: userId)
    }

    func unlikePost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.unlikePost(postId: postId, userId: userId)
    }

    func getUserLikedPosts(userId: String) async throws -> Set<String> {
        try await FirebaseServices.shared.getUserLikedPosts(userId: userId)
    }

    func bookmarkPost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.bookmarkPost(postId: postId, userId: userId)
    }

    func unbookmarkPost(postId: String, userId: String) async throws {
        try await FirebaseServices.shared.unbookmarkPost(postId: postId, userId: userId)
    }

    func getUserBookmarkedPosts(userId: String) async throws -> Set<String> {
        try await FirebaseServices.shared.getUserBookmarkedPosts(userId: userId)
    }

    func addComment(postId: String, content: String, authorId: String, authorUsername: String, parentCommentId: String? = nil) async throws {
        try await FirebaseServices.shared.addComment(postId: postId, content: content, authorId: authorId, authorUsername: authorUsername, parentCommentId: parentCommentId)
    }

    func getCommentsForPost(postId: String) async throws -> [Comment] {
        try await FirebaseServices.shared.getCommentsForPost(postId: postId)
    }

    func deleteComment(commentId: String, postId: String) async throws {
        try await FirebaseServices.shared.deleteComment(commentId: commentId, postId: postId)
    }

    func reportPost(postId: String, reportedBy: String, reason: String) async throws {
        try await FirebaseServices.shared.reportPost(postId: postId, reportedBy: reportedBy, reason: reason)
    }

    // Activity

    func getFollowingActivity(userId: String, limit: Int = 50) async throws -> [ActivityItem] {
        try await FirebaseServices.shared.getFollowingActivity(userId: userId, limit: limit)
    }

    func createActivity(userId: String, type: ActivityItem.ActivityType, content: String, relatedId: String? = nil) async throws {
        guard let currentUser else { return }
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

    // Communities

    func getUserCommunities(userId: String) async throws -> [Community] {
        try await FirebaseServices.shared.getUserCommunities(userId: userId)
    }

    func joinCommunity(communityId: String, userId: String) async throws {
        try await FirebaseServices.shared.joinCommunity(communityId: communityId, userId: userId)
    }

    func getCommunityMembers(communityId: String) async throws -> [User] {
        try await FirebaseServices.shared.getCommunityMembers(communityId: communityId)
    }

    func searchCommunities(query: String, limit: Int = 20) async throws -> [Community] {
        try await FirebaseServices.shared.searchCommunities(query: query, limit: limit)
    }
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case notAuthenticated
    case usernameTaken
    case invalidCredentials
    case networkError
    case unknownError
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case invalidData
    case uploadFailed
    case custom(String)
    /// The user must confirm their password before this
    case recentLoginRequired

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You're signed out. Please sign in again."
        case .usernameTaken:
            return "That username is taken. Try another one."
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Check your connection and try again."
        case .unknownError:
            return "Something went wrong. Please try again."
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Use at least 8 characters with an uppercase letter, a lowercase letter and a number."
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
