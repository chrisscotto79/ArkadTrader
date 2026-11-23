// File: Shared/Services/FirebaseServices+Moderation.swift
// Reports, blocking, and community moderation (mutes, bans, message delete and pin).
// Data shapes follow docs/backend-contracts.md, section 1.

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

extension FirebaseServices {
    // MARK: - Reports

    /// Writes a `reports/{id}` document. Post reports are counted once per person; a post is hidden at 3.
    func submitReport(target: ReportTarget, reason: ReportReason, details: String?, reportedBy: String) async throws {
        var report: [String: Any] = [
            "targetType": target.targetType,
            "targetId": target.targetId,
            "targetOwnerId": target.targetOwnerId,
            "reason": reason.rawValue,
            "reportedBy": reportedBy,
            "createdAt": Timestamp(date: Date()),
            "status": "pending"
        ]
        if let communityId = target.communityId { report["communityId"] = communityId }
        if let channelId = target.channelId { report["channelId"] = channelId }
        if let postId = target.postId { report["postId"] = postId }
        if let details = details?.trimmingCharacters(in: .whitespacesAndNewlines), !details.isEmpty {
            report["details"] = details
        }

        // The report itself must land; the post bookkeeping below is secondary.
        try await db.collection("reports").document().setData(report)

        // Best-effort: the report is already saved, so a failure here shouldn't read as a failed report.
        if case .post(let postId, _) = target {
            try? await recordPostReport(postId: postId, reportedBy: reportedBy)
        }
    }

    /// Remembers which posts this user reported, and (free mode) counts the report on the post.
    private func recordPostReport(postId: String, reportedBy: String) async throws {
        try await db.collection("users").document(reportedBy)
            .collection("reportedPosts").document(postId)
            .setData(["postId": postId, "reportedAt": Timestamp(date: Date())])

        // With the server off, the reporter's app counts the report: one reporters/{me}
        // marker plus reportCount + 1 in the same batch (the rules allow it once per person),
        // and hides the post once three different people have reported it.
        guard !AppConfig.serverFunctionsEnabled else { return }
        let postRef = db.collection("posts").document(postId)
        let markerRef = postRef.collection("reporters").document(reportedBy)
        let post = try await postRef.getDocument()
        guard let data = post.data(), (data["authorId"] as? String) != reportedBy else { return }
        if (try? await markerRef.getDocument())?.exists == true { return }

        let newCount = ((data["reportCount"] as? NSNumber)?.intValue ?? 0) + 1
        let batch = db.batch()
        batch.setData(["reportedAt": FieldValue.serverTimestamp()], forDocument: markerRef)
        batch.updateData(["reportCount": newCount], forDocument: postRef)
        try await batch.commit()

        if newCount >= 3, (data["isHidden"] as? Bool) != true {
            try? await postRef.updateData([
                "isHidden": true,
                "hiddenAt": FieldValue.serverTimestamp(),
                "hiddenReason": "Multiple reports (\(newCount) reports)"
            ])
        }
    }

    /// Older entry point (free-text reason). Files the report as "other" with the text as details.
    func reportPost(postId: String, reportedBy: String, reason: String) async throws {
        let postDoc = try await db.collection("posts").document(postId).getDocument()
        let ownerId = postDoc.data()?["authorId"] as? String ?? ""
        try await submitReport(
            target: .post(id: postId, ownerId: ownerId),
            reason: .other,
            details: reason,
            reportedBy: reportedBy
        )
    }

    /// Older entry point (free-text reason). Files the report as "other" with the text as details.
    func reportUser(userId: String, reportedBy: String, reason: String) async throws {
        try await submitReport(target: .user(id: userId), reason: .other, details: reason, reportedBy: reportedBy)
    }

    // MARK: - Blocking

    /// Blocks a user and removes any follow between the two accounts.
    func blockUser(userId: String, blockedBy: String) async throws {
        let blockRef = db.collection("users").document(blockedBy)
            .collection("blockedUsers").document(userId)

        try await blockRef.setData([
            "userId": userId,
            "blockedAt": Timestamp(date: Date())
        ])

        // You stop following them
        if try await isFollowing(userId: blockedBy, targetUserId: userId) {
            try await unfollowUser(userId: userId, followerId: blockedBy)
        }

        // They stop following you. This writes to their account too, so it is best-effort:
        // the block above already hides their content from you either way.
        if (try? await isFollowing(userId: userId, targetUserId: blockedBy)) == true {
            try? await unfollowUser(userId: blockedBy, followerId: userId)
        }
    }

    func unblockUser(userId: String, unblockedBy: String) async throws {
        try await db.collection("users").document(unblockedBy)
            .collection("blockedUsers").document(userId).delete()
    }

