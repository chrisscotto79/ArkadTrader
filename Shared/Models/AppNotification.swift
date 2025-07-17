//
//  AppNotification.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/17/25.
//


// File: Shared/Models/AppNotification.swift
// AppNotification Model for HomeView

import Foundation
import FirebaseFirestore

struct AppNotification: Identifiable, Codable {
    let id: String
    let userId: String
    let type: NotificationType
    let title: String
    let message: String
    let relatedPostId: String?
    let relatedUserId: String?
    let relatedUsername: String?
    let createdAt: Date
    let isRead: Bool
    let actionUrl: String?
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        type: NotificationType,
        title: String,
        message: String,
        relatedPostId: String? = nil,
        relatedUserId: String? = nil,
        relatedUsername: String? = nil,
        createdAt: Date = Date(),
        isRead: Bool = false,
        actionUrl: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.message = message
        self.relatedPostId = relatedPostId
        self.relatedUserId = relatedUserId
        self.relatedUsername = relatedUsername
        self.createdAt = createdAt
        self.isRead = isRead
        self.actionUrl = actionUrl
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "userId": userId,
            "type": type.rawValue,
            "title": title,
            "message": message,
            "relatedPostId": relatedPostId as Any,
            "relatedUserId": relatedUserId as Any,
            "relatedUsername": relatedUsername as Any,
            "createdAt": Timestamp(date: createdAt),
            "isRead": isRead,
            "actionUrl": actionUrl as Any
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> AppNotification {
        guard let userId = data["userId"] as? String,
              let typeString = data["type"] as? String,
              let type = NotificationType(rawValue: typeString),
              let title = data["title"] as? String,
              let message = data["message"] as? String,
              let isRead = data["isRead"] as? Bool,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        return AppNotification(
            id: id,
            userId: userId,
            type: type,
            title: title,
            message: message,
            relatedPostId: data["relatedPostId"] as? String,
            relatedUserId: data["relatedUserId"] as? String,
            relatedUsername: data["relatedUsername"] as? String,
            createdAt: createdAtTimestamp.dateValue(),
            isRead: isRead,
            actionUrl: data["actionUrl"] as? String
        )
    }
}

// MARK: - NotificationType Enum
enum NotificationType: String, CaseIterable, Codable {
    case like = "like"
    case comment = "comment"
    case reply = "reply"
    case follow = "follow"
    case mention = "mention"
    case tradeAlert = "trade_alert"
    case marketNews = "market_news"
    case communityPost = "community_post"
    case achievement = "achievement"
    case priceAlert = "price_alert"
    
    var displayName: String {
        switch self {
        case .like: return "Like"
        case .comment: return "Comment"
        case .reply: return "Reply"
        case .follow: return "Follow"
        case .mention: return "Mention"
        case .tradeAlert: return "Trade Alert"
        case .marketNews: return "Market News"
        case .communityPost: return "Community Post"
        case .achievement: return "Achievement"
        case .priceAlert: return "Price Alert"
        }
    }
    
    var icon: String {
        switch self {
        case .like: return "heart.fill"
        case .comment: return "message.fill"
        case .reply: return "arrowshape.turn.up.left.fill"
        case .follow: return "person.badge.plus.fill"
        case .mention: return "at.circle.fill"
        case .tradeAlert: return "chart.line.uptrend.xyaxis"
        case .marketNews: return "newspaper.fill"
        case .communityPost: return "person.3.fill"
        case .achievement: return "star.fill"
        case .priceAlert: return "bell.fill"
        }
    }
    
    var color: String {
        switch self {
        case .like: return "red"
        case .comment: return "blue"
        case .reply: return "blue"
        case .follow: return "arkadGold"
        case .mention: return "purple"
        case .tradeAlert: return "green"
        case .marketNews: return "orange"
        case .communityPost: return "arkadGold"
        case .achievement: return "arkadGold"
        case .priceAlert: return "red"
        }
    }
}