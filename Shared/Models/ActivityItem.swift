//
//  ActivityItem.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//

import Foundation
import FirebaseFirestore

struct ActivityItem: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let activityType: ActivityType
    let content: String
    let relatedId: String?
    let createdAt: Date
    
    enum ActivityType: String, CaseIterable, Codable {
        case newPost = "new_post"
        case newTrade = "new_trade"
        case joinedCommunity = "joined_community"
        case tradeClosed = "trade_closed"
        case achievement = "achievement"
        
        var displayName: String {
            switch self {
            case .newPost: return "New Post"
            case .newTrade: return "New Trade"
            case .joinedCommunity: return "Joined Community"
            case .tradeClosed: return "Trade Closed"
            case .achievement: return "Achievement"
            }
        }
        
        var icon: String {
            switch self {
            case .newPost: return "text.bubble"
            case .newTrade: return "chart.line.uptrend.xyaxis"
            case .joinedCommunity: return "person.3"
            case .tradeClosed: return "checkmark.circle"
            case .achievement: return "trophy"
            }
        }
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "userId": userId,
            "username": username,
            "activityType": activityType.rawValue,
            "content": content,
            "relatedId": relatedId as Any,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> ActivityItem {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let activityTypeString = data["activityType"] as? String,
              let activityType = ActivityType(rawValue: activityTypeString),
              let content = data["content"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw NSError(domain: "ActivityItemDecoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid activity item data"])
        }
        
        return ActivityItem(
            id: id,
            userId: userId,
            username: username,
            activityType: activityType,
            content: content,
            relatedId: data["relatedId"] as? String,
            createdAt: createdAtTimestamp.dateValue()
        )
    }
}