    func getUserBlockedUsers(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId)
            .collection("blockedUsers").getDocuments()

        return Set(snapshot.documents.map { $0.documentID })
    }

    func isUserBlocked(userId: String, by blockedBy: String) async throws -> Bool {
        let document = try await db.collection("users").document(blockedBy)
            .collection("blockedUsers").document(userId).getDocument()

        return document.exists
    }

    // MARK: - Community members: bans, removal, mutes

    /// Whether `userId` is banned from the community (`communities/{cid}/bans/{uid}` exists).
    func isUserBanned(communityId: String, userId: String) async throws -> Bool {
        let document = try await db.collection("communities").document(communityId)
            .collection("bans").document(userId).getDocument()
        return document.exists
    }

    /// Bans a member: writes `bans/{uid}` and removes their membership in one batch.
    func banMember(communityId: String, userId: String, bannedBy: String, reason: String? = nil) async throws {
        let communityRef = db.collection("communities").document(communityId)
        let batch = db.batch()

        var ban: [String: Any] = [
            "bannedBy": bannedBy,
            "createdAt": Timestamp(date: Date())
        ]
        if let reason, !reason.isEmpty { ban["reason"] = reason }
        batch.setData(ban, forDocument: communityRef.collection("bans").document(userId))

        let memberRef = communityRef.collection("members").document(userId)
        if try await memberRef.getDocument().exists {
            batch.deleteDocument(memberRef)
            batch.updateData(["memberCount": FieldValue.increment(Int64(-1))], forDocument: communityRef)
            batch.updateData(
                ["communityIds": FieldValue.arrayRemove([communityId])],
                forDocument: db.collection("users").document(userId)
            )
        }

        try await batch.commit()
    }

    /// Removes a member without banning them (they can rejoin).
    func removeMember(communityId: String, userId: String) async throws {
        try await leaveCommunity(communityId: communityId, userId: userId)
    }

    /// Mutes a member until `until`, or unmutes them when `until` is nil.
    func setMemberMute(communityId: String, userId: String, until: Date?) async throws {
        let memberRef = db.collection("communities").document(communityId)
            .collection("members").document(userId)
        let value: Any
        if let until {
            value = Timestamp(date: until)
        } else {
            value = FieldValue.delete()
        }
        try await memberRef.updateData(["mutedUntil": value])
    }

    /// Members whose mute hasn't run out yet, keyed by user id.
    func getMutedMembers(communityId: String) async throws -> [String: Date] {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("members")
            .whereField("mutedUntil", isGreaterThan: Timestamp(date: Date()))
            .getDocuments()

        var muted: [String: Date] = [:]
        for document in snapshot.documents {
            if let until = (document.data()["mutedUntil"] as? Timestamp)?.dateValue() {
                muted[document.documentID] = until
            }
        }
        return muted
    }

    /// Live `mutedUntil` for one member (nil when not muted or the mute has run out).
    func listenToMemberMute(communityId: String, userId: String, onChange: @escaping (Date?) -> Void) -> ListenerRegistration {
        db.collection("communities").document(communityId)
            .collection("members").document(userId)
            .addSnapshotListener { snapshot, _ in
                let until = (snapshot?.data()?["mutedUntil"] as? Timestamp)?.dateValue()
                onChange(until.flatMap { $0 > Date() ? $0 : nil })
            }
    }

    // MARK: - Channel messages: delete and pin

    private func messageRef(messageId: String, channelId: String, communityId: String) -> DocumentReference {
        db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages").document(messageId)
    }

    /// Soft delete: every listener sees the message turn into "Message deleted". The text and every
    /// structured field (callout, updates, results, trade shares, game plans, reply quote, media,
    /// reactions) are removed from the doc, so nothing of it can still be read.
    func softDeleteCommunityMessage(messageId: String, channelId: String, communityId: String, deletedBy: String) async throws {
        var fields: [String: Any] = [
            "isDeleted": true,
            "content": "",
            "deletedBy": deletedBy,
            "deletedAt": FieldValue.serverTimestamp()
        ]
        for field in CommunityMessage.structuredFields {
            fields[field] = FieldValue.delete()
        }
        try await messageRef(messageId: messageId, channelId: channelId, communityId: communityId).updateData(fields)
    }

    func setCommunityMessagePinned(messageId: String, channelId: String, communityId: String, isPinned: Bool, by userId: String) async throws {
        let fields: [String: Any] = isPinned
            ? ["isPinned": true, "pinnedBy": userId, "pinnedAt": Timestamp(date: Date())]
            : ["isPinned": false, "pinnedBy": FieldValue.delete(), "pinnedAt": FieldValue.delete()]
        try await messageRef(messageId: messageId, channelId: channelId, communityId: communityId).updateData(fields)
    }
}
