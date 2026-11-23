// File: Shared/Services/FirebaseServices+NotificationCreation.swift
// Free mode: the acting user's app creates inbox notifications for other people.
// See docs/backend-contracts.md, section 0. When Cloud Functions are deployed
// (AppConfig.serverFunctionsEnabled), the server creates them instead and these do nothing.
//
// Every document written here is
//   notifications/{id} = { userId, fromUserId: me, type, title, body, data: [String: String],
//                          isRead: false, createdAt: serverTimestamp }
// - Never to yourself, except `price_alert`, which only goes to yourself.
// - Never to people you've blocked.
// - `communityId` (or data["communityId"]) is required by the rules for community types
//   (callout, callout_result, callout_update, mention-in-chat, member_joined, community_event,
//   trade_share): both sides must be members of that community.
// - title is cut to 200 characters, body to 500, each data value to 200.

import Foundation
import FirebaseAuth
import FirebaseFirestore

extension FirebaseServices {
    /// Creates one inbox notification. Skips yourself (except `price_alert`) and people you've blocked.
    /// Failures are ignored: a missed notification should never break the action that caused it.
    ///
    /// - Parameter documentId: a fixed id for notifications that should only ever be sent once
    ///   (e.g. "like_{postId}_{me}"). Writing it again is an update, which the rules refuse, so
    ///   a re-like doesn't notify twice.
    func createNotification(
        to userId: String,
        type: String,
        title: String,
        body: String,
        data: [String: String] = [:],
        communityId: String? = nil,
        documentId: String? = nil
    ) async {
        await createNotifications(to: [userId], type: type, title: title, body: body, data: data,
                                  communityId: communityId, documentId: documentId)
    }

    /// Creates the same notification for many people, in batches of 450. If a batch is refused
    /// (one recipient the rules don't allow), its notifications are sent one by one instead.
    func createNotifications(
        to userIds: [String],
        type: String,
        title: String,
        body: String,
        data: [String: String] = [:],
        communityId: String? = nil,
        documentId: String? = nil
    ) async {
        guard !AppConfig.serverFunctionsEnabled,
              let actorId = Auth.auth().currentUser?.uid else { return }

        let blocked = await MainActor.run { BlockStore.shared.blockedIds }
        var seen = Set<String>()
        let recipients = userIds.filter { recipient in
            guard !recipient.isEmpty, !blocked.contains(recipient), seen.insert(recipient).inserted else { return false }
            // price_alert only to yourself; everything else never to yourself
            return type == "price_alert" ? recipient == actorId : recipient != actorId
        }
        guard !recipients.isEmpty else { return }

        var payload = data
        if let communityId, !communityId.isEmpty { payload["communityId"] = communityId }
        payload = payload.mapValues { String($0.prefix(200)) }

        func document(for recipient: String) -> [String: Any] {
            [
                "userId": recipient,
                "fromUserId": actorId,
                "type": type,
                "title": String(title.prefix(200)),
                "body": String(body.prefix(500)),
                "data": payload,
                "isRead": false,
                "createdAt": FieldValue.serverTimestamp()
            ]
        }
        func ref(for recipient: String) -> DocumentReference {
            let collection = db.collection("notifications")
            guard let documentId else { return collection.document() }
            // One fixed id per recipient
            return collection.document(recipients.count == 1 ? documentId : "\(documentId)_\(recipient)")
        }

        for chunk in recipients.chunked(into: 450) {
            let batch = db.batch()
            for recipient in chunk {
                batch.setData(document(for: recipient), forDocument: ref(for: recipient))
            }
            do {
                try await batch.commit()
            } catch where chunk.count > 1 {
                for recipient in chunk {
                    try? await ref(for: recipient).setData(document(for: recipient))
                }
            } catch {
                // A single refused notification is dropped
            }
        }
    }

    /// Looks up user ids for `@username` mentions in some text (at most 10 names). Trailing
    /// ".,!?:;)" is ignored ("@sam," is sam); underscores are part of the name.
    func userIdsMentioned(in text: String) async -> [String] {
        let trailing = CharacterSet(charactersIn: ".,!?:;)")
        var names: [String] = []
        for word in text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }) where word.hasPrefix("@") {
            let name = String(word.dropFirst())
                .trimmingCharacters(in: trailing)
                .lowercased()
            if !name.isEmpty, !names.contains(name) { names.append(name) }
        }
        guard !names.isEmpty else { return [] }
        guard let snapshot = try? await db.collection("users")
            .whereField("username", in: Array(names.prefix(10)))
            .getDocuments() else { return [] }
        return snapshot.documents.map(\.documentID)
    }
}
