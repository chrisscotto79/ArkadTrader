// File: Shared/Services/FirebaseServices+Notifications.swift
// The notifications inbox, device tokens and push preferences (docs/backend-contracts.md, section 2).
// With Cloud Functions deployed, the server creates `notifications/{id}` documents and sends the
// pushes. In free mode (section 0) the acting user's app creates them: see the "Social actions"
// section below and FirebaseServices+NotificationCreation.swift. Either way the recipient's app
// only reads them and marks them read.

import Foundation
import FirebaseFirestore

/// A notification plus who caused it. `fromUserId` is set on notifications the app creates
/// in free mode, so the inbox can hide ones from people you've blocked.
struct InboxEntry {
    var notification: UserNotification
    let fromUserId: String?

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let notification = try? UserNotification.fromFirestore(data: data, id: document.documentID) else {
            return nil
        }
        self.notification = notification
        self.fromUserId = data["fromUserId"] as? String
    }
}

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

    /// Like `listenToNotifications`, but each entry also carries `fromUserId`.
    func listenToInbox(
        userId: String,
        limit: Int = 50,
        onChange: @escaping ([InboxEntry]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        notificationsQuery(userId: userId, limit: limit).addSnapshotListener { snapshot, error in
            if let error {
                onError(error)
                return
            }
            onChange(snapshot?.documents.compactMap(InboxEntry.init(document:)) ?? [])
        }
    }

    /// Live list of unread notifications, capped at `limit`, so the Home bell can leave out
    /// the ones the inbox hides.
    func listenToUnreadNotifications(
        userId: String,
        limit: Int = 100,
        onChange: @escaping ([InboxEntry]) -> Void
    ) -> ListenerRegistration {
        unreadNotificationsQuery(userId: userId)
            .limit(to: limit)
            .addSnapshotListener { snapshot, _ in
                onChange(snapshot?.documents.compactMap(InboxEntry.init(document:)) ?? [])
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

    // MARK: - Social actions (free mode)
    //
    // Called after a like, comment, follow or post has been written. Each runs in the
    // background and never throws, so a missed notification can't break the action.
    // With Cloud Functions deployed the server creates these and the calls do nothing.

    /// "<username> liked your post", to the post's author.
    func notifyPostLiked(postId: String) {
        guard !AppConfig.serverFunctionsEnabled else { return }
        Task {
            guard let post = await postSummary(postId: postId) else { return }
            let username = await currentUsername()
            await createNotification(
                to: post.authorId,
                type: "like",
                title: "\(username) liked your post",
                body: Self.snippet(post.content),
                data: ["route": "post", "postId": postId]
            )
        }
    }

    /// "<username> commented: <first 80 characters>", to the post's author.
    func notifyPostCommented(postId: String, commenterUsername: String, content: String) {
        guard !AppConfig.serverFunctionsEnabled else { return }
        Task {
            guard let post = await postSummary(postId: postId) else { return }
            await createNotification(
                to: post.authorId,
                type: "reply",
                title: "\(commenterUsername) commented: \(Self.snippet(content))",
                body: "",
                data: ["route": "post", "postId": postId]
            )
        }
    }

    /// "<username> started following you", to the person followed.
    func notifyFollowed(userId: String, followerId: String) {
        guard !AppConfig.serverFunctionsEnabled else { return }
        Task {
            let username = await currentUsername()
            await createNotification(
                to: userId,
                type: "follow",
                title: "\(username) started following you",
                body: "",
                data: ["route": "profile", "userId": followerId]
            )
        }
    }

    /// "<username> mentioned you", to everyone @mentioned in a new post.
    func notifyPostMentions(postId: String, authorUsername: String, content: String) {
        guard !AppConfig.serverFunctionsEnabled, content.contains("@") else { return }
        Task {
            let mentioned = await userIdsMentioned(in: content)
            guard !mentioned.isEmpty else { return }
            await createNotifications(
                to: mentioned,
                type: "mention",
                title: "\(authorUsername) mentioned you",
                body: Self.snippet(content),
                data: ["route": "post", "postId": postId]
            )
        }
    }

    /// The signed-in user's username, for notification text.
    private func currentUsername() async -> String {
        let username = await MainActor.run { FirebaseAuthService.shared.currentUser?.username }
        guard let username, !username.isEmpty else { return "Someone" }
        return username
    }

    private func postSummary(postId: String) async -> (authorId: String, content: String)? {
        guard let data = try? await db.collection("posts").document(postId).getDocument().data(),
              let authorId = data["authorId"] as? String, !authorId.isEmpty else { return nil }
        return (authorId, data["content"] as? String ?? "")
    }

    /// The first 80 characters of some text, on one line.
    static func snippet(_ text: String, limit: Int = 80) -> String {
        let oneLine = text
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard oneLine.count > limit else { return oneLine }
        return String(oneLine.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
