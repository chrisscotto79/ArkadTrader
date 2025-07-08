// File: Shared/Services/FirebaseServices.swift
// Updated Firebase Services with Complete User Interactions

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    private init() {
        checkAuth()
    }
    
    // MARK: - Auth Methods
    
    func checkAuth() {
        if let firebaseUser = Auth.auth().currentUser {
            Task {
                await loadUser(uid: firebaseUser.uid)
            }
        }
    }
    
    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let docRef = db.collection("users").document(result.user.uid)
            let snapshot = try await docRef.getDocument()

            if snapshot.exists {
                await loadUser(uid: result.user.uid)
            } else {
                // If no user doc exists, create a basic one
                let user = User(id: result.user.uid, email: email, username: email.components(separatedBy: "@")[0], fullName: "")
                try await docRef.setData(user.toFirestore())
                currentUser = user
                isAuthenticated = true
            }
        } catch {
            print("Login error: \(error.localizedDescription)")
            throw error
        }
    }

    func register(email: String, password: String, username: String, fullName: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            let newUser = User(
                id: result.user.uid,
                email: email,
                username: username.lowercased(),
                fullName: fullName
            )

            try await db.collection("users").document(result.user.uid).setData(newUser.toFirestore())

            currentUser = newUser
            isAuthenticated = true
        } catch {
            print("Register error: \(error.localizedDescription)")
            throw error
        }
    }

    func logout() async {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
            removeAllListeners()
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    func updateProfile(fullName: String?, bio: String?) async throws {
        guard let userId = currentUser?.id else { return }
        
        var updates: [String: Any] = [:]
        if let fullName = fullName {
            updates["fullName"] = fullName
        }
        if let bio = bio {
            updates["bio"] = bio
        }
        updates["updatedAt"] = Timestamp(date: Date())
        
        try await db.collection("users").document(userId).updateData(updates)
        
        // Update local user
        if var user = currentUser {
            if let fullName = fullName {
                user.fullName = fullName
            }
            if let bio = bio {
                user.bio = bio
            }
            currentUser = user
        }
    }
    
    private func loadUser(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            if let data = document.data() {
                currentUser = try User.fromFirestore(data: data, id: uid)
                isAuthenticated = true
            }
        } catch {
            print("Error loading user: \(error)")
            isAuthenticated = false
        }
    }
    
    // MARK: - Trade Methods
    
    func addTrade(_ trade: Trade) async throws {
        try await db.collection("trades").document(trade.id).setData(trade.toFirestore())
    }
    
    func updateTrade(_ trade: Trade) async throws {
        try await db.collection("trades").document(trade.id).setData(trade.toFirestore())
    }
    
    func deleteTrade(tradeId: String) async throws {
        try await db.collection("trades").document(tradeId).delete()
    }
    
    func getUserTrades(userId: String) async throws -> [Trade] {
        let snapshot = try await db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .order(by: "entryDate", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Trade.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func listenToUserTrades(userId: String, completion: @escaping ([Trade]) -> Void) {
        let listener = db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .order(by: "entryDate", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching trades: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let trades = documents.compactMap { document in
                    try? Trade.fromFirestore(data: document.data(), id: document.documentID)
                }
                
                completion(trades)
            }
        
        listeners.append(listener)
    }
    
    // MARK: - Post Methods
    
    func createPost(_ post: Post) async throws {
        try await db.collection("posts").document(post.id).setData(post.toFirestore())
    }
    
    func getFeedPosts() async throws -> [Post] {
        let snapshot = try await db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Post.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    // MARK: - Like/Unlike Methods
    
    func likePost(postId: String, userId: String) async throws {
        let batch = db.batch()
        
        // Add to user's likes subcollection
        let userLikeRef = db.collection("users").document(userId).collection("likes").document(postId)
        batch.setData([
            "postId": postId,
            "likedAt": Timestamp(date: Date())
        ], forDocument: userLikeRef)
        
        // Increment post's like count
        let postRef = db.collection("posts").document(postId)
        batch.updateData([
            "likesCount": FieldValue.increment(Int64(1))
        ], forDocument: postRef)
        
        try await batch.commit()
    }
    
    func unlikePost(postId: String, userId: String) async throws {
        let batch = db.batch()
        
        // Remove from user's likes subcollection
        let userLikeRef = db.collection("users").document(userId).collection("likes").document(postId)
        batch.deleteDocument(userLikeRef)
        
        // Decrement post's like count
        let postRef = db.collection("posts").document(postId)
        batch.updateData([
            "likesCount": FieldValue.increment(Int64(-1))
        ], forDocument: postRef)
        
        try await batch.commit()
    }
    
    func getUserLikedPosts(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId).collection("likes").getDocuments()
        return Set(snapshot.documents.map { $0.documentID })
    }
    
    // MARK: - Bookmark Methods
    
    func bookmarkPost(postId: String, userId: String) async throws {
        let userBookmarkRef = db.collection("users").document(userId).collection("bookmarks").document(postId)
        try await userBookmarkRef.setData([
            "postId": postId,
            "bookmarkedAt": Timestamp(date: Date())
        ])
    }
    
    func unbookmarkPost(postId: String, userId: String) async throws {
        let userBookmarkRef = db.collection("users").document(userId).collection("bookmarks").document(postId)
        try await userBookmarkRef.delete()
    }
    
    func getUserBookmarkedPosts(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId).collection("bookmarks").getDocuments()
        return Set(snapshot.documents.map { $0.documentID })
    }
    
    // MARK: - Following Methods
    
    func followUser(userId: String, targetUserId: String) async throws {
        let batch = db.batch()
        
        // Add to user's following
        let followingRef = db.collection("users").document(userId).collection("following").document(targetUserId)
        batch.setData([
            "userId": targetUserId,
            "followedAt": Timestamp(date: Date())
        ], forDocument: followingRef)
        
        // Add to target user's followers
        let followerRef = db.collection("users").document(targetUserId).collection("followers").document(userId)
        batch.setData([
            "userId": userId,
            "followedAt": Timestamp(date: Date())
        ], forDocument: followerRef)
        
        // Update counts
        let userRef = db.collection("users").document(userId)
        batch.updateData(["followingCount": FieldValue.increment(Int64(1))], forDocument: userRef)
        
        let targetUserRef = db.collection("users").document(targetUserId)
        batch.updateData(["followersCount": FieldValue.increment(Int64(1))], forDocument: targetUserRef)
        
        try await batch.commit()
    }
    
    func unfollowUser(userId: String, targetUserId: String) async throws {
        let batch = db.batch()
        
        // Remove from user's following
        let followingRef = db.collection("users").document(userId).collection("following").document(targetUserId)
        batch.deleteDocument(followingRef)
        
        // Remove from target user's followers
        let followerRef = db.collection("users").document(targetUserId).collection("followers").document(userId)
        batch.deleteDocument(followerRef)
        
        // Update counts
        let userRef = db.collection("users").document(userId)
        batch.updateData(["followingCount": FieldValue.increment(Int64(-1))], forDocument: userRef)
        
        let targetUserRef = db.collection("users").document(targetUserId)
        batch.updateData(["followersCount": FieldValue.increment(Int64(-1))], forDocument: targetUserRef)
        
        try await batch.commit()
    }
    
    func getUserFollowing(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId).collection("following").getDocuments()
        return Set(snapshot.documents.map { $0.documentID })
    }
    
    func getUserFollowers(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId).collection("followers").getDocuments()
        return Set(snapshot.documents.map { $0.documentID })
    }
    
    // MARK: - Report and Block Methods
    
    func reportPost(postId: String, reportedBy: String, reason: String) async throws {
        let reportRef = db.collection("reports").document()
        try await reportRef.setData([
            "postId": postId,
            "reportedBy": reportedBy,
            "reason": reason,
            "reportedAt": Timestamp(date: Date()),
            "status": "pending"
        ])
    }
    
    func blockUser(userId: String, blockedBy: String) async throws {
        let blockRef = db.collection("users").document(blockedBy).collection("blocked").document(userId)
        try await blockRef.setData([
            "userId": userId,
            "blockedAt": Timestamp(date: Date())
        ])
    }
    
    func unblockUser(userId: String, unblockedBy: String) async throws {
        let blockRef = db.collection("users").document(unblockedBy).collection("blocked").document(userId)
        try await blockRef.delete()
    }
    
    func getUserBlockedUsers(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId).collection("blocked").getDocuments()
        return Set(snapshot.documents.map { $0.documentID })
    }
    
    // MARK: - Community Methods
    
    func createCommunity(_ community: Community) async throws {
        try await db.collection("communities").document(community.id).setData(community.toFirestore())
    }
    
    func getCommunities() async throws -> [Community] {
        let snapshot = try await db.collection("communities")
            .order(by: "memberCount", descending: true)
            .limit(to: 20)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Community.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func joinCommunity(communityId: String, userId: String) async throws {
        // Add user to community members
        try await db.collection("communities").document(communityId).updateData([
            "memberCount": FieldValue.increment(Int64(1))
        ])
        
        // Add community to user's communities
        try await db.collection("users").document(userId).updateData([
            "communityIds": FieldValue.arrayUnion([communityId])
        ])
    }
    
    // MARK: - Comment Methods
    
    func addComment(postId: String, content: String, authorId: String, authorUsername: String) async throws {
        let comment = Comment(
            postId: postId,
            content: content,
            authorId: authorId,
            authorUsername: authorUsername
        )
        
        let batch = db.batch()
        
        // Add comment to comments collection
        let commentRef = db.collection("comments").document(comment.id)
        batch.setData(comment.toFirestore(), forDocument: commentRef)
        
        // Increment post's comment count
        let postRef = db.collection("posts").document(postId)
        batch.updateData([
            "commentsCount": FieldValue.increment(Int64(1))
        ], forDocument: postRef)
        
        try await batch.commit()
    }
    
    func getCommentsForPost(postId: String) async throws -> [Comment] {
        let snapshot = try await db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Comment.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    // MARK: - User Methods
    
    func updateUserStats(userId: String, totalProfitLoss: Double, winRate: Double) async throws {
        try await db.collection("users").document(userId).updateData([
            "totalProfitLoss": totalProfitLoss,
            "winRate": winRate,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Search Methods
    
    func searchUsers(query: String) async throws -> [User] {
        // Note: Firestore doesn't have full-text search, so this is a simple prefix search
        let snapshot = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query.lowercased())
            .whereField("username", isLessThan: query.lowercased() + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? User.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func searchPosts(query: String) async throws -> [Post] {
        // Simple search implementation - in production you'd use Algolia or similar
        let snapshot = try await db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        let posts = snapshot.documents.compactMap { document in
            try? Post.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        return posts.filter { post in
            post.content.localizedCaseInsensitiveContains(query) ||
            post.authorUsername.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - Clean up
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}

// MARK: - Comment Model
struct Comment: Identifiable, Codable {
    let id: String
    let postId: String
    let content: String
    let authorId: String
    let authorUsername: String
    let createdAt: Date
    let likesCount: Int

    // Initializer for creating a new comment
    init(postId: String, content: String, authorId: String, authorUsername: String) {
        self.id = UUID().uuidString
        self.postId = postId
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.createdAt = Date()
        self.likesCount = 0
    }

    // Initializer for loading from Firestore
    init(id: String, postId: String, content: String, authorId: String, authorUsername: String, createdAt: Date, likesCount: Int) {
        self.id = id
        self.postId = postId
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.createdAt = createdAt
        self.likesCount = likesCount
    }

    func toFirestore() -> [String: Any] {
        return [
            "postId": postId,
            "content": content,
            "authorId": authorId,
            "authorUsername": authorUsername,
            "createdAt": Timestamp(date: createdAt),
            "likesCount": likesCount
        ]
    }

    static func fromFirestore(data: [String: Any], id: String) throws -> Comment {
        guard let postId = data["postId"] as? String,
              let content = data["content"] as? String,
              let authorId = data["authorId"] as? String,
              let authorUsername = data["authorUsername"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let likesCount = data["likesCount"] as? Int else {
            throw FirestoreError.invalidData
        }

        return Comment(
            id: id,
            postId: postId,
            content: content,
            authorId: authorId,
            authorUsername: authorUsername,
            createdAt: createdAtTimestamp.dateValue(),
            likesCount: likesCount
        )
    }
}


// Keep the old name for compatibility
typealias FirestoreService = FirebaseAuthService

enum FirestoreError: Error {
    case invalidData
    case userNotFound
    case unauthorized
}
