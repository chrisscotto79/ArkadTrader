//
//  UserNotification.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/13/25.
//


// File: Shared/Models/UserNotification.swift
import Foundation
import FirebaseFirestore

struct UserNotification: Identifiable, Codable {
    let id: String
    let userId: String
    let type: String
    let title: String
    let body: String
    let data: [String: String]
    let isRead: Bool
    let createdAt: Date
    
    static func fromFirestore(data: [String: Any], id: String) throws -> UserNotification {
        guard let userId = data["userId"] as? String,
              let type = data["type"] as? String,
              let title = data["title"] as? String,
              let body = data["body"] as? String,
              let isRead = data["isRead"] as? Bool,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw NSError(domain: "NotificationDecoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid notification data"])
        }
        
        let notificationData = data["data"] as? [String: String] ?? [:]
        
        return UserNotification(
            id: id,
            userId: userId,
            type: type,
            title: title,
            body: body,
            data: notificationData,
            isRead: isRead,
            createdAt: createdAtTimestamp.dateValue()
        )
    }
}