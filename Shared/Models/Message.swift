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
    
    func otherParticipant(currentUserId: UUID) -> User? {
        return participants?.first { $0.id != currentUserId }
    }
}

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

struct AppNotification: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let type: NotificationType
    let title: String
    let message: String
    let isRead: Bool
    let createdAt: Date
    let actionUrl: String?
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

struct Comment: Identifiable, Codable {
    let id: UUID
    let postId: UUID
    let authorId: UUID
    let authorUsername: String
    let content: String
    let likesCount: Int
    let createdAt: Date
    let parentCommentId: UUID?
    
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

// Extensions
