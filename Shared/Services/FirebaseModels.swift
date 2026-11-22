// File: Shared/Services/FirebaseModels.swift
// Models and errors used by FirebaseServices

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

// MARK: - Supporting Types

enum FirestoreError: LocalizedError {
    case invalidData
    case documentNotFound
    case unauthorized
    case networkError
    case uploadFailed  // ✅ ADD THIS LINE
    
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
        case .uploadFailed:
            return "Failed to upload file"
        }
        
    }
}


enum SearchError: LocalizedError {
    case searchFailed(String)
    case noResults
    case invalidQuery
    
    var errorDescription: String? {
        switch self {
        case .searchFailed(let message):
            return message
        case .noResults:
            return "No results found"
        case .invalidQuery:
            return "Invalid search query"
        }
    }
}

struct NewsAnalytics {
    let totalArticles: Int
    let topKeywords: [String]
    let sourceCounts: [String: Int]
    let lastUpdated: Date
}

struct UserStats {
    let followersCount: Int
    let followingCount: Int
    let postsCount: Int
    let tradesCount: Int
    let joinDate: Date
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
    let parentCommentId: String?
    
    // Initializer for creating a new comment
    init(postId: String, content: String, authorId: String, authorUsername: String, parentCommentId: String? = nil) {
        self.id = UUID().uuidString
        self.postId = postId
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.createdAt = Date()
        self.likesCount = 0
        self.parentCommentId = parentCommentId
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
        self.parentCommentId = parentCommentId
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
        
        // Only add parentCommentId if it exists
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
            parentCommentId: data["parentCommentId"] as? String
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

// MARK: - CommunityMessage Extension

extension CommunityMessage {
    
    /// Updated toFirestore method with edit support
    func toFirestoreWithEditSupport() -> [String: Any] {
        var data = toFirestore()
        data["isEdited"] = false
        return data
    }
    
    /// Updated fromFirestore method with edit support
    static func fromFirestoreWithEditSupport(data: [String: Any], id: String) throws -> CommunityMessage {
        guard let content = data["content"] as? String,
              let authorId = data["authorId"] as? String,
              let authorUsername = data["authorUsername"] as? String,
              let channelId = data["channelId"] as? String,
              let communityId = data["communityId"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        var message = CommunityMessage(
            content: content,
            authorId: authorId,
            authorUsername: authorUsername,
            channelId: channelId,
            communityId: communityId
        )
        
        message.id = id
        message.createdAt = createdAtTimestamp.dateValue()
        
        // Handle edited messages
        if let isEdited = data["isEdited"] as? Bool, isEdited {
            message.content = content + " (edited)"
        }
        
        return message
    }
}
