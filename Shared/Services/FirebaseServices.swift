// File: Shared/Services/FirebaseServices.swift
// Complete Firebase Services with all search functionality

import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirebaseServices {
    static let shared = FirebaseServices()
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    private init() {}
    
    // MARK: - User Management Methods
    
    func createUser(_ user: User) async throws {
        try await db.collection("users").document(user.id).setData(user.toFirestore())
    }
    
    func updateUser(_ user: User) async throws {
        try await db.collection("users").document(user.id).setData(user.toFirestore())
    }
    
    func getUserById(userId: String) async throws -> User? {
        let document = try await db.collection("users").document(userId).getDocument()
        guard let data = document.data() else { return nil }
        return try User.fromFirestore(data: data, id: userId)
    }
    
    func searchUsers(query: String) async throws -> [User] {
        let snapshot = try await db.collection("users")
            .order(by: "username")
            .limit(to: 100)
            .getDocuments()
        
        let users = snapshot.documents.compactMap { document in
            try? User.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        return users.filter { user in
            user.username.localizedCaseInsensitiveContains(query) ||
            user.fullName.localizedCaseInsensitiveContains(query)
        }
    }
    
    func updateUserOnlineStatus(userId: String, isOnline: Bool) async throws {
        try await db.collection("users").document(userId).updateData([
            "isOnline": isOnline,
            "lastSeen": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Follow/Unfollow Methods
    
    func followUser(userId: String, followerId: String) async throws {
        let batch = db.batch()
        
        // Add to follower's following list
        let followerRef = db.collection("users").document(followerId)
        batch.updateData([
            "followingIds": FieldValue.arrayUnion([userId]),
            "followingCount": FieldValue.increment(Int64(1))
        ], forDocument: followerRef)
        
        // Add to user's followers list
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "followerIds": FieldValue.arrayUnion([followerId]),
            "followersCount": FieldValue.increment(Int64(1))
        ], forDocument: userRef)
        
        try await batch.commit()
    }
    
    func unfollowUser(userId: String, followerId: String) async throws {
        let batch = db.batch()
        
        // Remove from follower's following list
        let followerRef = db.collection("users").document(followerId)
        batch.updateData([
            "followingIds": FieldValue.arrayRemove([userId]),
            "followingCount": FieldValue.increment(Int64(-1))
        ], forDocument: followerRef)
        
        // Remove from user's followers list
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "followerIds": FieldValue.arrayRemove([followerId]),
            "followersCount": FieldValue.increment(Int64(-1))
        ], forDocument: userRef)
        
        try await batch.commit()
    }
    
    func getUserFollowing(userId: String) async throws -> Set<String> {
        let user = try await getUserById(userId: userId)
        return Set(user?.followingIds ?? [])
    }
    
    // MARK: - Trade Management Methods
    
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
    
    func searchTrades(query: String) async throws -> [Trade] {
        let snapshot = try await db.collection("trades")
            .order(by: "entryDate", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        let trades = snapshot.documents.compactMap { document in
            try? Trade.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        // Filter trades by ticker symbol, notes, or strategy
        return trades.filter { trade in
            trade.ticker.localizedCaseInsensitiveContains(query) ||
            (trade.notes?.localizedCaseInsensitiveContains(query) ?? false) ||
            (trade.strategy?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    
    func getTradeById(tradeId: String) async throws -> Trade? {
        let document = try await db.collection("trades").document(tradeId).getDocument()
        guard let data = document.data() else { return nil }
        return try Trade.fromFirestore(data: data, id: tradeId)
    }
    
    // MARK: - Post/Feed Management Methods
    
    func createPost(_ post: Post) async throws {
        try await db.collection("posts").document(post.id).setData(post.toFirestore())
    }
    
    func updatePost(_ post: Post) async throws {
        try await db.collection("posts").document(post.id).setData(post.toFirestore())
    }
    
    func deletePost(postId: String) async throws {
        let batch = db.batch()
        
        // Delete post
        let postRef = db.collection("posts").document(postId)
        batch.deleteDocument(postRef)
        
        // Delete all comments for this post
        let commentsSnapshot = try await db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .getDocuments()
        
        for commentDoc in commentsSnapshot.documents {
            batch.deleteDocument(commentDoc.reference)
        }
        
        try await batch.commit()
    }
    
    func getFeedPosts(limit: Int = 50) async throws -> [Post] {
        let snapshot = try await db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Post.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func getUserPosts(userId: String) async throws -> [Post] {
        let snapshot = try await db.collection("posts")
            .whereField("authorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Post.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func getFollowingPosts(userId: String) async throws -> [Post] {
        let followingIds = try await getUserFollowing(userId: userId)
        guard !followingIds.isEmpty else { return [] }
        
        let snapshot = try await db.collection("posts")
            .whereField("authorId", in: Array(followingIds))
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Post.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func searchPosts(query: String) async throws -> [Post] {
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
    
    // MARK: - Like/Unlike Methods
    
    func likePost(postId: String, userId: String) async throws {
        let batch = db.batch()
        
        // Add to likes collection
        let likeRef = db.collection("likes").document("\(userId)_\(postId)")
        batch.setData([
            "userId": userId,
            "postId": postId,
            "timestamp": Timestamp(date: Date())
        ], forDocument: likeRef)
        
        // Update post like count
        let postRef = db.collection("posts").document(postId)
        batch.updateData([
            "likeCount": FieldValue.increment(Int64(1))
        ], forDocument: postRef)
        
        try await batch.commit()
    }
    
    func unlikePost(postId: String, userId: String) async throws {
        let batch = db.batch()
        
        // Remove from likes collection
        let likeRef = db.collection("likes").document("\(userId)_\(postId)")
        batch.deleteDocument(likeRef)
        
        // Update post like count
        let postRef = db.collection("posts").document(postId)
        batch.updateData([
            "likeCount": FieldValue.increment(Int64(-1))
        ], forDocument: postRef)
        
        try await batch.commit()
    }
    
    func getUserLikedPosts(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("likes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let postIds = snapshot.documents.compactMap { document in
            document.data()["postId"] as? String
        }
        
        return Set(postIds)
    }
    
    // MARK: - Bookmark Methods
    
    func bookmarkPost(postId: String, userId: String) async throws {
        let bookmarkRef = db.collection("bookmarks").document("\(userId)_\(postId)")
        try await bookmarkRef.setData([
            "userId": userId,
            "postId": postId,
            "timestamp": Timestamp(date: Date())
        ])
    }
    
    func unbookmarkPost(postId: String, userId: String) async throws {
        let bookmarkRef = db.collection("bookmarks").document("\(userId)_\(postId)")
        try await bookmarkRef.delete()
    }
    
    func getUserBookmarkedPosts(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("bookmarks")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let postIds = snapshot.documents.compactMap { document in
            document.data()["postId"] as? String
        }
        
        return Set(postIds)
    }
    
    // MARK: - Community Management Methods
    
    func createCommunity(_ community: Community) async throws {
        try await db.collection("communities").document(community.id).setData(community.toFirestore())
        
        // Add creator as first member
        try await joinCommunity(communityId: community.id, userId: community.createdBy)
    }
    
    func updateCommunity(_ community: Community) async throws {
        try await db.collection("communities").document(community.id).setData(community.toFirestore())
    }
    
    func deleteCommunity(communityId: String) async throws {
        let batch = db.batch()
        
        // Delete community
        let communityRef = db.collection("communities").document(communityId)
        batch.deleteDocument(communityRef)
        
        // Remove community from all users
        let membersSnapshot = try await db.collection("communities").document(communityId)
            .collection("members").getDocuments()
        
        for memberDoc in membersSnapshot.documents {
            let userId = memberDoc.documentID
            batch.updateData([
                "communityIds": FieldValue.arrayRemove([communityId])
            ], forDocument: db.collection("users").document(userId))
        }
        
        try await batch.commit()
    }
    
    func getCommunities(limit: Int = 20) async throws -> [Community] {
        let snapshot = try await db.collection("communities")
            .order(by: "memberCount", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Community.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func getUserCommunities(userId: String) async throws -> [Community] {
        let user = try await getUserById(userId: userId)
        guard let communityIds = user?.communityIds, !communityIds.isEmpty else { return [] }
        
        let snapshot = try await db.collection("communities")
            .whereField(FieldPath.documentID(), in: communityIds)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Community.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func searchCommunities(query: String) async throws -> [Community] {
        let snapshot = try await db.collection("communities")
            .order(by: "memberCount", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        let communities = snapshot.documents.compactMap { document in
            try? Community.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        // Filter communities by name or description
        return communities.filter { community in
            community.name.localizedCaseInsensitiveContains(query) ||
            community.description.localizedCaseInsensitiveContains(query)
        }
    }
    
    func joinCommunity(communityId: String, userId: String) async throws {
        let batch = db.batch()
        
        // Add user to community members
        let memberRef = db.collection("communities").document(communityId).collection("members").document(userId)
        batch.setData([
            "userId": userId,
            "joinedAt": Timestamp(date: Date()),
            "role": "member"
        ], forDocument: memberRef)
        
        // Update community member count
        let communityRef = db.collection("communities").document(communityId)
        batch.updateData([
            "memberCount": FieldValue.increment(Int64(1))
        ], forDocument: communityRef)
        
        // Add community to user's communities
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "communityIds": FieldValue.arrayUnion([communityId])
        ], forDocument: userRef)
        
        try await batch.commit()
    }
    
    func leaveCommunity(communityId: String, userId: String) async throws {
        let batch = db.batch()
        
        // Remove user from community members
        let memberRef = db.collection("communities").document(communityId).collection("members").document(userId)
        batch.deleteDocument(memberRef)
        
        // Update community member count
        let communityRef = db.collection("communities").document(communityId)
        batch.updateData([
            "memberCount": FieldValue.increment(Int64(-1))
        ], forDocument: communityRef)
        
        // Remove community from user's communities
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "communityIds": FieldValue.arrayRemove([communityId])
        ], forDocument: userRef)
        
        try await batch.commit()
    }
    
    func getCommunityMembers(communityId: String) async throws -> [User] {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("members").getDocuments()
        
        let userIds = snapshot.documents.map { $0.documentID }
        guard !userIds.isEmpty else { return [] }
        
        let usersSnapshot = try await db.collection("users")
            .whereField(FieldPath.documentID(), in: userIds)
            .getDocuments()
        
        return usersSnapshot.documents.compactMap { document in
            try? User.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    // MARK: - Report Methods
    
    func reportPost(postId: String, reportedBy: String, reason: String) async throws {
        let reportRef = db.collection("reports").document()
        try await reportRef.setData([
            "type": "post",
            "contentId": postId,
            "reportedBy": reportedBy,
            "reason": reason,
            "status": "pending",
            "createdAt": Timestamp(date: Date())
        ])
    }
    
    func blockUser(userId: String, blockedBy: String) async throws {
        let blockRef = db.collection("blocks").document("\(blockedBy)_\(userId)")
        try await blockRef.setData([
            "blockedBy": blockedBy,
            "blockedUser": userId,
            "timestamp": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Clean up
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}

// MARK: - Custom Errors
enum FirestoreError: Error {
    case invalidData
    case userNotFound
    case unauthorized
}
