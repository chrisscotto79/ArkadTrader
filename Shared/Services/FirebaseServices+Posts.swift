// File: Shared/Services/FirebaseServices+Posts.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

extension FirebaseServices {
    // MARK: - Post Management
    
    func createPost(_ post: Post) async throws {
        try await db.collection("posts").document(post.id).setData(post.toFirestore())
    }
    
    func updatePost(_ post: Post) async throws {
        try await db.collection("posts").document(post.id).setData(post.toFirestore(), merge: true)
    }
    
    func deletePost(postId: String) async throws {
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
    
    func searchPosts(query: String, limit: Int = 20) async throws -> [Post] {
        let firebaseServices = FirebaseServices.shared
        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }
        
        // Note: Firestore doesn't support full-text search natively
        // This is a basic implementation - for production, consider using Algolia or similar
        
        let snapshot = try await firebaseServices.db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 100) // Get more posts to filter client-side
            .getDocuments()
        
        let posts = snapshot.documents.compactMap { document in
            try? Post.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        // Filter posts that contain the search query
        let filteredPosts = posts.filter { post in
            post.content.lowercased().contains(searchQuery) ||
            post.authorUsername.lowercased().contains(searchQuery)
        }
        
        return Array(filteredPosts.prefix(limit))
    }
    
    // MARK: - Like/Unlike Methods
    
    func likePost(postId: String, userId: String) async throws {
        print("💾 === LIKING POST (ROBUST VERSION) ===")
        print("📝 Post ID: \(postId)")
        print("👤 User ID: \(userId)")
        
        // Check if user has already liked this post
        let isAlreadyLiked = try await checkIfUserLikedPost(postId: postId, userId: userId)
        if isAlreadyLiked {
            print("⚠️ User has already liked this post - skipping")
            return
        }
        
        let batch = db.batch()
        
        // 1. Add like document in POST's likes subcollection
        let postLikeRef = db.collection("posts").document(postId).collection("likes").document(userId)
        batch.setData([
            "userId": userId,
            "likedAt": Timestamp(date: Date())
        ], forDocument: postLikeRef)
        print("✅ Will write to: posts/\(postId)/likes/\(userId)")
        
        // 2. Add like document in USER's likedPosts subcollection
        let userLikeRef = db.collection("users").document(userId).collection("likedPosts").document(postId)
        batch.setData([
            "postId": postId,
            "likedAt": Timestamp(date: Date())
        ], forDocument: userLikeRef)
        print("✅ Will write to: users/\(userId)/likedPosts/\(postId)")
        
        // 3. Update post's like count
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
        
        // Check what like documents actually exist before deleting
        let likeLocations = try await checkLikeLocations(postId: postId, userId: userId)
        
        if likeLocations.isEmpty {
            print("⚠️ No like documents found - user hasn't liked this post")
            return
        }
        
        print("📍 Found likes in locations: \(likeLocations)")
        
        let batch = db.batch()
        var shouldDecrementCount = false
        
        // Remove from POST's likes collection if it exists there
        if likeLocations.contains("post") {
            let postLikeRef = db.collection("posts").document(postId).collection("likes").document(userId)
            batch.deleteDocument(postLikeRef)
            shouldDecrementCount = true
            print("✅ Will delete: posts/\(postId)/likes/\(userId)")
        }
        
        // Remove from USER's new likes collection if it exists there
        if likeLocations.contains("userNew") {
            let userNewLikeRef = db.collection("users").document(userId).collection("likedPosts").document(postId)
            batch.deleteDocument(userNewLikeRef)
            if !shouldDecrementCount {
                shouldDecrementCount = true
            }
            print("✅ Will delete: users/\(userId)/likedPosts/\(postId)")
        }
        
        // Remove from USER's old likes collection if it exists there (cleanup)
        if likeLocations.contains("userOld") {
            let userOldLikeRef = db.collection("users").document(userId).collection("likes").document(postId)
            batch.deleteDocument(userOldLikeRef)
            if !shouldDecrementCount {
                shouldDecrementCount = true
            }
            print("✅ Will delete OLD: users/\(userId)/likes/\(postId)")
        }
        
        // Only decrement count once, regardless of how many locations had the like
        if shouldDecrementCount {
            let postRef = db.collection("posts").document(postId)
            batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: postRef)
            print("✅ Will decrement likesCount on post")
        }
        
