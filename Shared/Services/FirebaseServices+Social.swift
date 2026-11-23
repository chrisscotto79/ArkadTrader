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
            "followedAt": FieldValue.serverTimestamp()
        ], forDocument: followingRef)
        
        // Add to user's followers subcollection
        let followerRef = db.collection("users").document(userId).collection("followers").document(followerId)
        batch.setData([
            "userId": followerId,
            "followedAt": FieldValue.serverTimestamp()
        ], forDocument: followerRef)
        
        // Update counts
        let userRef = db.collection("users").document(userId)
        batch.updateData(["followersCount": FieldValue.increment(Int64(1))], forDocument: userRef)
        
        let followerUserRef = db.collection("users").document(followerId)
        // lastFollowChange lets the rules pair the count change with the following doc.
        batch.updateData([
            "followingCount": FieldValue.increment(Int64(1)),
            "lastFollowChange": userId
        ], forDocument: followerUserRef)
        
        try await batch.commit()
        notifyFollowed(userId: userId, followerId: followerId)
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
        // lastFollowChange lets the rules pair the count change with the following doc.
        batch.updateData([
            "followingCount": FieldValue.increment(Int64(-1)),
            "lastFollowChange": userId
        ], forDocument: followerUserRef)
        
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
    
    // MARK: - Following feed
    //
    // Firestore's `in` filter takes at most 30 values, so the ids are read once and each
    // query runs per group of 30; the groups' results are merged, sorted and trimmed.
    // Following more than `followingFeedMaxPeople` people: the most recently followed count.

    /// Upper bound on people the Following feed reads from (10 groups of 30), for the free plan.
    static let followingFeedMaxPeople = 300

    /// The ids of people `userId` follows, most recently followed first.
    func followingIdsForFeed(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("following")
            .getDocuments()
        return snapshot.documents
            .sorted {
                let a = ($0.data()["followedAt"] as? Timestamp)?.dateValue() ?? .distantPast
                let b = ($1.data()["followedAt"] as? Timestamp)?.dateValue() ?? .distantPast
                return a > b
            }
            .prefix(Self.followingFeedMaxPeople)
            .map(\.documentID)
    }

    /// Runs `query` for each group of 30 ids. Throws only when every group failed.
    private func perGroup<T>(_ ids: [String],
                             _ query: @escaping ([String]) async throws -> [T]) async throws -> [T] {
        guard !ids.isEmpty else { return [] }
        let groups = ids.chunked(into: 30)
        var results: [T] = []
        var failures = 0
        var lastError: Error?
        await withTaskGroup(of: Result<[T], Error>.self) { taskGroup in
            for group in groups {
                taskGroup.addTask {
                    do { return .success(try await query(group)) } catch { return .failure(error) }
                }
            }
            for await result in taskGroup {
                switch result {
                case .success(let items): results += items
                case .failure(let error):
                    failures += 1
                    lastError = error
                }
            }
        }
        if failures == groups.count, let lastError { throw lastError }
        return results
    }

    func getFollowingPosts(followingIds: [String], limit: Int = 20) async throws -> [Post] {
        let posts: [Post] = try await perGroup(followingIds) { group in
            let snapshot = try await self.db.collection("posts")
                .whereField("authorId", in: group)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.compactMap(Post.fromDocument)
        }
        return Array(posts.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    func getFollowingTrades(followingIds: [String], limit: Int = 20) async throws -> [Trade] {
        let trades: [Trade] = try await perGroup(followingIds) { group in
            let snapshot = try await self.db.collection("trades")
                .whereField("userId", in: group)
                .whereField("isPublic", isEqualTo: true)
                .order(by: "entryDate", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.compactMap { document in
                try? Trade.fromFirestore(data: document.data(with: .estimate), id: document.documentID)
            }
        }
        return Array(trades.sorted { $0.entryDate > $1.entryDate }.prefix(limit))
    }

    func getFollowingActivity(followingIds: [String], limit: Int = 50) async throws -> [ActivityItem] {
        let items: [ActivityItem] = try await perGroup(followingIds) { group in
            let snapshot = try await self.db.collection("activity")
                .whereField("userId", in: group)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.compactMap { document in
                try? ActivityItem.fromFirestore(data: document.data(with: .estimate), id: document.documentID)
            }
        }
        return Array(items.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    // Older entry points (FirebaseAuthService wrappers): read the ids, then the posts.
    func getFollowingPosts(userId: String, limit: Int = 20) async throws -> [Post] {
        try await getFollowingPosts(followingIds: followingIdsForFeed(userId: userId), limit: limit)
    }

    func getFollowingTrades(userId: String, limit: Int = 20) async throws -> [Trade] {
        try await getFollowingTrades(followingIds: followingIdsForFeed(userId: userId), limit: limit)
    }

    func getFollowingActivity(userId: String, limit: Int = 50) async throws -> [ActivityItem] {
        try await getFollowingActivity(followingIds: followingIdsForFeed(userId: userId), limit: limit)
    }

    // MARK: - Activity Methods
    
    func createActivity(_ activity: ActivityItem) async throws {
        try await db.collection("activity").document(activity.id).setData(activity.toFirestore())
    }
}
