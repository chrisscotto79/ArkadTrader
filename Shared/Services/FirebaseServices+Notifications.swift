// File: Shared/Services/FirebaseServices+Notifications.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

extension FirebaseServices {
    // MARK: - Notification Methods
    
    func sendNotification(to userId: String, type: String, title: String, body: String, data: [String: Any] = [:]) async throws {
        let notification: [String: Any] = [
            "userId": userId,
            "type": type,
            "title": title,
            "body": body,
            "data": data,
            "isRead": false,
            "createdAt": Timestamp(date: Date())
        ]
        
        try await db.collection("notifications").document().setData(notification)
    }
    
    func getUserNotifications(userId: String, limit: Int = 50) async throws -> [UserNotification] {
        let snapshot = try await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? UserNotification.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func markNotificationAsRead(notificationId: String) async throws {
        try await db.collection("notifications").document(notificationId)
            .updateData(["isRead": true])
    }
    
    func getUnreadNotificationCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()
        
        return snapshot.documents.count
    }
    
    // MARK: - Analytics Methods
    
    func trackUserActivity(userId: String, action: String, details: [String: Any] = [:]) async throws {
        let activity: [String: Any] = [
            "userId": userId,
            "action": action,
            "details": details,
            "timestamp": Timestamp(date: Date())
        ]
        
        try await db.collection("userActivity").document().setData(activity)
    }
}
