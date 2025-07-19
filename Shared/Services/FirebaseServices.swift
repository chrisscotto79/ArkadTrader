// File: Shared/Services/FirebaseServices.swift
// Enhanced Firebase Services with Starting Capital Support

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class FirebaseServices {
    static let shared = FirebaseServices()
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    private init() {
        configureFirestore()
    }
    
    // MARK: - Configuration
    private func configureFirestore() {
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
    }
    
    // MARK: - User Management Methods
    
    func createUser(_ user: User) async throws {
        try await db.collection("users").document(user.id).setData(user.toFirestore())
    }
    
    func updateUser(_ user: User) async throws {
        try await db.collection("users").document(user.id).setData(user.toFirestore(), merge: true)
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
    
    // MARK: - New Starting Capital Method
    func updateUserStartingCapital(userId: String, startingCapital: Double) async throws {
        try await db.collection("users").document(userId).updateData([
            "startingCapital": startingCapital,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Following Methods
    func getFollowingPosts(userId: String, limit: Int = 20) async throws -> [Post] {
        // Get user's following list
        let followingSnapshot = try await db.collection("users")
            .document(userId)
            .collection("following")
            .getDocuments()
        
        guard !followingSnapshot.documents.isEmpty else { return [] }
        
        let followingIds = followingSnapshot.documents.map { $0.documentID }
        
        // Query posts from followed users
        let postsSnapshot = try await db.collection("posts")
            .whereField("authorId", in: followingIds)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return postsSnapshot.documents.compactMap { document in
            try? Post.fromFirestore(data: document.data(), id: document.documentID)
        }
    }

    func getFollowingTrades(userId: String, limit: Int = 20) async throws -> [Trade] {
        // Get user's following list
        let followingSnapshot = try await db.collection("users")
            .document(userId)
            .collection("following")
            .getDocuments()
        
        guard !followingSnapshot.documents.isEmpty else { return [] }
        
        let followingIds = followingSnapshot.documents.map { $0.documentID }
        
        // Query public trades from followed users
        let tradesSnapshot = try await db.collection("trades")
            .whereField("userId", in: followingIds)
            .whereField("isPublic", isEqualTo: true)
            .order(by: "entryDate", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return tradesSnapshot.documents.compactMap { document in
            try? Trade.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    func createActivity(_ activity: ActivityItem) async throws {
        try await db.collection("activity").document(activity.id).setData(activity.toFirestore())
    }

    func getComments(postId: String) async throws -> [Comment] {
        let snapshot = try await db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Comment.fromFirestore(data: document.data(), id: document.documentID)
        }
    }

    func getFollowingActivity(userId: String, limit: Int = 50) async throws -> [ActivityItem] {
        let followingSnapshot = try await db.collection("users")
            .document(userId)
            .collection("following")
            .getDocuments()
        
        guard !followingSnapshot.documents.isEmpty else { return [] }
        
        let followingIds = followingSnapshot.documents.map { $0.documentID }
        
        // Get recent activity from followed users
        let activitySnapshot = try await db.collection("activity")
            .whereField("userId", in: followingIds)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return activitySnapshot.documents.compactMap { document in
            try? ActivityItem.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
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
        
        // Remove from collections
        let followingRef = db.collection("users").document(followerId).collection("following").document(userId)
        batch.deleteDocument(followingRef)
        
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
        let document = try await db.collection("users").document(userId)
            .collection("following").document(targetUserId).getDocument()
        return document.exists
    }
    
    // MARK: - Trade Management Methods
    
    func addTrade(_ trade: Trade) async throws {
        try await db.collection("trades").document(trade.id).setData(trade.toFirestore())
    }
    
    func updateTrade(_ trade: Trade) async throws {
        try await db.collection("trades").document(trade.id).setData(trade.toFirestore(), merge: true)
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
    
    func getTradeById(tradeId: String) async throws -> Trade? {
        let document = try await db.collection("trades").document(tradeId).getDocument()
        guard let data = document.data() else { return nil }
        return try Trade.fromFirestore(data: data, id: tradeId)
    }
    
    func copyTrade(tradeId: String, userId: String) async throws {
        guard let originalTrade = try await getTradeById(tradeId: tradeId) else {
            throw FirestoreError.documentNotFound
        }
        
        // Create a new trade based on the original, but for the new user
        var copiedTrade = Trade(
            ticker: originalTrade.ticker,
            tradeType: originalTrade.tradeType,
            entryPrice: originalTrade.entryPrice,
            quantity: originalTrade.quantity,
            userId: userId
        )
        
        // Copy additional properties
        copiedTrade.notes = originalTrade.notes
        copiedTrade.strategy = originalTrade.strategy
        
        try await addTrade(copiedTrade)
    }
    
    func searchTrades(query: String) async throws -> [Trade] {
        let snapshot = try await db.collection("trades")
            .order(by: "entryDate", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        let trades = snapshot.documents.compactMap { document in
            try? Trade.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        return trades.filter { trade in
            trade.ticker.lowercased().contains(query.lowercased()) ||
            (trade.notes ?? "").lowercased().contains(query.lowercased())
        }
    }
    
    // MARK: - Post Management Methods
    
    func createPost(_ post: Post) async throws {
        try await db.collection("posts").document(post.id).setData(post.toFirestore())
    }
    
    func updatePost(_ post: Post) async throws {
        try await db.collection("posts").document(post.id).setData(post.toFirestore(), merge: true)
    }
    
    func deletePost(postId: String) async throws {
        // Delete post and all associated data
        let batch = db.batch()
        
        // Delete the post
        batch.deleteDocument(db.collection("posts").document(postId))
        
        // Delete all comments
        let comments = try await db.collection("posts").document(postId)
            .collection("comments").getDocuments()
        for comment in comments.documents {
            batch.deleteDocument(comment.reference)
        }
        
        // Delete all likes
        let likes = try await db.collection("posts").document(postId)
            .collection("likes").getDocuments()
        for like in likes.documents {
            batch.deleteDocument(like.reference)
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
        let following = try await getUserFollowing(userId: userId)
        guard !following.isEmpty else { return [] }
        
        let snapshot = try await db.collection("posts")
            .whereField("authorId", in: Array(following))
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
            post.content.lowercased().contains(query.lowercased()) ||
            post.authorUsername.lowercased().contains(query.lowercased())
        }
    }
    
    private func checkIfUserLikedPost(postId: String, userId: String) async throws -> Bool {
        // Check both locations
        let postLikeDoc = try await db.collection("posts").document(postId)
            .collection("likes").document(userId).getDocument()
        
        let userNewLikeDoc = try await db.collection("users").document(userId)
            .collection("likedPosts").document(postId).getDocument()
        
        let userOldLikeDoc = try await db.collection("users").document(userId)
            .collection("likes").document(postId).getDocument()
        
        return postLikeDoc.exists || userNewLikeDoc.exists || userOldLikeDoc.exists
    }
    private func checkLikeLocations(postId: String, userId: String) async throws -> Set<String> {
        var locations: Set<String> = []
        
        // Check post likes collection
        do {
            let postLikeDoc = try await db.collection("posts").document(postId)
                .collection("likes").document(userId).getDocument()
            if postLikeDoc.exists {
                locations.insert("post")
            }
        } catch {
            print("⚠️ Error checking post like: \(error)")
        }
        
        // Check user new likes collection
        do {
            let userNewLikeDoc = try await db.collection("users").document(userId)
                .collection("likedPosts").document(postId).getDocument()
            if userNewLikeDoc.exists {
                locations.insert("userNew")
            }
        } catch {
            print("⚠️ Error checking user new like: \(error)")
        }
        
        // Check user old likes collection
        do {
            let userOldLikeDoc = try await db.collection("users").document(userId)
                .collection("likes").document(postId).getDocument()
            if userOldLikeDoc.exists {
                locations.insert("userOld")
            }
        } catch {
            print("⚠️ Error checking user old like: \(error)")
        }
        
        return locations
    }
    // MARK: - Like/Unlike Methods
    
    func likePost(postId: String, userId: String) async throws {
        print("💾 === LIKING POST (ROBUST VERSION) ===")
        print("📝 Post ID: \(postId)")
        print("👤 User ID: \(userId)")
        
        // ✅ First check if user has already liked this post (prevent double-liking)
        let isAlreadyLiked = try await checkIfUserLikedPost(postId: postId, userId: userId)
        if isAlreadyLiked {
            print("⚠️ User has already liked this post - skipping")
            return
        }
        
        let batch = db.batch()
        
        // ✅ 1. Add like document in POST's likes subcollection
        let postLikeRef = db.collection("posts").document(postId).collection("likes").document(userId)
        batch.setData([
            "userId": userId,
            "likedAt": Timestamp(date: Date())
        ], forDocument: postLikeRef)
        print("✅ Will write to: posts/\(postId)/likes/\(userId)")
        
        // ✅ 2. Add like document in USER's likedPosts subcollection
        let userLikeRef = db.collection("users").document(userId).collection("likedPosts").document(postId)
        batch.setData([
            "postId": postId,
            "likedAt": Timestamp(date: Date())
        ], forDocument: userLikeRef)
        print("✅ Will write to: users/\(userId)/likedPosts/\(postId)")
        
        // ✅ 3. Update post's like count
        let postRef = db.collection("posts").document(postId)
        batch.updateData(["likesCount": FieldValue.increment(Int64(1))], forDocument: postRef)
        print("✅ Will increment likesCount on post")
        
        try await batch.commit()
        print("✅ Like batch committed successfully!")
    }

    func unlikePost(postId: String, userId: String) async throws {
        print("🗑️ === UNLIKING POST (ROBUST VERSION) ===")
        print("📝 Post ID: \(postId)")
        print("👤 User ID: \(userId)")
        
        // ✅ Check what like documents actually exist before deleting
        let likeLocations = try await checkLikeLocations(postId: postId, userId: userId)
        
        if likeLocations.isEmpty {
            print("⚠️ No like documents found - user hasn't liked this post")
            return
        }
        
        print("📍 Found likes in locations: \(likeLocations)")
        
        let batch = db.batch()
        var shouldDecrementCount = false
        
        // ✅ Remove from POST's likes collection if it exists there
        if likeLocations.contains("post") {
            let postLikeRef = db.collection("posts").document(postId).collection("likes").document(userId)
            batch.deleteDocument(postLikeRef)
            shouldDecrementCount = true
            print("✅ Will delete: posts/\(postId)/likes/\(userId)")
        }
        
        // ✅ Remove from USER's new likes collection if it exists there
        if likeLocations.contains("userNew") {
            let userNewLikeRef = db.collection("users").document(userId).collection("likedPosts").document(postId)
            batch.deleteDocument(userNewLikeRef)
            if !shouldDecrementCount {
                shouldDecrementCount = true
            }
            print("✅ Will delete: users/\(userId)/likedPosts/\(postId)")
        }
        
        // ✅ Remove from USER's old likes collection if it exists there (cleanup)
        if likeLocations.contains("userOld") {
            let userOldLikeRef = db.collection("users").document(userId).collection("likes").document(postId)
            batch.deleteDocument(userOldLikeRef)
            if !shouldDecrementCount {
                shouldDecrementCount = true
            }
            print("✅ Will delete OLD: users/\(userId)/likes/\(postId)")
        }
        
        // ✅ Only decrement count once, regardless of how many locations had the like
        if shouldDecrementCount {
            let postRef = db.collection("posts").document(postId)
            batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: postRef)
            print("✅ Will decrement likesCount on post")
        }
        
        try await batch.commit()
        print("✅ Unlike completed successfully!")
    }

   
    
    
    
    // ✅ NEW helper method to ensure a specific like is migrated
    func ensureLikeMigration(postId: String, userId: String) async {
        print("🔄 Ensuring migration for post: \(postId), user: \(userId)")
        
        // Check if the like exists in old location but not new location
        do {
            let oldLikeRef = db.collection("users").document(userId).collection("likes").document(postId)
            let oldLikeDoc = try await oldLikeRef.getDocument()
            
            let newLikeRef = db.collection("users").document(userId).collection("likedPosts").document(postId)
            let newLikeDoc = try await newLikeRef.getDocument()
            
            let postLikeRef = db.collection("posts").document(postId).collection("likes").document(userId)
            let postLikeDoc = try await postLikeRef.getDocument()
            
            // If we have old like but missing new ones, migrate this specific like
            if oldLikeDoc.exists && (!newLikeDoc.exists || !postLikeDoc.exists) {
                print("🔄 Migrating single like: \(postId)")
                
                let batch = db.batch()
                
                // Add to new user location
                if !newLikeDoc.exists {
                    batch.setData([
                        "postId": postId,
                        "likedAt": Timestamp(date: Date()),
                        "migratedFromOldFormat": true
                    ], forDocument: newLikeRef)
                }
                
                // Add to post location
                if !postLikeDoc.exists {
                    batch.setData([
                        "userId": userId,
                        "likedAt": Timestamp(date: Date()),
                        "migratedFromOldFormat": true
                    ], forDocument: postLikeRef)
                }
                
                try await batch.commit()
                print("✅ Single like migration completed")
            }
        } catch {
            print("⚠️ Error during single like migration: \(error)")
        }
    }
    func getUserLikedPosts(userId: String) async throws -> Set<String> {
        print("🔍 === LOADING USER LIKED POSTS (ROBUST VERSION) ===")
        print("👤 User ID: \(userId)")
        
        var allLikedPosts: Set<String> = []
        
        // ✅ Load from NEW location (likedPosts)
        do {
            print("🔄 Checking NEW location: users/\(userId)/likedPosts")
            let newLikesSnapshot = try await db.collection("users").document(userId)
                .collection("likedPosts").getDocuments()
            
            let newLikes = Set(newLikesSnapshot.documents.map { $0.documentID })
            allLikedPosts.formUnion(newLikes)
            print("✅ Found \(newLikes.count) likes in NEW location")
        } catch {
            print("⚠️ Could not read from likedPosts: \(error)")
        }
        
        // ✅ Load from OLD location (likes) - but don't duplicate
        do {
            print("🔄 Checking OLD location: users/\(userId)/likes")
            let oldLikesSnapshot = try await db.collection("users").document(userId)
                .collection("likes").getDocuments()
            
            let oldLikes = Set(oldLikesSnapshot.documents.map { $0.documentID })
            
            // Only add old likes that aren't already in new location
            let newOldLikes = oldLikes.subtracting(allLikedPosts)
            allLikedPosts.formUnion(newOldLikes)
            
            print("✅ Found \(oldLikes.count) total in OLD location, \(newOldLikes.count) new ones")
            
            // ✅ Auto-migrate old likes if found
            if !newOldLikes.isEmpty {
                print("🔄 Auto-migrating \(newOldLikes.count) old likes")
                Task {
                    await migrateSpecificLikes(userId: userId, postIds: newOldLikes)
                }
            }
        } catch {
            print("⚠️ Could not read from likes: \(error)")
        }
        
        print("✅ Total unique liked posts: \(allLikedPosts.count)")
        return allLikedPosts
    }
    private func migrateSpecificLikes(userId: String, postIds: Set<String>) async {
        print("🔄 Migrating \(postIds.count) specific likes for user \(userId)")
        
        let batch = db.batch()
        var batchCount = 0
        
        for postId in postIds {
            // Add to new user location
            let newUserLikeRef = db.collection("users").document(userId)
                .collection("likedPosts").document(postId)
            batch.setData([
                "postId": postId,
                "likedAt": Timestamp(date: Date()),
                "migratedFromOldFormat": true
            ], forDocument: newUserLikeRef)
            
            // Add to post's likes collection
            let postLikeRef = db.collection("posts").document(postId)
                .collection("likes").document(userId)
            batch.setData([
                "userId": userId,
                "likedAt": Timestamp(date: Date()),
                "migratedFromOldFormat": true
            ], forDocument: postLikeRef)
            
            batchCount += 2
            
            // Commit in batches to avoid hitting Firestore limits
            if batchCount >= 400 {
                do {
                    try await batch.commit()
                    print("✅ Migrated batch of likes")
                    batchCount = 0
                } catch {
                    print("❌ Error migrating batch: \(error)")
                }
            }
        }
        
        // Commit remaining operations
        if batchCount > 0 {
            do {
                try await batch.commit()
                print("✅ Migration completed")
            } catch {
                print("❌ Error in final migration: \(error)")
            }
        }
    }
    func migrateOldLikes(userId: String, oldLikes: Set<String>) async throws {
        print("🔄 === MIGRATING OLD LIKES ===")
        
        let batch = db.batch()
        var batchCount = 0
        
        for postId in oldLikes {
            // 1. Add to new user location (likedPosts)
            let newUserLikeRef = db.collection("users").document(userId)
                .collection("likedPosts").document(postId)
            batch.setData([
                "postId": postId,
                "likedAt": Timestamp(date: Date()),
                "migratedFromOldFormat": true
            ], forDocument: newUserLikeRef)
            
            // 2. Add to post's likes subcollection
            let postLikeRef = db.collection("posts").document(postId)
                .collection("likes").document(userId)
            batch.setData([
                "userId": userId,
                "likedAt": Timestamp(date: Date()),
                "migratedFromOldFormat": true
            ], forDocument: postLikeRef)
            
            // 3. Delete from old location
            let oldLikeRef = db.collection("users").document(userId)
                .collection("likes").document(postId)
            batch.deleteDocument(oldLikeRef)
            
            batchCount += 3
            
            // Commit batch if getting close to limit
            if batchCount >= 450 {
                do {
                    try await batch.commit()
                    print("✅ Migrated batch of likes")
                    batchCount = 0
                } catch {
                    print("❌ Error migrating batch: \(error)")
                }
            }
        }
        
        // Commit remaining operations
        if batchCount > 0 {
            do {
                try await batch.commit()
                print("✅ Migration completed successfully")
            } catch {
                print("❌ Error in final migration batch: \(error)")
            }
        }
    }
    // ✅ Updated unlike method to be more defensive
    
    // MARK: - Bookmark Methods
    
    func bookmarkPost(postId: String, userId: String) async throws {
        let bookmarkRef = db.collection("users").document(userId).collection("bookmarks").document(postId)
        try await bookmarkRef.setData([
            "postId": postId,
            "bookmarkedAt": Timestamp(date: Date())
        ])
    }
    
    func unbookmarkPost(postId: String, userId: String) async throws {
        try await db.collection("users").document(userId).collection("bookmarks").document(postId).delete()
    }
    
    func getUserBookmarkedPosts(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId).collection("bookmarks").getDocuments()
        return Set(snapshot.documents.map { $0.documentID })
    }
    
    // MARK: - Community Management Methods
    
    func createCommunity(_ community: Community) async throws {
        let batch = db.batch()
        
        // Create community document
        let communityRef = db.collection("communities").document(community.id)
        batch.setData(community.toFirestore(), forDocument: communityRef)
        
        // Add creator as first member with admin role
        let memberRef = communityRef.collection("members").document(community.createdBy)
        batch.setData([
            "userId": community.createdBy,
            "role": "admin",
            "joinedAt": Timestamp(date: Date())
        ], forDocument: memberRef)
        
        // Update user's community list
        let userRef = db.collection("users").document(community.createdBy)
        batch.updateData([
            "communityIds": FieldValue.arrayUnion([community.id])
        ], forDocument: userRef)
        
        try await batch.commit()
    }
    
    func updateCommunity(_ community: Community) async throws {
        try await db.collection("communities").document(community.id).setData(community.toFirestore(), merge: true)
    }
    
    func deleteCommunity(communityId: String) async throws {
        let batch = db.batch()
        
        // Get all members
        let members = try await db.collection("communities").document(communityId)
            .collection("members").getDocuments()
        
        // Remove community from each member's list
        for member in members.documents {
            let userRef = db.collection("users").document(member.documentID)
            batch.updateData([
                "communityIds": FieldValue.arrayRemove([communityId])
            ], forDocument: userRef)
        }
        
        // Delete community
        batch.deleteDocument(db.collection("communities").document(communityId))
        
        try await batch.commit()
    }
    
    func getCommunities(limit: Int = 20) async throws -> [Community] {
        let snapshot = try await db.collection("communities")
            .whereField("isPrivate", isEqualTo: false)
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
        
        return communities.filter { community in
            community.name.lowercased().contains(query.lowercased()) ||
            community.description.lowercased().contains(query.lowercased())
        }
    }
    
    func joinCommunity(communityId: String, userId: String) async throws {
        let batch = db.batch()
        
        // Add member to community
        let memberRef = db.collection("communities").document(communityId)
            .collection("members").document(userId)
        batch.setData([
            "userId": userId,
            "role": "member",
            "joinedAt": Timestamp(date: Date())
        ], forDocument: memberRef)
        
        // Update community member count
        let communityRef = db.collection("communities").document(communityId)
        batch.updateData([
            "memberCount": FieldValue.increment(Int64(1))
        ], forDocument: communityRef)
        
        // Add community to user's list
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "communityIds": FieldValue.arrayUnion([communityId])
        ], forDocument: userRef)
        
        try await batch.commit()
    }
    
    func leaveCommunity(communityId: String, userId: String) async throws {
        let batch = db.batch()
        
        // Remove member from community
        let memberRef = db.collection("communities").document(communityId)
            .collection("members").document(userId)
        batch.deleteDocument(memberRef)
        
        // Update community member count
        let communityRef = db.collection("communities").document(communityId)
        batch.updateData([
            "memberCount": FieldValue.increment(Int64(-1))
        ], forDocument: communityRef)
        
        // Remove community from user's list
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
    
    // MARK: - Comment Methods
    
    func addComment(postId: String, content: String, authorId: String, authorUsername: String, parentCommentId: String? = nil) async throws {
        let batch = db.batch()
        
        let comment = Comment(
            postId: postId,
            content: content,
            authorId: authorId,
            authorUsername: authorUsername,
            parentCommentId: parentCommentId  // ✅ Add this
        )
        
        // Add comment
        let commentRef = db.collection("posts").document(postId)
            .collection("comments").document(comment.id)
        batch.setData(comment.toFirestore(), forDocument: commentRef)
        
        // Update comment count (only increment for top-level comments)
        if parentCommentId == nil {  // ✅ Add this condition
            let postRef = db.collection("posts").document(postId)
            batch.updateData(["commentsCount": FieldValue.increment(Int64(1))], forDocument: postRef)
        }
        
        try await batch.commit()
    }
    
    func getCommentsForPost(postId: String) async throws -> [Comment] {
        let snapshot = try await db.collection("posts").document(postId)
            .collection("comments")
            // .order(by: "createdAt", descending: false)  // ❌ Remove this line temporarily
            .getDocuments()
        
        let comments = snapshot.documents.compactMap { document in
            try? Comment.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        // ✅ Sort in memory instead
        return comments.sorted { $0.createdAt < $1.createdAt }
    }
    
    
    // MARK: - Comment Like Methods

    // MARK: - Comment Like Methods (add to FirebaseServices.swift)

    func likeComment(commentId: String, userId: String) async throws {
        print("💾 Saving comment like to Firebase...")
        
        let likeRef = db.collection("users").document(userId)
            .collection("commentLikes").document(commentId)
        
        try await likeRef.setData([
            "commentId": commentId,
            "likedAt": Timestamp(date: Date())
        ])
        
        print("✅ Comment like saved to Firebase")
    }

    func unlikeComment(commentId: String, userId: String) async throws {
        print("🗑️ Removing comment like from Firebase...")
        
        let likeRef = db.collection("users").document(userId)
            .collection("commentLikes").document(commentId)
        
        try await likeRef.delete()
        
        print("✅ Comment unlike saved to Firebase")
    }
    // Add this method to FirebaseServices.swift
    func getUserLikedComments(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId)
            .collection("commentLikes").getDocuments()
        
        return Set(snapshot.documents.map { $0.documentID })
    }
    func deleteComment(commentId: String, postId: String) async throws {
        let batch = db.batch()
        
        // Delete comment
        let commentRef = db.collection("posts").document(postId)
            .collection("comments").document(commentId)
        batch.deleteDocument(commentRef)
        
        // Update comment count
        let postRef = db.collection("posts").document(postId)
        batch.updateData(["commentsCount": FieldValue.increment(Int64(-1))], forDocument: postRef)
        
        try await batch.commit()
    }
    
    // MARK: - Messaging Methods
    
    func sendMessage(to recipientId: String, content: String, senderId: String) async throws {
        // Create or get conversation
        let conversationId = createConversationId(between: senderId, and: recipientId)
        
        let message = Message(senderId: senderId, recipientId: recipientId, content: content)
        
        let batch = db.batch()
        
        // Add message
        let messageRef = db.collection("messages").document(message.id.uuidString)
        batch.setData([
            "senderId": message.senderId,
            "recipientId": message.recipientId,
            "content": message.content,
            "timestamp": Timestamp(date: message.timestamp),
            "conversationId": conversationId,
            "isRead": false
        ], forDocument: messageRef)
        
        // Update or create conversation
        let conversationRef = db.collection("conversations").document(conversationId)
        batch.setData([
            "participants": [senderId, recipientId].sorted(),
            "lastMessage": content,
            "lastMessageTimestamp": Timestamp(date: Date()),
            "lastMessageSenderId": senderId,
            "updatedAt": Timestamp(date: Date())
        ], forDocument: conversationRef, merge: true)
        
        try await batch.commit()
    }
    
    func getConversations(userId: String) async throws -> [Conversation] {
        let snapshot = try await db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .order(by: "updatedAt", descending: true)
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
        
        let messages = snapshot.documents.compactMap { document -> Message? in
            let data = document.data()
            guard let senderId = data["senderId"] as? String,
                  let recipientId = data["recipientId"] as? String,
                  let content = data["content"] as? String,
                  let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                return nil
            }
            
            return Message(senderId: senderId, recipientId: recipientId, content: content)
        }
        
        return messages.reversed()
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
                
                let messages = documents.compactMap { document -> Message? in
                    let data = document.data()
                    guard let senderId = data["senderId"] as? String,
                          let recipientId = data["recipientId"] as? String,
                          let content = data["content"] as? String else {
                        return nil
                    }
                    
                    return Message(senderId: senderId, recipientId: recipientId, content: content)
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
    
    // MARK: - Report and Block Methods
    
    func reportPost(postId: String, reportedBy: String, reason: String) async throws {
        let batch = db.batch()
        
        // Add the report
        let report: [String: Any] = [
            "postId": postId,
            "reportedBy": reportedBy,
            "reason": reason,
            "timestamp": Timestamp(date: Date()),
            "status": "pending"
        ]
        
        let reportRef = db.collection("reports").document()
        batch.setData(report, forDocument: reportRef)
        
        // ✅ Track user's reported posts
        let userReportRef = db.collection("users").document(reportedBy)
            .collection("reportedPosts").document(postId)
        batch.setData([
            "postId": postId,
            "reportedAt": Timestamp(date: Date())
        ], forDocument: userReportRef)
        
        // ✅ Increment report count on the post
        let postRef = db.collection("posts").document(postId)
        batch.updateData(["reportCount": FieldValue.increment(Int64(1))], forDocument: postRef)
        
        try await batch.commit()
        
        // ✅ Check if post should be auto-hidden (3+ reports)
        try await checkPostReportCount(postId: postId)
    }

    private func checkPostReportCount(postId: String) async throws {
        let postDoc = try await db.collection("posts").document(postId).getDocument()
        let reportCount = postDoc.data()?["reportCount"] as? Int ?? 0
        
        print("📊 Post \(postId) has \(reportCount) reports")
        
        if reportCount >= 3 {
            // Auto-hide the post
            try await db.collection("posts").document(postId).updateData([
                "isHidden": true,
                "hiddenAt": Timestamp(date: Date()),
                "hiddenReason": "Multiple reports (\(reportCount) reports)"
            ])
            
            print("🚨 Auto-hidden post \(postId) due to \(reportCount) reports")
        }
    }
    
    func reportUser(userId: String, reportedBy: String, reason: String) async throws {
        let report: [String: Any] = [
            "userId": userId,
            "reportedBy": reportedBy,
            "reason": reason,
            "timestamp": Timestamp(date: Date()),
            "status": "pending"
        ]
        
        try await db.collection("reports").document().setData(report)
    }
    
    func blockUser(userId: String, blockedBy: String) async throws {
        let blockRef = db.collection("users").document(blockedBy)
            .collection("blockedUsers").document(userId)
        
        try await blockRef.setData([
            "userId": userId,
            "blockedAt": Timestamp(date: Date())
        ])
    }
    
    func unblockUser(userId: String, unblockedBy: String) async throws {
        try await db.collection("users").document(unblockedBy)
            .collection("blockedUsers").document(userId).delete()
    }
    
    func getUserBlockedUsers(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId)
            .collection("blockedUsers").getDocuments()
        
        return Set(snapshot.documents.map { $0.documentID })
    }
    
    func isUserBlocked(userId: String, by blockedBy: String) async throws -> Bool {
        let document = try await db.collection("users").document(blockedBy)
            .collection("blockedUsers").document(userId).getDocument()
        
        return document.exists
    }
    
    // MARK: - Market News Methods
    
    func cacheMarketNews(articles: [MarketNewsArticle]) async throws {
        let batch = db.batch()
        
        for article in articles {
            let ref = db.collection("marketNews").document(article.id)
            batch.setData(article.toFirestore(), forDocument: ref)
        }
        
        try await batch.commit()
    }
    
    func getCachedMarketNews() async throws -> [MarketNewsArticle] {
        let snapshot = try await db.collection("marketNews")
            .order(by: "publishedUtc", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? MarketNewsArticle.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func clearOldMarketNews() async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let snapshot = try await db.collection("marketNews")
            .whereField("cachedAt", isLessThan: Timestamp(date: cutoffDate))
            .getDocuments()
        
        let batch = db.batch()
        
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        try await batch.commit()
    }
    
    func searchMarketNews(query: String) async throws -> [MarketNewsArticle] {
        let snapshot = try await db.collection("marketNews")
            .order(by: "publishedUtc", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        let articles = snapshot.documents.compactMap { document in
            try? MarketNewsArticle.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        return articles.filter { article in
            article.title.lowercased().contains(query.lowercased()) ||
            (article.description ?? "").lowercased().contains(query.lowercased()) ||
            article.keywords.contains { $0.lowercased().contains(query.lowercased()) }
        }
    }
    
    // MARK: - Notification Methods
    
    func sendNotification(to userId: String, type: String, title: String, body: String, data: [String: Any] = [:]) async throws {
        let notification: [String: Any] = [
            "userId": userId,
            "type": type,
            "title": title,
            "body": body,
            "data": data,
            "isRead": false,
            "createdAt": Timestamp(date: Date())
        ]
        
        try await db.collection("notifications").document().setData(notification)
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
        let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        
        let snapshot = try await db.collection("marketNews")
            .whereField("cachedAt", isGreaterThan: Timestamp(date: oneWeekAgo))
            .getDocuments()
        
        let articles = snapshot.documents.compactMap { document in
            try? MarketNewsArticle.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        // Analyze keywords
        var keywordCounts: [String: Int] = [:]
        for article in articles {
            for keyword in article.keywords {
                keywordCounts[keyword, default: 0] += 1
            }
        }
        
        let topKeywords = keywordCounts.sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
        
        // Analyze sources
        var sourceCounts: [String: Int] = [:]
        for article in articles {
            if let source = article.source {
                sourceCounts[source, default: 0] += 1
            }
        }
        
        return NewsAnalytics(
            totalArticles: articles.count,
            topKeywords: topKeywords,
            sourceCounts: sourceCounts,
            lastUpdated: Date()
        )
    }
    
    func trackUserActivity(userId: String, action: String, details: [String: Any] = [:]) async throws {
        let activity: [String: Any] = [
            "userId": userId,
            "action": action,
            "details": details,
            "timestamp": Timestamp(date: Date())
        ]
        
        try await db.collection("userActivity").document().setData(activity)
    }
    
    
    // MARK: - Helper Methods
    
    private func createConversationId(between user1: String, and user2: String) -> String {
        let sorted = [user1, user2].sorted()
        return "\(sorted[0])_\(sorted[1])"
    }
    
    // MARK: - Cleanup
    
    func removeAllListeners() {
        for listener in listeners {
            listener.remove()
        }
        listeners.removeAll()
    }
    func getPopularUsers(limit: Int = 20) async throws -> [User] {
            let snapshot = try await db.collection("users")
                .order(by: "followersCount", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                try? User.fromFirestore(data: document.data(), id: document.documentID)
            }
        }
        
        /// Get recently joined users
        func getRecentUsers(limit: Int = 20) async throws -> [User] {
            let snapshot = try await db.collection("users")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                try? User.fromFirestore(data: document.data(), id: document.documentID)
            }
        }
        
        /// Get top performing traders based on profit/loss
        func getTopTraders(limit: Int = 20) async throws -> [User] {
            let snapshot = try await db.collection("users")
                .whereField("totalProfitLoss", isGreaterThan: 0)
                .order(by: "totalProfitLoss", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                try? User.fromFirestore(data: document.data(), id: document.documentID)
            }
        }
        
        /// Get users with high win rates
        func getHighWinRateTraders(limit: Int = 20) async throws -> [User] {
            let snapshot = try await db.collection("users")
                .whereField("winRate", isGreaterThan: 60.0)
                .order(by: "winRate", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                try? User.fromFirestore(data: document.data(), id: document.documentID)
            }
        }
        
        /// Get verified users
        func getVerifiedUsers(limit: Int = 20) async throws -> [User] {
            let snapshot = try await db.collection("users")
                .whereField("isVerified", isEqualTo: true)
                .order(by: "followersCount", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                try? User.fromFirestore(data: document.data(), id: document.documentID)
            }
        }
        
        /// Search users with enhanced filtering
        func searchUsersAdvanced(
            query: String,
            minFollowers: Int? = nil,
            isVerified: Bool? = nil,
            subscriptionTier: SubscriptionTier? = nil,
            limit: Int = 20
        ) async throws -> [User] {
            var queryBuilder = db.collection("users")
                .whereField("username", isGreaterThanOrEqualTo: query.lowercased())
                .whereField("username", isLessThan: query.lowercased() + "\u{f8ff}")
            
            if let minFollowers = minFollowers {
                queryBuilder = queryBuilder.whereField("followersCount", isGreaterThanOrEqualTo: minFollowers)
            }
            
            if let isVerified = isVerified {
                queryBuilder = queryBuilder.whereField("isVerified", isEqualTo: isVerified)
            }
            
            if let subscriptionTier = subscriptionTier {
                queryBuilder = queryBuilder.whereField("subscriptionTier", isEqualTo: subscriptionTier.rawValue)
            }
            
            let snapshot = try await queryBuilder
                .limit(to: limit)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                try? User.fromFirestore(data: document.data(), id: document.documentID)
            }
        }
        
        /// Get suggested users for a specific user (based on mutual follows, similar interests)
        func getSuggestedUsers(for userId: String, limit: Int = 20) async throws -> [User] {
            // Get users that the current user's followers also follow
            let followingSnapshot = try await db.collection("users").document(userId)
                .collection("following").limit(to: 10).getDocuments()
            
            var suggestedUserIds: Set<String> = []
            
            // For each user the current user follows, get who they follow
            for followingDoc in followingSnapshot.documents {
                let theirFollowingSnapshot = try await db.collection("users")
                    .document(followingDoc.documentID)
                    .collection("following")
                    .limit(to: 5)
                    .getDocuments()
                
                for theirFollowing in theirFollowingSnapshot.documents {
                    if theirFollowing.documentID != userId { // Don't suggest the user themselves
                        suggestedUserIds.insert(theirFollowing.documentID)
                    }
                }
            }
            
            // If we don't have enough suggestions, add popular users
            if suggestedUserIds.count < limit {
                let popularUsers = try await getPopularUsers(limit: limit - suggestedUserIds.count)
                for user in popularUsers {
                    if user.id != userId {
                        suggestedUserIds.insert(user.id)
                    }
                }
            }
            
            // Convert IDs to User objects
            let userIds = Array(suggestedUserIds.prefix(limit))
            var users: [User] = []
            
            for userId in userIds {
                if let user = try await getUserById(userId: userId) {
                    users.append(user)
                }
            }
            
            return users.sorted { $0.followersCount > $1.followersCount }
        }
    
    
    deinit {
        removeAllListeners()
    }
}

// MARK: - Supporting Types

enum FirestoreError: LocalizedError {
    case invalidData
    case documentNotFound
    case unauthorized
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .documentNotFound:
            return "Document not found"
        case .unauthorized:
            return "You don't have permission to perform this action"
        case .networkError:
            return "Network error. Please check your connection"
        }
    }
}

struct NewsAnalytics {
    let totalArticles: Int
    let topKeywords: [String]
    let sourceCounts: [String: Int]
    let lastUpdated: Date
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
    let parentCommentId: String?  // ✅ Add this for replies


    // Initializer for creating a new comment
    init(postId: String, content: String, authorId: String, authorUsername: String, parentCommentId: String? = nil) {
        self.id = UUID().uuidString
        self.postId = postId
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.createdAt = Date()
        self.likesCount = 0
        self.parentCommentId = parentCommentId  // ✅ Add this

    }

    // Initializer for loading from Firestore
    init(id: String, postId: String, content: String, authorId: String, authorUsername: String, createdAt: Date, likesCount: Int, parentCommentId: String? = nil) {
        self.id = id
        self.postId = postId
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.createdAt = createdAt
        self.likesCount = likesCount
        self.parentCommentId = parentCommentId  // ✅ Add this

    }

    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "postId": postId,
            "content": content,
            "authorId": authorId,
            "authorUsername": authorUsername,
            "createdAt": Timestamp(date: createdAt),
            "likesCount": likesCount
        ]
        
        // ✅ Only add parentCommentId if it exists
        if let parentCommentId = parentCommentId {
            data["parentCommentId"] = parentCommentId
        }
        
        return data
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
            likesCount: likesCount,
            parentCommentId: data["parentCommentId"] as? String  // ✅ Add this - it's optional
        )
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
              let lastMessageTimestamp = (data["lastMessageTimestamp"] as? Timestamp)?.dateValue(),
              let lastMessageSenderId = data["lastMessageSenderId"] as? String,
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            throw FirestoreError.invalidData
        }
        
        return Conversation(
            id: id,
            participants: participants,
            lastMessage: lastMessage,
            lastMessageTimestamp: lastMessageTimestamp,
            lastMessageSenderId: lastMessageSenderId,
            updatedAt: updatedAt
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
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            throw FirestoreError.invalidData
        }
        
        return UserNotification(
            id: id,
            userId: userId,
            type: type,
            title: title,
            body: body,
            data: data["data"] as? [String: Any] ?? [:],
            isRead: isRead,
            createdAt: createdAt
        )
    }
}

extension FirebaseAuthService {
    
    // MARK: - User Discovery Wrapper Methods
    
    func getPopularUsers(limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getPopularUsers(limit: limit)
    }
    
    func getRecentUsers(limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getRecentUsers(limit: limit)
    }
    
    func getTopTraders(limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getTopTraders(limit: limit)
    }
    
    func getHighWinRateTraders(limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getHighWinRateTraders(limit: limit)
    }
    
    func getVerifiedUsers(limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getVerifiedUsers(limit: limit)
    }
    
    func searchUsersAdvanced(
        query: String,
        minFollowers: Int? = nil,
        isVerified: Bool? = nil,
        subscriptionTier: SubscriptionTier? = nil,
        limit: Int = 20
    ) async throws -> [User] {
        return try await FirebaseServices.shared.searchUsersAdvanced(
            query: query,
            minFollowers: minFollowers,
            isVerified: isVerified,
            subscriptionTier: subscriptionTier,
            limit: limit
        )
    }
    
    func getSuggestedUsers(for userId: String, limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getSuggestedUsers(for: userId, limit: limit)
    }
}
