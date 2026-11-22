// File: Shared/Services/FirebaseServices+Social.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

extension FirebaseServices {
    // MARK: - Following/Followers
    
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
    
    func getFollowingPosts(userId: String, limit: Int = 20) async throws -> [Post] {
        let followingSnapshot = try await db.collection("users")
            .document(userId)
            .collection("following")
            .getDocuments()
        
        guard !followingSnapshot.documents.isEmpty else { return [] }
        
        let followingIds = followingSnapshot.documents.map { $0.documentID }
        
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
        let followingSnapshot = try await db.collection("users")
            .document(userId)
            .collection("following")
            .getDocuments()
        
        guard !followingSnapshot.documents.isEmpty else { return [] }
        
        let followingIds = followingSnapshot.documents.map { $0.documentID }
        
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
    
    func getFollowingActivity(userId: String, limit: Int = 50) async throws -> [ActivityItem] {
        let followingSnapshot = try await db.collection("users")
            .document(userId)
            .collection("following")
            .getDocuments()
        
        guard !followingSnapshot.documents.isEmpty else { return [] }
        
        let followingIds = followingSnapshot.documents.map { $0.documentID }
        
        let activitySnapshot = try await db.collection("activity")
            .whereField("userId", in: followingIds)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return activitySnapshot.documents.compactMap { document in
            try? ActivityItem.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    

    // MARK: - Activity Methods
    
    func createActivity(_ activity: ActivityItem) async throws {
        try await db.collection("activity").document(activity.id).setData(activity.toFirestore())
    }
}
