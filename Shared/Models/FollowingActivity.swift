//
//  FollowingActivity.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/17/25.
//


// File: Shared/Models/FollowingActivity.swift  
// FollowingActivity Model for HomeView

import Foundation
import FirebaseFirestore

struct FollowingActivity: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let activityType: ActivityType
    let content: String
    let relatedPostId: String?
    let relatedUserId: String?
    let timestamp: Date
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        username: String,
        activityType: ActivityType,
        content: String,
        relatedPostId: String? = nil,
        relatedUserId: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.activityType = activityType
        self.content = content
        self.relatedPostId = relatedPostId
        self.relatedUserId = relatedUserId
        self.timestamp = timestamp
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "userId": userId,
            "username": username,
            "activityType": activityType.rawValue,
            "content": content,
            "relatedPostId": relatedPostId as Any,
            "relatedUserId": relatedUserId as Any,
            "timestamp": Timestamp(date: timestamp)
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> FollowingActivity {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let activityTypeString = data["activityType"] as? String,
              let activityType = ActivityType(rawValue: activityTypeString),
              let content = data["content"] as? String,
              let timestampFirestore = data["timestamp"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        return FollowingActivity(
            id: id,
            userId: userId,
            username: username,
            activityType: activityType,
            content: content,
            relatedPostId: data["relatedPostId"] as? String,
            relatedUserId: data["relatedUserId"] as? String,
            timestamp: timestampFirestore.dateValue()
        )
    }
}

// MARK: - ActivityType Enum
enum ActivityType: String, CaseIterable, Codable {
    case newPost = "new_post"
    case newTrade = "new_trade"
    case tradeClosed = "trade_closed"
    case likedPost = "liked_post"
    case commentedOnPost = "commented_on_post"
    case followedUser = "followed_user"
    case joinedCommunity = "joined_community"
    case achievementUnlocked = "achievement_unlocked"
    
    var description: String {
        switch self {
        case .newPost: return "posted"
        case .newTrade: return "opened a trade"
        case .tradeClosed: return "closed a trade"
        case .likedPost: return "liked a post"
        case .commentedOnPost: return "commented on a post"
        case .followedUser: return "followed a user"
        case .joinedCommunity: return "joined a community"
        case .achievementUnlocked: return "unlocked an achievement"
        }
    }
    
    var icon: String {
        switch self {
        case .newPost: return "plus.circle"
        case .newTrade: return "chart.line.uptrend.xyaxis"
        case .tradeClosed: return "checkmark.circle"
        case .likedPost: return "heart"
        case .commentedOnPost: return "message"
        case .followedUser: return "person.badge.plus"
        case .joinedCommunity: return "person.3"
        case .achievementUnlocked: return "star"
        }
    }
    
    var color: String {
        switch self {
        case .newPost: return "blue"
        case .newTrade: return "green"
        case .tradeClosed: return "arkadGold"
        case .likedPost: return "red"
        case .commentedOnPost: return "blue"
        case .followedUser: return "arkadGold"
        case .joinedCommunity: return "purple"
        case .achievementUnlocked: return "arkadGold"
        }
    }
}