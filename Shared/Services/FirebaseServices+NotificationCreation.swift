// File: Shared/Services/FirebaseServices+NotificationCreation.swift
// Free mode: the acting user's app creates inbox notifications for other people.
// See docs/backend-contracts.md, section 0. When Cloud Functions are deployed
// (AppConfig.serverFunctionsEnabled), the server creates them instead and these do nothing.

import Foundation
import FirebaseAuth
import FirebaseFirestore

extension FirebaseServices {
    /// Creates one inbox notification. Skips yourself (except `price_alert`) and people you've blocked.
    /// Failures are ignored: a missed notification should never break the action that caused it.
    func createNotification(
        to userId: String,
        type: String,
        title: String,
        body: String,
        data: [String: String] = [:]
    ) async {
        await createNotifications(to: [userId], type: type, title: title, body: body, data: data)
    }

    /// Creates the same notification for many people, in batches of 450.
    func createNotifications(
        to userIds: [String],
        type: String,
        title: String,
        body: String,
        data: [String: String] = [:]
    ) async {
        guard !AppConfig.serverFunctionsEnabled,
              let actorId = Auth.auth().currentUser?.uid else { return }

        let blocked = await MainActor.run { BlockStore.shared.blockedIds }
        let recipients = Array(Set(userIds)).filter { recipient in
            guard !recipient.isEmpty, !blocked.contains(recipient) else { return false }
            return recipient != actorId || type == "price_alert"
        }
        guard !recipients.isEmpty else { return }

        for chunk in recipients.chunked(into: 450) {
            let batch = db.batch()
            for recipient in chunk {
                let ref = db.collection("notifications").document()
                batch.setData([
                    "userId": recipient,
                    "fromUserId": actorId,
                    "type": type,
                    "title": title,
                    "body": body,
                    "data": data,
                    "isRead": false,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
            }
            try? await batch.commit()
        }
    }

    /// Looks up user ids for `@username` mentions in some text (at most 10 names).
    func userIdsMentioned(in text: String) async -> [String] {
        let names = Set(
            text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
                .filter { $0.hasPrefix("@") && $0.count > 1 }
                .map { $0.dropFirst().trimmingCharacters(in: .punctuationCharacters).lowercased() }
                .filter { !$0.isEmpty }
        )
        guard !names.isEmpty else { return [] }
        var ids: [String] = []
        for chunk in Array(names.prefix(10)).chunked(into: 10) {
            if let snapshot = try? await db.collection("users").whereField("username", in: chunk).getDocuments() {
                ids += snapshot.documents.map(\.documentID)
            }
        }
        return ids
    }
}
