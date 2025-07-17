//
//  FirebaseAuthService+HomeExtensions.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/17/25.
//

// File: Core/Services/FirebaseAuthService+HomeExtensions.swift
// Firebase service extensions for all home functionality

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

extension FirebaseAuthService {
    
    // MARK: - Firestore Collections
    private var postsCollection: CollectionReference {
        db.collection("posts")
    }
    
    private var likesCollection: CollectionReference {
        db.collection("likes")
    }
    
    private var bookmarksCollection: CollectionReference {
        db.collection("bookmarks")
    }
    
    private var followsCollection: CollectionReference {
        db.collection("follows")
    }
    
    private var commentsCollection: CollectionReference {
        db.collection("comments")
    }
    
    private var reportsCollection: CollectionReference {
        db.collection("reports")
    }
    
    private var notificationsCollection: CollectionReference {
        db.collection("notifications")
    }
    
    private var activitiesCollection: CollectionReference {
        db.collection("activities")
    }
    
    private var viewsCollection: CollectionReference {
        db.collection("post_views")
    }
    
    private var sharesCollection: CollectionReference {
        db.collection("shares")
    }
    
    // MARK: - Posts Management
    
    /// Fetch all posts with pagination support
    func getFeedPosts(page: Int = 0, limit: Int = 20) async throws -> [Post] {
        do {
            let query = postsCollection
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
            
            // TODO: Implement proper pagination with lastDocument
            // if page > 0 {
            //     query = query.start(afterDocument: lastDocument)
            // }
            
            let snapshot = try await query.getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: Post.self)
            }
        } catch {
            print("Error fetching feed posts: \(error)")
            throw AuthError.networkError("Failed to fetch posts: \(error.localizedDescription)")
        }
    }
    
    /// Fetch posts from users that current user follows
    func getFollowingPosts(userId: String, page: Int = 0, limit: Int = 20) async throws -> [Post] {
        do {
            // First get the list of users that current user follows
            let followingUserIds = try await getUserFollowing(userId: userId)
            
            if followingUserIds.isEmpty {
                return []
            }
            
            // Fetch posts from followed users
            let snapshot = try await postsCollection
                .whereField("authorId", in: followingUserIds)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: Post.self)
            }
        } catch {
            print("Error fetching following posts: \(error)")
            throw AuthError.networkError("Failed to fetch following posts: \(error.localizedDescription)")
        }
    }
    
    /// Create a new post
    func createPost(post: Post) async throws {
        do {
            try postsCollection.document(post.id).setData(from: post)
            print("✅ Post created successfully: \(post.id)")
        } catch {
            print("Error creating post: \(error)")
            throw AuthError.networkError("Failed to create post: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Like Management
    
    /// Like a post
    func likePost(postId: String, userId: String) async throws {
        let batch = db.batch()
        
        do {
            // Add like document
            let likeData: [String: Any] = [
                "postId": postId,
                "userId": userId,
                "createdAt": Timestamp()
            ]
            let likeRef = likesCollection.document("\(userId)_\(postId)")
            batch.setData(likeData, forDocument: likeRef)
            
            // Increment post likes count
            let postRef = postsCollection.document(postId)
            batch.updateData(["likesCount": FieldValue.increment(Int64(1))], forDocument: postRef)
            
            try await batch.commit()
            print("✅ Post liked successfully: \(postId)")
        } catch {
            print("Error liking post: \(error)")
            throw AuthError.networkError("Failed to like post: \(error.localizedDescription)")
        }
    }
    
    /// Unlike a post
    func unlikePost(postId: String, userId: String) async throws {
        let batch = db.batch()
        
        do {
            // Remove like document
            let likeRef = likesCollection.document("\(userId)_\(postId)")
            batch.deleteDocument(likeRef)
            
            // Decrement post likes count
            let postRef = postsCollection.document(postId)
            batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: postRef)
            
            try await batch.commit()
            print("✅ Post unliked successfully: \(postId)")
        } catch {
            print("Error unliking post: \(error)")
            throw AuthError.networkError("Failed to unlike post: \(error.localizedDescription)")
        }
    }
    
    /// Get all post IDs that user has liked
    func getUserLikedPosts(userId: String) async throws -> Set<String> {
        do {
            let snapshot = try await likesCollection
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let postIds = snapshot.documents.compactMap { document in
                document.data()["postId"] as? String
            }
            
            return Set(postIds)
        } catch {
            print("Error getting liked posts: \(error)")
            throw AuthError.networkError("Failed to get liked posts: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Bookmark Management
    
    /// Bookmark a post
    func bookmarkPost(postId: String, userId: String) async throws {
        do {
            let bookmarkData: [String: Any] = [
                "postId": postId,
                "userId": userId,
                "createdAt": Timestamp()
            ]
            
            try await bookmarksCollection.document("\(userId)_\(postId)").setData(bookmarkData)
            print("✅ Post bookmarked successfully: \(postId)")
        } catch {
            print("Error bookmarking post: \(error)")
            throw AuthError.networkError("Failed to bookmark post: \(error.localizedDescription)")
        }
    }
    
    /// Remove bookmark from a post
    func unbookmarkPost(postId: String, userId: String) async throws {
        do {
            try await bookmarksCollection.document("\(userId)_\(postId)").delete()
            print("✅ Post unbookmarked successfully: \(postId)")
        } catch {
            print("Error unbookmarking post: \(error)")
            throw AuthError.networkError("Failed to unbookmark post: \(error.localizedDescription)")
        }
    }
    
    /// Get all post IDs that user has bookmarked
    func getUserBookmarkedPosts(userId: String) async throws -> Set<String> {
        do {
            let snapshot = try await bookmarksCollection
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let postIds = snapshot.documents.compactMap { document in
                document.data()["postId"] as? String
            }
            
            return Set(postIds)
        } catch {
            print("Error getting bookmarked posts: \(error)")
            throw AuthError.networkError("Failed to get bookmarked posts: \(error.localizedDescription)")
        }
    }
    
    /// Get saved posts for user
    func getSavedPosts(userId: String) async throws -> [Post] {
        do {
            // Get bookmarked post IDs
            let bookmarkedPostIds = try await getUserBookmarkedPosts(userId: userId)
            
            if bookmarkedPostIds.isEmpty {
                return []
            }
            
            // Fetch the actual posts
            let snapshot = try await postsCollection
                .whereField("id", in: Array(bookmarkedPostIds))
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: Post.self)
            }
        } catch {
            print("Error getting saved posts: \(error)")
            throw AuthError.networkError("Failed to get saved posts: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Share Management
    
    /// Share a post
    func sharePost(postId: String, userId: String, shareType: String) async throws {
        let batch = db.batch()
        
        do {
            // Add share document
            let shareData: [String: Any] = [
                "postId": postId,
                "userId": userId,
                "shareType": shareType,
                "createdAt": Timestamp()
            ]
            let shareRef = sharesCollection.document()
            batch.setData(shareData, forDocument: shareRef)
            
            // Increment post shares count
            let postRef = postsCollection.document(postId)
            batch.updateData(["sharesCount": FieldValue.increment(Int64(1))], forDocument: postRef)
            
            try await batch.commit()
            print("✅ Post shared successfully: \(postId)")
        } catch {
            print("Error sharing post: \(error)")
            throw AuthError.networkError("Failed to share post: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Following Management
    
    /// Get list of user IDs that the current user follows
    func getUserFollowing(userId: String) async throws -> [String] {
        do {
            let snapshot = try await followsCollection
                .whereField("followerId", isEqualTo: userId)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                document.data()["followingId"] as? String
            }
        } catch {
            print("Error getting following list: \(error)")
            throw AuthError.networkError("Failed to get following list: \(error.localizedDescription)")
        }
    }
    
    /// Follow a user
    func followUser(followerId: String, followingId: String) async throws {
        do {
            let followData: [String: Any] = [
                "followerId": followerId,
                "followingId": followingId,
                "createdAt": Timestamp()
            ]
            
            try await followsCollection.document("\(followerId)_\(followingId)").setData(followData)
            print("✅ User followed successfully: \(followingId)")
        } catch {
            print("Error following user: \(error)")
            throw AuthError.networkError("Failed to follow user: \(error.localizedDescription)")
        }
    }
    
    /// Unfollow a user
    func unfollowUser(followerId: String, followingId: String) async throws {
        do {
            try await followsCollection.document("\(followerId)_\(followingId)").delete()
            print("✅ User unfollowed successfully: \(followingId)")
        } catch {
            print("Error unfollowing user: \(error)")
            throw AuthError.networkError("Failed to unfollow user: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Comments Management
    
    /// Get comments for a specific post
    func getPostComments(postId: String, sortBy: CommentSortOption = .recent) async throws -> [Comment] {
        do {
            var query = commentsCollection
                .whereField("postId", isEqualTo: postId)
            
            // Apply sorting
            switch sortBy {
            case .recent:
                query = query.order(by: "createdAt", descending: true)
            case .oldest:
                query = query.order(by: "createdAt", descending: false)
            case .top:
                query = query.order(by: "likesCount", descending: true)
            }
            
            let snapshot = try await query.getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: Comment.self)
            }
        } catch {
            print("Error getting comments: \(error)")
            throw AuthError.networkError("Failed to get comments: \(error.localizedDescription)")
        }
    }
    
    /// Create a new comment
    func createComment(comment: Comment) async throws {
        let batch = db.batch()
        
        do {
            // Add comment document
            let commentRef = commentsCollection.document(comment.id)
            try batch.setData(from: comment, forDocument: commentRef)
            
            // Increment post comments count
            let postRef = postsCollection.document(comment.postId)
            batch.updateData(["commentsCount": FieldValue.increment(Int64(1))], forDocument: postRef)
            
            try await batch.commit()
            print("✅ Comment created successfully: \(comment.id)")
        } catch {
            print("Error creating comment: \(error)")
            throw AuthError.networkError("Failed to create comment: \(error.localizedDescription)")
        }
    }
    
    /// Toggle like on a comment
    func toggleCommentLike(commentId: String, userId: String) async throws {
        let likeRef = likesCollection.document("\(userId)_comment_\(commentId)")
        
        do {
            let likeDoc = try await likeRef.getDocument()
            
            if likeDoc.exists {
                // Unlike comment
                let batch = db.batch()
                batch.deleteDocument(likeRef)
                
                let commentRef = commentsCollection.document(commentId)
                batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: commentRef)
                
                try await batch.commit()
                print("✅ Comment unliked successfully: \(commentId)")
            } else {
                // Like comment
                let batch = db.batch()
                
                let likeData: [String: Any] = [
                    "commentId": commentId,
                    "userId": userId,
                    "createdAt": Timestamp()
                ]
                batch.setData(likeData, forDocument: likeRef)
                
                let commentRef = commentsCollection.document(commentId)
                batch.updateData(["likesCount": FieldValue.increment(Int64(1))], forDocument: commentRef)
                
                try await batch.commit()
                print("✅ Comment liked successfully: \(commentId)")
            }
        } catch {
            print("Error toggling comment like: \(error)")
            throw AuthError.networkError("Failed to toggle comment like: \(error.localizedDescription)")
        }
    }
    
    // MARK: - User Management
    
    /// Get user by ID
    func getUser(userId: String) async throws -> User {
        do {
            let document = try await usersCollection.document(userId).getDocument()
            
            guard document.exists else {
                throw AuthError.userNotFound
            }
            
            return try document.data(as: User.self)
        } catch {
            if error is AuthError {
                throw error
            }
            print("Error getting user: \(error)")
            throw AuthError.networkError("Failed to get user: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Reporting
    
    /// Report a post
    func reportPost(report: PostReport) async throws {
        do {
            try reportsCollection.document(report.id).setData(from: report)
            print("✅ Post reported successfully: \(report.postId)")
        } catch {
            print("Error reporting post: \(error)")
            throw AuthError.networkError("Failed to report post: \(error.localizedDescription)")
        }
    }
    
    /// Get reported posts by user
    func getUserReportedPosts(userId: String) async throws -> Set<String> {
        do {
            let snapshot = try await reportsCollection
                .whereField("reportedBy", isEqualTo: userId)
                .getDocuments()
            
            let postIds = snapshot.documents.compactMap { document in
                document.data()["postId"] as? String
            }
            
            return Set(postIds)
        } catch {
            print("Error getting reported posts: \(error)")
            throw AuthError.networkError("Failed to get reported posts: \(error.localizedDescription)")
        }
    }
    
    // MARK: - View Tracking
    
    /// Track post view
    func trackPostView(postId: String, userId: String) async throws {
        do {
            let viewData: [String: Any] = [
                "postId": postId,
                "userId": userId,
                "viewedAt": Timestamp()
            ]
            
            // Use merge to avoid overwriting if already viewed
            try await viewsCollection.document("\(userId)_\(postId)").setData(viewData, merge: true)
            print("✅ Post view tracked: \(postId)")
        } catch {
            print("Error tracking post view: \(error)")
            // Don't throw error for view tracking failures
        }
    }
    
    /// Get viewed posts by user
    func getUserViewedPosts(userId: String) async throws -> Set<String> {
        do {
            let snapshot = try await viewsCollection
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let postIds = snapshot.documents.compactMap { document in
                document.data()["postId"] as? String
            }
            
            return Set(postIds)
        } catch {
            print("Error getting viewed posts: \(error)")
            throw AuthError.networkError("Failed to get viewed posts: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Activity Management
    
    /// Create following activity
    func createFollowingActivity(activity: FollowingActivity) async throws {
        do {
            try activitiesCollection.document(activity.id).setData(from: activity)
            print("✅ Activity created successfully: \(activity.id)")
        } catch {
            print("Error creating activity: \(error)")
            throw AuthError.networkError("Failed to create activity: \(error.localizedDescription)")
        }
    }
    
    /// Get following activities
    func getFollowingActivities(userId: String, limit: Int = 50) async throws -> [FollowingActivity] {
        do {
            // Get users that current user follows
            let followingUserIds = try await getUserFollowing(userId: userId)
            
            if followingUserIds.isEmpty {
                return []
            }
            
            let snapshot = try await activitiesCollection
                .whereField("userId", in: followingUserIds)
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: FollowingActivity.self)
            }
        } catch {
            print("Error getting following activities: \(error)")
            throw AuthError.networkError("Failed to get following activities: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notification Management
    
    /// Get notifications for user
    func getNotifications(userId: String, limit: Int = 50) async throws -> [AppNotification] {
        do {
            let snapshot = try await notificationsCollection
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: AppNotification.self)
            }
        } catch {
            print("Error getting notifications: \(error)")
            throw AuthError.networkError("Failed to get notifications: \(error.localizedDescription)")
        }
    }
    
    /// Create notification
    func createNotification(notification: AppNotification) async throws {
        do {
            try notificationsCollection.document(notification.id).setData(from: notification)
            print("✅ Notification created successfully: \(notification.id)")
        } catch {
            print("Error creating notification: \(error)")
            throw AuthError.networkError("Failed to create notification: \(error.localizedDescription)")
        }
    }
    
    /// Mark notification as read
    func markNotificationAsRead(notificationId: String) async throws {
        do {
            try await notificationsCollection.document(notificationId).updateData([
                "isRead": true
            ])
            print("✅ Notification marked as read: \(notificationId)")
        } catch {
            print("Error marking notification as read: \(error)")
            throw AuthError.networkError("Failed to mark notification as read: \(error.localizedDescription)")
        }
    }
    
    /// Mark all notifications as read for user
    func markAllNotificationsAsRead(userId: String) async throws {
        do {
            let snapshot = try await notificationsCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .getDocuments()
            
            let batch = db.batch()
            
            for document in snapshot.documents {
                batch.updateData(["isRead": true], forDocument: document.reference)
            }
            
            try await batch.commit()
            print("✅ All notifications marked as read for user: \(userId)")
        } catch {
            print("Error marking all notifications as read: \(error)")
            throw AuthError.networkError("Failed to mark all notifications as read: \(error.localizedDescription)")
        }
    }
    
    /// Check if user has unread notifications
    func hasUnreadNotifications(userId: String) async throws -> Bool {
        do {
            let snapshot = try await notificationsCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .limit(to: 1)
                .getDocuments()
            
            return !snapshot.documents.isEmpty
        } catch {
            print("Error checking unread notifications: \(error)")
            return false
        }
    }
    
    // MARK: - Helper Properties
    
    private var usersCollection: CollectionReference {
        db.collection("users")
    }
    
    private var db: Firestore {
        Firestore.firestore()
    }
}

// MARK: - Additional Auth Errors
extension AuthError {
    static let userNotFound = AuthError.networkError("User not found")
}

// MARK: - Firestore Extensions for Models
extension FollowingActivity: Codable {
    enum CodingKeys: String, CodingKey {
        case id, userId, username, activityType, content, relatedPostId, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        
        let activityTypeString = try container.decode(String.self, forKey: .activityType)
        activityType = ActivityType(rawValue: activityTypeString) ?? .newPost
        
        content = try container.decodeIfPresent(String.self, forKey: .content)
        relatedPostId = try container.decodeIfPresent(String.self, forKey: .relatedPostId)
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .timestamp) {
            self.timestamp = timestamp.dateValue()
        } else {
            timestamp = try container.decode(Date.self, forKey: .timestamp)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(username, forKey: .username)
        try container.encode(activityType.rawValue, forKey: .activityType)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(relatedPostId, forKey: .relatedPostId)
        try container.encode(Timestamp(date: timestamp), forKey: .timestamp)
    }
}

extension AppNotification: Codable {
    enum CodingKeys: String, CodingKey {
        case id, userId, type, title, message, relatedPostId, relatedUserId, relatedUsername, createdAt, isRead, actionUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        
        let typeString = try container.decode(String.self, forKey: .type)
        type = NotificationType(rawValue: typeString) ?? .like
        
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        relatedPostId = try container.decodeIfPresent(String.self, forKey: .relatedPostId)
        relatedUserId = try container.decodeIfPresent(String.self, forKey: .relatedUserId)
        relatedUsername = try container.decodeIfPresent(String.self, forKey: .relatedUsername)
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        isRead = try container.decode(Bool.self, forKey: .isRead)
        actionUrl = try container.decodeIfPresent(String.self, forKey: .actionUrl)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(relatedPostId, forKey: .relatedPostId)
        try container.encodeIfPresent(relatedUserId, forKey: .relatedUserId)
        try container.encodeIfPresent(relatedUsername, forKey: .relatedUsername)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(isRead, forKey: .isRead)
        try container.encodeIfPresent(actionUrl, forKey: .actionUrl)
    }
}

extension PostReport: Codable {
    enum CodingKeys: String, CodingKey {
        case id, postId, reportedBy, reason, additionalDetails, createdAt, status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        postId = try container.decode(String.self, forKey: .postId)
        reportedBy = try container.decode(String.self, forKey: .reportedBy)
        
        let reasonString = try container.decode(String.self, forKey: .reason)
        reason = ReportReason(rawValue: reasonString) ?? .other
        
        additionalDetails = try container.decodeIfPresent(String.self, forKey: .additionalDetails)
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        let statusString = try container.decode(String.self, forKey: .status)
        status = ReportStatus(rawValue: statusString) ?? .pending
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(postId, forKey: .postId)
        try container.encode(reportedBy, forKey: .reportedBy)
        try container.encode(reason.rawValue, forKey: .reason)
        try container.encodeIfPresent(additionalDetails, forKey: .additionalDetails)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(status.rawValue, forKey: .status)
    }
}
