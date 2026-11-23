// File: Shared/Services/FirebaseServices+Users.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

extension FirebaseServices {
    // MARK: - User Management
    
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
    
    func getUserByUsername(_ username: String) async throws -> User? {
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username.lowercased())
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first else { return nil }
        return try User.fromFirestore(data: document.data(), id: document.documentID)
    }
    
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let user = try await getUserByUsername(username)
        return user == nil
    }
    
    func searchUsers(query: String, limit: Int = 20) async throws -> [User] {
        let snapshot = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query.lowercased())
            .whereField("username", isLessThan: query.lowercased() + "\u{f8ff}")
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? User.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
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
    
    func updateUserStartingCapital(userId: String, startingCapital: Double) async throws {
        try await db.collection("users").document(userId).updateData([
            "startingCapital": startingCapital,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    func getUserStats(userId: String) async throws -> UserStats {
        let user = try await getUserById(userId: userId)
        
        let followersSnapshot = try await db.collection("users").document(userId)
            .collection("followers").getDocuments()
        
        let followingSnapshot = try await db.collection("users").document(userId)
            .collection("following").getDocuments()
        
        let postsSnapshot = try await db.collection("posts")
            .whereField("authorId", isEqualTo: userId)
            .getDocuments()
        
        let tradesSnapshot = try await db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        return UserStats(
            followersCount: followersSnapshot.count,
            followingCount: followingSnapshot.count,
            postsCount: postsSnapshot.count,
            tradesCount: tradesSnapshot.count,
            joinDate: user?.createdAt ?? Date()  // or whatever the actual property name is
        )
    }
    // Reaction to a message

    // MARK: - User Discovery
    
    func getPopularUsers(limit: Int = 20) async throws -> [User] {
        let snapshot = try await db.collection("users")
            .order(by: "followersCount", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? User.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func getRecentUsers(limit: Int = 20) async throws -> [User] {
        let snapshot = try await db.collection("users")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? User.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
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
                if theirFollowing.documentID != userId {
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
        
        // Fetch the actual user objects
        let userIds = Array(suggestedUserIds.prefix(limit))
        guard !userIds.isEmpty else { return [] }
        
        let usersSnapshot = try await db.collection("users")
            .whereField(FieldPath.documentID(), in: userIds)
            .getDocuments()
        
        return usersSnapshot.documents.compactMap { document in
            try? User.fromFirestore(data: document.data(), id: document.documentID)
        }
    }

    // MARK: - Account deletion (free mode)

    /// `users/{uid}` subcollections removed when an account is deleted. The first nine are the
    /// ones in docs/backend-contracts.md, section 0; the rest are older per-user lists the app
    /// also writes (likes, bookmarks, comment likes).
    static let accountSubcollections = [
        "watchlist", "priceAlerts", "learnProgress", "callouts", "fcmTokens",
        "following", "followers", "blockedUsers", "reportedPosts",
        "likedPosts", "likes", "bookmarks", "commentLikes", "communityLessonProgress"
    ]

    /// Free mode (docs/backend-contracts.md, section 0): removes what the user created, before
    /// FirebaseAuthService deletes `users/{uid}`. Trades are removed afterwards, by
    /// `deleteAccountTrades`. Best-effort: each step is wrapped so one failure doesn't stop
    /// the rest. Community chat messages are left as they are.
    ///
    /// Runs while `users/{uid}` still exists: unfollowing and leaving update its counts and
    /// `communityIds`, and those updates fail on a deleted document.
    func deleteAccountData(userId: String) async {
        let profile = try? await getUserById(userId: userId)

        // Posts, with their comments and likes
        await bestEffort("posts") {
            let snapshot = try await db.collection("posts")
                .whereField("authorId", isEqualTo: userId)
                .getDocuments()
            for document in snapshot.documents {
                do {
                    try await deletePost(postId: document.documentID)
                } catch {
                    // The comments or likes couldn't all be removed; remove the post itself.
                    try? await document.reference.delete()
                }
            }
        }

        // Follows in both directions, through unfollow so everyone's counts stay right
        await bestEffort("following") {
            for followedId in try await getUserFollowing(userId: userId) {
                try? await unfollowUser(userId: followedId, followerId: userId)
            }
        }
        await bestEffort("followers") {
            for followerId in try await getUserFollowers(userId: userId) {
                try? await unfollowUser(userId: userId, followerId: followerId)
            }
        }

        // Communities: leave the ones you joined, delete the ones you own
        var ownedIds: [String] = []
        await bestEffort("owned communities") {
            ownedIds = try await db.collection("communities")
                .whereField("createdBy", isEqualTo: userId)
                .getDocuments()
                .documents.map(\.documentID)
        }
        for communityId in (profile?.communityIds ?? []) where !ownedIds.contains(communityId) {
            // The community leaderboard entry first: the rules allow it only while a member
            await bestEffort("community \(communityId) traderStats") {
                try await db.collection("communities").document(communityId)
                    .collection("traderStats").document(userId)
                    .delete()
            }
            await bestEffort("leave community \(communityId)") {
                try await leaveCommunity(communityId: communityId, userId: userId)
            }
        }
        for communityId in ownedIds {
            // Its photos first (images/community_*_{cid}), while the community still exists
            await bestEffort("community \(communityId) avatar image") {
                try await ImageStore.shared.deleteImage(id: ImageStore.communityAvatarId(communityId: communityId))
            }
            await bestEffort("community \(communityId) banner image") {
                try await ImageStore.shared.deleteImage(id: ImageStore.communityBannerId(communityId: communityId))
            }
            await bestEffort("delete community \(communityId)") {
                try await deleteCommunity(communityId: communityId)
            }
        }

        // Everything under users/{uid}
        let userRef = db.collection("users").document(userId)
        for name in Self.accountSubcollections {
            await bestEffort("users/\(userId)/\(name)") {
                let snapshot = try await userRef.collection(name).getDocuments()
                try await deleteDocuments(snapshot.documents.map(\.reference))
            }
        }

        // Track record
        await bestEffort("traderStats") {
            try await db.collection("traderStats").document(userId).delete()
        }

        // Your own inbox
        await bestEffort("notifications") {
            let snapshot = try await db.collection("notifications")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            try await deleteDocuments(snapshot.documents.map(\.reference))
        }

        // Profile photo in Firestore (images/avatar_{uid})
        await bestEffort("profile image") {
            try await ImageStore.shared.deleteImage(id: ImageStore.avatarId(userId: userId))
        }

        // Legacy profile photo in Cloud Storage, at the path uploadProfileImage used. Only when
        // Storage is available; on the free plan the request would just fail.
        if AppConfig.mediaUploadsEnabled, let url = profile?.profileImageUrl, ImageStore.imageId(from: url) == nil {
            await bestEffort("legacy profile image") {
                try await Storage.storage().reference()
                    .child("profile_images").child("\(userId).jpg")
                    .delete()
            }
        }
    }

    /// Free mode: removes the user's trades. Call after `users/{uid}` is deleted: the rules
    /// only let price-checked trades be deleted later than 15 minutes after logging once the
    /// profile is gone. Best-effort, one trade at a time so one refusal doesn't block the rest.
    func deleteAccountTrades(userId: String) async {
        await bestEffort("trades") {
            let snapshot = try await db.collection("trades")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            for document in snapshot.documents {
                try? await document.reference.delete()
            }
        }
    }

    /// Deletes documents in batches of 450.
    private func deleteDocuments(_ references: [DocumentReference]) async throws {
        for chunk in references.chunked(into: 450) {
            let batch = db.batch()
            for reference in chunk {
                batch.deleteDocument(reference)
            }
            try await batch.commit()
        }
    }

    private func bestEffort(_ step: String, _ work: () async throws -> Void) async {
        do {
            try await work()
        } catch {
            print("⚠️ Account deletion: \(step) failed: \(error.localizedDescription)")
        }
    }
}