        try await batch.commit()
        print("✅ Unlike completed successfully!")
    }
    
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        print("🔄 Starting profile image upload for user: \(userId)")
        
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ Failed to convert image to data")
            throw FirestoreError.invalidData
        }
        
        print("📊 Image data size: \(imageData.count) bytes")
        
        // Simple file naming convention
        let fileName = "\(userId).jpg"
        let storageRef = Storage.storage().reference().child("profile_images").child(fileName)
        
        print("🔍 Upload path: profile_images/\(fileName)")
        
        do {
            print("🔄 Uploading image to Firebase Storage...")
            
            // Upload the image data using proper async/await pattern
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                storageRef.putData(imageData, metadata: nil) { metadata, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let metadata = metadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: FirestoreError.uploadFailed)
                    }
                }
            }
            print("✅ Image uploaded successfully")
            print("📍 Upload path confirmed: \(storageRef.fullPath)")
            
            // Get the download URL
            let downloadURL = try await storageRef.downloadURL()
            print("✅ Download URL obtained: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
            
        } catch let storageError {
            print("❌ Storage operation failed: \(storageError)")
            
            // If getting download URL fails, try constructing a public URL as fallback
            if storageError.localizedDescription.contains("download") ||
               storageError.localizedDescription.contains("url") {
                print("🔄 Attempting fallback with constructed public URL")
                let publicURL = "https://firebasestorage.googleapis.com/v0/b/arkad-ios-app.firebasestorage.app/o/profile_images%2F\(fileName)?alt=media"
                print("🔄 Constructed public URL: \(publicURL)")
                return publicURL
            }
            
            // For any other errors, rethrow as FirestoreError
            print("❌ Profile image upload failed: \(storageError)")
            throw FirestoreError.uploadFailed
        }
    }


    func deleteProfileImage(imageUrl: String) async throws {
        print("🔄 Deleting profile image: \(imageUrl)")
        
        guard let url = URL(string: imageUrl) else {
            print("❌ Invalid image URL")
            return
        }
        
        // Extract the file path from the URL
        let pathComponents = url.pathComponents
        if let index = pathComponents.firstIndex(of: "profile_images"),
           index + 1 < pathComponents.count {
            let fileName = pathComponents[index + 1]
            let storageRef = Storage.storage().reference().child("profile_images/\(fileName)")
            
            do {
                try await storageRef.delete()
                print("✅ Profile image deleted successfully")
            } catch {
                print("⚠️ Failed to delete profile image: \(error)")
                // Don't throw error here - we still want to update the user record
            }
        }
    }
    func getUserLikedPosts(userId: String) async throws -> Set<String> {
        print("🔍 === LOADING USER LIKED POSTS (ROBUST VERSION) ===")
        print("👤 User ID: \(userId)")
        
        var allLikedPosts: Set<String> = []
        
        // Load from NEW location (likedPosts)
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
        
        // Load from OLD location (likes) - but don't duplicate
        do {
            print("🔄 Checking OLD location: users/\(userId)/likes")
            let oldLikesSnapshot = try await db.collection("users").document(userId)
                .collection("likes").getDocuments()
            
            let oldLikes = Set(oldLikesSnapshot.documents.map { $0.documentID })
            
            // Only add old likes that aren't already in new location
            let newOldLikes = oldLikes.subtracting(allLikedPosts)
            allLikedPosts.formUnion(newOldLikes)
            
            print("✅ Found \(oldLikes.count) total in OLD location, \(newOldLikes.count) new ones")
            
            // Auto-migrate old likes if found
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
    
    
    // MARK: - Like Helper Methods
    
    func checkIfUserLikedPost(postId: String, userId: String) async throws -> Bool {
        // Check both locations
        let postLikeDoc = try await db.collection("posts").document(postId)
            .collection("likes").document(userId).getDocument()
        
        let userNewLikeDoc = try await db.collection("users").document(userId)
            .collection("likedPosts").document(postId).getDocument()
        
        let userOldLikeDoc = try await db.collection("users").document(userId)
            .collection("likes").document(postId).getDocument()
        
        return postLikeDoc.exists || userNewLikeDoc.exists || userOldLikeDoc.exists
    }
    
    func checkLikeLocations(postId: String, userId: String) async throws -> Set<String> {
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
    
    func migrateSpecificLikes(userId: String, postIds: Set<String>) async {
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
    
    // MARK: - Comment Methods
    
    func addComment(postId: String, content: String, authorId: String, authorUsername: String, parentCommentId: String? = nil) async throws {
        let batch = db.batch()
        
        let comment = Comment(
            postId: postId,
            content: content,
            authorId: authorId,
            authorUsername: authorUsername,
            parentCommentId: parentCommentId
        )
        
        // Add comment
        let commentRef = db.collection("posts").document(postId)
            .collection("comments").document(comment.id)
        batch.setData(comment.toFirestore(), forDocument: commentRef)
        
        // Update comment count (only increment for top-level comments)
        if parentCommentId == nil {
            let postRef = db.collection("posts").document(postId)
            batch.updateData(["commentsCount": FieldValue.increment(Int64(1))], forDocument: postRef)
        }
        
        try await batch.commit()
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
    
    func getCommentsForPost(postId: String) async throws -> [Comment] {
        let snapshot = try await db.collection("posts").document(postId)
            .collection("comments")
            .getDocuments()
        
        let comments = snapshot.documents.compactMap { document in
            try? Comment.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        // Sort in memory instead
        return comments.sorted { $0.createdAt < $1.createdAt }
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
    
    // MARK: - Comment Like Methods
    
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
    
    func getUserLikedComments(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId)
            .collection("commentLikes").getDocuments()
        
        return Set(snapshot.documents.map { $0.documentID })
    }
}
