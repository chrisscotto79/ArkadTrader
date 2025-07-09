// File: Shared/Services/FirebaseServices.swift
// Complete Firebase Services with all functionality and correct following/follower handling

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

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
            .whereField("username", isGreaterThanOrEqualTo: query.lowercased())
            .whereField("username", isLessThan: query.lowercased() + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? User.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func updateUserOnlineStatus(userId: String, isOnline: Bool) async throws {
        try await db.collection("users").document(userId).updateData([
            "isOnline": isOnline,
            "lastSeen": Timestamp(date: Date())
        ])
    }
    
    func updateUserStats(userId: String, totalProfitLoss: Double, winRate: Double) async throws {
        try await db.collection("users").document(userId).updateData([
            "totalProfitLoss": totalProfitLoss,
            "winRate": winRate,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Following Methods (Fixed to use subcollections)
    
    func followUser(userId: String, followerId: String) async throws {
        let batch = db.batch()
        
        // Add to follower's following subcollection
        let followingRef = db.collection("users").document(followerId).collection("following").document(userId)
        batch.setData([
            "userId": userId,
            "followedAt": Timestamp(date: Date())
        ], forDocument: followingRef)
        
        // Add to user's followers subcollection
        let followerRef = db.collection("users").document(userId).collection("followers").document(followerId)
        batch.setData([
            "userId": followerId,
            "followedAt": Timestamp(date: Date())
        ], forDocument: followerRef)
        
        // Update counts
        let userRef = db.collection("users").document(userId)
        batch.updateData(["followersCount": FieldValue.increment(Int64(1))], forDocument: userRef)
        
        let followerUserRef = db.collection("users").document(followerId)
        batch.updateData(["followingCount": FieldValue.increment(Int64(1))], forDocument: followerUserRef)
        
        try await batch.commit()
    }
    
    func unfollowUser(userId: String, followerId: String) async throws {
        let batch = db.batch()
        
        // Remove from follower's following subcollection
        let followingRef = db.collection("users").document(followerId).collection("following").document(userId)
        batch.deleteDocument(followingRef)
        
        // Remove from user's followers subcollection
        let followerRef = db.collection("users").document(userId).collection("followers").document(followerId)
        batch.deleteDocument(followerRef)
        
        // Update counts
        let userRef = db.collection("users").document(userId)
        batch.updateData(["followersCount": FieldValue.increment(Int64(-1))], forDocument: userRef)
        
        let followerUserRef = db.collection("users").document(followerId)
        batch.updateData(["followingCount": FieldValue.increment(Int64(-1))], forDocument: followerUserRef)
        
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
    
    func isFollowing(userId: String, targetUserId: String) async throws -> Bool {
        let document = try await db.collection("users").document(userId).collection("following").document(targetUserId).getDocument()
        return document.exists
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
    
    func copyTrade(tradeId: String, userId: String) async throws {
        guard let originalTrade = try await getTradeById(tradeId: tradeId) else {
            throw NSError(domain: "TradeNotFound", code: 404, userInfo: [NSLocalizedDescriptionKey: "Original trade not found"])
        }
        
        var copiedTrade = Trade(
            ticker: originalTrade.ticker,
            tradeType: originalTrade.tradeType,
            entryPrice: originalTrade.entryPrice,
            quantity: originalTrade.quantity,
            userId: userId
        )
        copiedTrade.notes = "Copied from @\(originalTrade.userId)"
        copiedTrade.strategy = originalTrade.strategy
        
        try await addTrade(copiedTrade)
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
    
    func updateCommunityMemberRole(communityId: String, userId: String, role: String) async throws {
        try await db.collection("communities").document(communityId)
            .collection("members").document(userId)
            .updateData(["role": role])
    }
    
    // MARK: - Group Management Methods (Enhanced Communities)
    
    func createGroup(name: String, description: String, isPrivate: Bool, createdBy: String) async throws -> Community {
        let groupType: CommunityType = isPrivate ? .general : .general // You can add private type
        let group = Community(name: name, description: description, type: groupType, createdBy: createdBy)
        
        var groupData = group.toFirestore()
        groupData["isPrivate"] = isPrivate
        groupData["groupType"] = "group"
        
        try await db.collection("communities").document(group.id).setData(groupData)
        try await joinCommunity(communityId: group.id, userId: createdBy)
        
        return group
    }
    
    func getGroups(userId: String) async throws -> [Community] {
        let snapshot = try await db.collection("communities")
            .whereField("groupType", isEqualTo: "group")
            .whereField("members", arrayContains: userId)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Community.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func inviteToGroup(groupId: String, inviterId: String, inviteeId: String) async throws {
        let inviteRef = db.collection("groupInvites").document()
        try await inviteRef.setData([
            "groupId": groupId,
            "inviterId": inviterId,
            "inviteeId": inviteeId,
            "status": "pending",
            "createdAt": Timestamp(date: Date())
        ])
    }
    
    func respondToGroupInvite(inviteId: String, accept: Bool) async throws {
        let inviteRef = db.collection("groupInvites").document(inviteId)
        let inviteDoc = try await inviteRef.getDocument()
        
        guard let inviteData = inviteDoc.data(),
              let groupId = inviteData["groupId"] as? String,
              let inviteeId = inviteData["inviteeId"] as? String else {
            throw NSError(domain: "InvalidInvite", code: 400, userInfo: nil)
        }
        
        if accept {
            try await joinCommunity(communityId: groupId, userId: inviteeId)
        }
        
        try await inviteRef.updateData([
            "status": accept ? "accepted" : "declined",
            "respondedAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Messaging Methods
    
    func sendMessage(to recipientId: String, content: String, senderId: String) async throws {
        let conversationId = generateConversationId(user1: senderId, user2: recipientId)
        let message = Message(senderId: senderId, recipientId: recipientId, content: content)
        
        let batch = db.batch()
        
        // Add message to messages collection
        let messageRef = db.collection("messages").document(message.id.uuidString)
        batch.setData([
            "senderId": message.senderId,
            "recipientId": message.recipientId,
            "content": message.content,
            "timestamp": Timestamp(date: message.timestamp),
            "conversationId": conversationId,
            "isRead": false
        ], forDocument: messageRef)
        
        // Update conversation
        let conversationRef = db.collection("conversations").document(conversationId)
        batch.setData([
            "participants": [senderId, recipientId],
            "lastMessage": content,
            "lastMessageTimestamp": Timestamp(date: message.timestamp),
            "lastMessageSenderId": senderId,
            "updatedAt": Timestamp(date: Date())
        ], forDocument: conversationRef, merge: true)
        
        try await batch.commit()
    }
    
    func getConversations(userId: String) async throws -> [Conversation] {
        let snapshot = try await db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .order(by: "lastMessageTimestamp", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Conversation.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func getMessages(conversationId: String, limit: Int = 50) async throws -> [Message] {
        let snapshot = try await db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? MessageFirestore.fromFirestore(data: document.data(), id: document.documentID)
        }.reversed()
    }
    
    func markMessagesAsRead(conversationId: String, userId: String) async throws {
        let snapshot = try await db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()
        
        let batch = db.batch()
        for document in snapshot.documents {
            batch.updateData(["isRead": true], forDocument: document.reference)
        }
        
        try await batch.commit()
    }
    
    func listenToConversation(conversationId: String, completion: @escaping ([Message]) -> Void) {
        let listener = db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let messages = documents.compactMap { document in
                    try? MessageFirestore.fromFirestore(data: document.data(), id: document.documentID)
                }
                
                completion(messages)
            }
        
        listeners.append(listener)
    }
    
    func deleteMessage(messageId: String) async throws {
        try await db.collection("messages").document(messageId).delete()
    }
    
    func getUnreadMessageCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("messages")
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()
        
        return snapshot.documents.count
    }
    
    private func generateConversationId(user1: String, user2: String) -> String {
        let sortedIds = [user1, user2].sorted()
        return sortedIds.joined(separator: "_")
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
    
    func deleteComment(commentId: String, postId: String) async throws {
        let batch = db.batch()
        
        // Delete comment
        let commentRef = db.collection("comments").document(commentId)
        batch.deleteDocument(commentRef)
        
        // Decrement post's comment count
        let postRef = db.collection("posts").document(postId)
        batch.updateData([
            "commentsCount": FieldValue.increment(Int64(-1))
        ], forDocument: postRef)
        
        try await batch.commit()
    }
    
    // MARK: - Report and Block Methods
    
    func reportPost(postId: String, reportedBy: String, reason: String) async throws {
        let reportRef = db.collection("reports").document()
        try await reportRef.setData([
            "postId": postId,
            "reportedBy": reportedBy,
            "reason": reason,
            "reportedAt": Timestamp(date: Date()),
            "status": "pending",
            "type": "post"
        ])
    }
    
    func reportUser(userId: String, reportedBy: String, reason: String) async throws {
        let reportRef = db.collection("reports").document()
        try await reportRef.setData([
            "userId": userId,
            "reportedBy": reportedBy,
            "reason": reason,
            "reportedAt": Timestamp(date: Date()),
            "status": "pending",
            "type": "user"
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
    
    func isUserBlocked(userId: String, by blockedBy: String) async throws -> Bool {
        let document = try await db.collection("users").document(blockedBy).collection("blocked").document(userId).getDocument()
        return document.exists
    }
    
    // MARK: - Market News Methods
    
    func cacheMarketNews(articles: [MarketNewsArticle]) async throws {
        let batch = db.batch()
        
        // First, delete old cached news (keep only last 50 articles)
        let oldNewsSnapshot = try await db.collection("marketNews")
            .order(by: "cachedAt", descending: false)
            .getDocuments()
        
        // Delete old news if we have more than 50 articles
        if oldNewsSnapshot.documents.count > 50 {
            let documentsToDelete = oldNewsSnapshot.documents.prefix(oldNewsSnapshot.documents.count - 30)
            for document in documentsToDelete {
                batch.deleteDocument(document.reference)
            }
        }
        
        // Add new articles
        for article in articles {
            let docRef = db.collection("marketNews").document(article.id)
            batch.setData(article.toFirestore(), forDocument: docRef)
        }
        
        try await batch.commit()
    }
    
    func getCachedMarketNews() async throws -> [MarketNewsArticle] {
        let snapshot = try await db.collection("marketNews")
            .order(by: "cachedAt", descending: true)
            .limit(to: 20)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? MarketNewsArticle.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func clearOldMarketNews() async throws {
        // Delete news older than 24 hours
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        let snapshot = try await db.collection("marketNews")
            .whereField("cachedAt", isLessThan: oneDayAgo)
            .getDocuments()
        
        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        if !snapshot.documents.isEmpty {
            try await batch.commit()
        }
    }
    
    func searchMarketNews(query: String) async throws -> [MarketNewsArticle] {
        // Search cached market news
        let snapshot = try await db.collection("marketNews")
            .order(by: "cachedAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        let articles = snapshot.documents.compactMap { document in
            try? MarketNewsArticle.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        return articles.filter { article in
            article.title.localizedCaseInsensitiveContains(query) ||
            (article.description?.localizedCaseInsensitiveContains(query) ?? false) ||
            article.keywords.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    // MARK: - Notification Methods
    
    func sendNotification(to userId: String, type: String, title: String, body: String, data: [String: Any] = [:]) async throws {
        let notificationRef = db.collection("notifications").document()
        try await notificationRef.setData([
            "userId": userId,
            "type": type,
            "title": title,
            "body": body,
            "data": data,
            "isRead": false,
            "createdAt": Timestamp(date: Date())
        ])
    }
    
    func getUserNotifications(userId: String, limit: Int = 50) async throws -> [UserNotification] {
        let snapshot = try await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? UserNotification.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func markNotificationAsRead(notificationId: String) async throws {
        try await db.collection("notifications").document(notificationId)
            .updateData(["isRead": true])
    }
    
    func getUnreadNotificationCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()
        
        return snapshot.documents.count
    }
    
    // MARK: - Analytics Methods
    
    func getMarketNewsAnalytics() async throws -> NewsAnalytics {
        let snapshot = try await db.collection("marketNews")
            .order(by: "cachedAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        let articles = snapshot.documents.compactMap { document in
            try? MarketNewsArticle.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        let totalArticles = articles.count
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        
        let recentArticles = articles.filter { article in
            article.cachedAt > oneDayAgo
        }.count
        
        // Get most common keywords
        let allKeywords = articles.flatMap { $0.keywords }
        let keywordCounts = Dictionary(grouping: allKeywords, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        let topKeywords = Array(keywordCounts.prefix(10).map { $0.key })
        
        return NewsAnalytics(
            totalArticles: totalArticles,
            recentArticles: recentArticles,
            topKeywords: topKeywords,
            lastUpdated: articles.first?.cachedAt ?? Date()
        )
    }
    
    func trackUserActivity(userId: String, action: String, details: [String: Any] = [:]) async throws {
        let activityRef = db.collection("userActivity").document()
        try await activityRef.setData([
            "userId": userId,
            "action": action,
            "details": details,
            "timestamp": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Clean up
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}

// MARK: - Supporting Models

// MARK: - Message Models for Firestore
struct MessageFirestore {
    let id: String
    let senderId: String
    let recipientId: String
    let content: String
    let timestamp: Date
    let conversationId: String
    let isRead: Bool
    
    static func fromFirestore(data: [String: Any], id: String) throws -> Message {
        guard let senderId = data["senderId"] as? String,
              let recipientId = data["recipientId"] as? String,
              let content = data["content"] as? String,
              let timestamp = data["timestamp"] as? Timestamp else {
            throw NSError(domain: "MessageDecoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid message data"])
        }
        
        return Message(senderId: senderId, recipientId: recipientId, content: content)
    }
}

// MARK: - Conversation Model
struct Conversation: Identifiable, Codable {
    let id: String
    let participants: [String]
    let lastMessage: String
    let lastMessageTimestamp: Date
    let lastMessageSenderId: String
    let updatedAt: Date
    
    static func fromFirestore(data: [String: Any], id: String) throws -> Conversation {
        guard let participants = data["participants"] as? [String],
              let lastMessage = data["lastMessage"] as? String,
              let lastMessageTimestamp = data["lastMessageTimestamp"] as? Timestamp,
              let lastMessageSenderId = data["lastMessageSenderId"] as? String,
              let updatedAt = data["updatedAt"] as? Timestamp else {
            throw NSError(domain: "ConversationDecoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid conversation data"])
        }
        
        return Conversation(
            id: id,
            participants: participants,
            lastMessage: lastMessage,
            lastMessageTimestamp: lastMessageTimestamp.dateValue(),
            lastMessageSenderId: lastMessageSenderId,
            updatedAt: updatedAt.dateValue()
        )
    }
}

// MARK: - User Notification Model
struct UserNotification: Identifiable {
    let id: String
    let userId: String
    let type: String
    let title: String
    let body: String
    let data: [String: Any]
    let isRead: Bool
    let createdAt: Date

    static func fromFirestore(data: [String: Any], id: String) throws -> UserNotification {
        guard let userId = data["userId"] as? String,
              let type = data["type"] as? String,
              let title = data["title"] as? String,
              let body = data["body"] as? String,
              let isRead = data["isRead"] as? Bool,
              let createdAt = data["createdAt"] as? Timestamp else {
            throw NSError(domain: "NotificationDecoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid notification data"])
        }

        return UserNotification(
            id: id,
            userId: userId,
            type: type,
            title: title,
            body: body,
            data: data["data"] as? [String: Any] ?? [:],
            isRead: isRead,
            createdAt: createdAt.dateValue()
        )
    }
}

// MARK: - Comment Model (Enhanced)
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

// MARK: - News Analytics Model
struct NewsAnalytics {
    let totalArticles: Int
    let recentArticles: Int
    let topKeywords: [String]
    let lastUpdated: Date
}

// MARK: - Custom Errors
enum FirestoreError: Error {
    case invalidData
    case userNotFound
    case unauthorized
}
