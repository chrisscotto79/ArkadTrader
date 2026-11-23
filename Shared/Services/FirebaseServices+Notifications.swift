// File: Shared/Services/FirebaseServices+Notifications.swift
// The notifications inbox, device tokens and push preferences (docs/backend-contracts.md, section 2).
// Cloud Functions create `notifications/{id}` documents and send the pushes; the app only
// reads them and marks them read.

import Foundation
import FirebaseFirestore

extension FirebaseServices {
    // MARK: - Inbox

    private func notificationsQuery(userId: String, limit: Int) -> Query {
        db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
    }

    private func unreadNotificationsQuery(userId: String) -> Query {
        db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
    }

    func getUserNotifications(userId: String, limit: Int = 50) async throws -> [UserNotification] {
        let snapshot = try await notificationsQuery(userId: userId, limit: limit).getDocuments()
        return snapshot.documents.compactMap { document in
            try? UserNotification.fromFirestore(data: document.data(), id: document.documentID)
        }
    }

    /// Live list of the user's newest notifications. Remove the returned registration when done.
    func listenToNotifications(
        userId: String,
        limit: Int = 50,
        onChange: @escaping ([UserNotification]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        notificationsQuery(userId: userId, limit: limit).addSnapshotListener { snapshot, error in
            if let error {
                onError(error)
                return
            }
            let notifications = snapshot?.documents.compactMap { document in
                try? UserNotification.fromFirestore(data: document.data(), id: document.documentID)
            } ?? []
            onChange(notifications)
        }
    }

    /// Live count of unread notifications, capped at `limit` so a large backlog stays cheap.
    func listenToUnreadNotificationCount(
        userId: String,
        limit: Int = 100,
        onChange: @escaping (Int) -> Void
    ) -> ListenerRegistration {
        unreadNotificationsQuery(userId: userId)
            .limit(to: limit)
            .addSnapshotListener { snapshot, _ in
                onChange(snapshot?.documents.count ?? 0)
            }
    }

    func getUnreadNotificationCount(userId: String) async throws -> Int {
        let snapshot = try await unreadNotificationsQuery(userId: userId).count.getAggregation(source: .server)
        return snapshot.count.intValue
    }

    func markNotificationAsRead(notificationId: String) async throws {
        try await db.collection("notifications").document(notificationId)
            .updateData(["isRead": true])
    }

    /// Marks every unread notification as read, in batches of up to 400.
    func markAllNotificationsAsRead(userId: String) async throws {
        while true {
            let snapshot = try await unreadNotificationsQuery(userId: userId)
                .limit(to: 400)
                .getDocuments()
            guard !snapshot.documents.isEmpty else { return }

            let batch = db.batch()
            for document in snapshot.documents {
                batch.updateData(["isRead": true], forDocument: document.reference)
            }
            try await batch.commit()

            if snapshot.documents.count < 400 { return }
        }
    }

    // MARK: - Device tokens

    private func fcmTokenRef(_ token: String, userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("fcmTokens").document(token)
    }

    /// Saves this device's FCM token at `users/{uid}/fcmTokens/{token}`.
    func saveFCMToken(_ token: String, userId: String) async throws {
        try await fcmTokenRef(token, userId: userId).setData([
            "token": token,
            "platform": "ios",
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func deleteFCMToken(_ token: String, userId: String) async throws {
        try await fcmTokenRef(token, userId: userId).delete()
    }

    // MARK: - Preferences

    /// Turns one `users/{uid}.notificationPrefs` key on or off, leaving the others as they are.
    func setNotificationPreference(_ key: String, enabled: Bool, userId: String) async throws {
        try await db.collection("users").document(userId).setData(
            ["notificationPrefs": [key: enabled]],
            merge: true
        )
    }
}
