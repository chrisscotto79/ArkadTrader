//
//  Message.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Models/Message.swift

import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let recipientId: UUID
    let content: String
    let timestamp: Date
    let isRead: Bool
    let messageType: MessageType
    
    init(conversationId: UUID, senderId: UUID, recipientId: UUID, content: String) {
        self.id = UUID()
        self.conversationId = conversationId
        self.senderId = senderId
        self.recipientId = recipientId
        self.content = content
        self.timestamp = Date()
        self.isRead = false
        self.messageType = .text
    }
}

enum MessageType: String, CaseIterable, Codable {
    case text = "text"
    case image = "image"
    case tradeShare = "trade_share"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .tradeShare: return "Trade Share"
        }
    }
}

// File: Shared/Models/Conversation.swift

struct Conversation: Identifiable, Codable {
    let id: UUID
    let participantIds: [UUID]
    let participants: [User]?
    let lastMessage: Message?
    let unreadCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    init(participantIds: [UUID]) {
        self.id = UUID()
        self.participantIds = participantIds
        self.participants = nil
        self.lastMessage = nil
        self.unreadCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Helper to get the other participant (assuming 1-on-1 conversation)
    func otherParticipant(currentUserId: UUID) -> User? {
        return participants?.first { $0.id != currentUserId }
    }
}

// File: Shared/Models/Following.swift

struct Following: Identifiable, Codable {
    let id: UUID
    let followerId: UUID
    let followingId: UUID
    let createdAt: Date
    
    init(followerId: UUID, followingId: UUID) {
        self.id = UUID()
        self.followerId = followerId
        self.followingId = followingId
        self.createdAt = Date()
    }
}



// File: Shared/Models/Notification.swift

struct AppNotification: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let type: NotificationType
    let title: String
    let message: String
    let isRead: Bool
    let createdAt: Date
    let actionUrl: String? // Deep link to relevant content
    let relatedUserId: UUID?
    let relatedTradeId: UUID?
    let relatedPostId: UUID?
    
    init(userId: UUID, type: NotificationType, title: String, message: String) {
        self.id = UUID()
        self.userId = userId
        self.type = type
        self.title = title
        self.message = message
        self.isRead = false
        self.createdAt = Date()
        self.actionUrl = nil
        self.relatedUserId = nil
        self.relatedTradeId = nil
        self.relatedPostId = nil
    }
}

enum NotificationType: String, CaseIterable, Codable {
    case newFollower = "new_follower"
    case newMessage = "new_message"
    case tradeLike = "trade_like"
    case tradeComment = "trade_comment"
    case marketAlert = "market_alert"
    case leaderboardUpdate = "leaderboard_update"
    
    var displayName: String {
        switch self {
        case .newFollower: return "New Follower"
        case .newMessage: return "New Message"
        case .tradeLike: return "Trade Like"
        case .tradeComment: return "Trade Comment"
        case .marketAlert: return "Market Alert"
        case .leaderboardUpdate: return "Leaderboard Update"
        }
    }
    
    var iconName: String {
        switch self {
        case .newFollower: return "person.badge.plus"
        case .newMessage: return "message"
        case .tradeLike: return "heart"
        case .tradeComment: return "text.bubble"
        case .marketAlert: return "exclamationmark.triangle"
        case .leaderboardUpdate: return "trophy"
        }
    }
}

// File: Shared/Models/Comment.swift

struct Comment: Identifiable, Codable {
    let id: UUID
    let postId: UUID
    let authorId: UUID
    let authorUsername: String
    let content: String
    let likesCount: Int
    let createdAt: Date
    let parentCommentId: UUID? // For reply threading
    
    init(postId: UUID, authorId: UUID, authorUsername: String, content: String) {
        self.id = UUID()
        self.postId = postId
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.content = content
        self.likesCount = 0
        self.createdAt = Date()
        self.parentCommentId = nil
    }
}

// File: Shared/Models/Like.swift

struct Like: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let postId: UUID?
    let commentId: UUID?
    let tradeId: UUID?
    let createdAt: Date
    
    init(userId: UUID, postId: UUID) {
        self.id = UUID()
        self.userId = userId
        self.postId = postId
        self.commentId = nil
        self.tradeId = nil
        self.createdAt = Date()
    }
}

// Extensions to existing models for enhanced functionality

// Add to User.swift
extension User {
    var isOnline: Bool {
        // Calculate if user was active recently
        // This would be updated from real-time data
        return true // Placeholder
    }
    
    var lastActiveAt: Date {
        // Return last activity timestamp
        return Date() // Placeholder
    }
}

// Add to Trade.swift
extension Trade {
    var shareableContent: String {
        let performance = profitLoss >= 0 ? "📈 +\(profitLoss.asCurrency)" : "📉 \(profitLoss.asCurrency)"
        return "Just \(isOpen ? "opened" : "closed") my \(ticker) position! \(performance)"
    }
    
    var isRecentlyUpdated: Bool {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return entryDate > oneDayAgo
    }
}

// Add to Post.swift
extension Post {
    var isRecent: Bool {
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        return createdAt > oneHourAgo
    }
    
    var timeAgoString: String {
        let interval = Date().timeIntervalSince(createdAt)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }
}
