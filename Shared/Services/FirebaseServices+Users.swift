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
}
