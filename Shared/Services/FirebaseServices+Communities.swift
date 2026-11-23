// File: Shared/Services/FirebaseServices+Communities.swift
// Communities: create / edit / delete, membership and invites, channels, chat messages,
// reactions and typing. Free mode: the phone does the work and firestore.rules enforce it.

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

extension FirebaseServices {
    // MARK: - Message reactions

    /// Most emoji one person can put on a single message (the rules check the same number).
    static let maxReactionsPerUser = 10

    /// Adds or removes one of the signed-in user's reactions on a message.
    /// Reactions live on the message as `reactions: { <uid>: [emoji, ...] }`; this only ever
    /// touches `reactions.<userId>`, with arrayUnion / arrayRemove.
    func setMessageReaction(messageId: String, channelId: String, communityId: String,
                            emoji: String, userId: String, adding: Bool) async throws {
        let ref = channelMessageRef(communityId: communityId, channelId: channelId, messageId: messageId)
        let change = adding ? FieldValue.arrayUnion([emoji]) : FieldValue.arrayRemove([emoji])
        try await ref.updateData([FieldPath(["reactions", userId]): change])
    }

    // MARK: - Community management

    /// Creates the community, the owner's member doc, `communityIds` on the owner, and the
    /// default #general and #callouts channels, all in one batch.
    func createCommunity(_ community: Community) async throws {
        let communityRef = db.collection("communities").document(community.id)
        let memberRef = communityRef.collection("members").document(community.createdBy)
        let userRef = db.collection("users").document(community.createdBy)

        func coreWrites(_ batch: WriteBatch) {
            batch.setData(community.toFirestore(), forDocument: communityRef)
            batch.setData([
                "userId": community.createdBy,
                "role": "admin",
                "joinedAt": Timestamp(date: Date())
            ], forDocument: memberRef)
            batch.updateData(["communityIds": FieldValue.arrayUnion([community.id])], forDocument: userRef)
        }

        let batch = db.batch()
        coreWrites(batch)
        for channel in Self.defaultChannels(for: community.id) {
            batch.setData(channel.toFirestore(),
                          forDocument: communityRef.collection("channels").document(channel.id))
        }
        do {
            try await batch.commit()
        } catch let error as NSError where error.domain == FirestoreErrorDomain
                    && error.code == FirestoreErrorCode.permissionDenied.rawValue {
            // Rules that can't see the community inside the same batch: create it on its own,
            // then the channels. If the channels still fail, the community page offers to add them.
            let fallback = db.batch()
            coreWrites(fallback)
            try await fallback.commit()
            try? await createDefaultChannels(for: community.id)
        }
    }

    /// Saves the edited details only (name, nameLower, description, isPrivate), so counters
    /// like memberCount and lastActivityDate are never overwritten with old values.
    func updateCommunity(_ community: Community) async throws {
        try await updateCommunityDetails(
            communityId: community.id,
            name: community.name,
            description: community.description,
            isPrivate: community.isPrivate
        )
    }

    /// Writes only the fields passed in. Renames also update `nameLower`.
    func updateCommunityDetails(communityId: String, name: String? = nil, description: String? = nil,
                                isPrivate: Bool? = nil) async throws {
        var fields: [String: Any] = [:]
        if let name {
            fields["name"] = name
            fields["nameLower"] = Community.normalizedName(name)
        }
        if let description { fields["description"] = description }
        if let isPrivate { fields["isPrivate"] = isPrivate }
        guard !fields.isEmpty else { return }
        try await db.collection("communities").document(communityId).updateData(fields)
    }

    /// Deletes a community. With the server on, deleting the doc is enough (onCommunityDeleted
    /// cleans up). In free mode the owner's phone removes the children first, in batches:
    /// channels (their messages and typing docs), members, rules, bans, invites, traderStats,
    /// courses (lessons), events (rsvps); then the id from the owner's `communityIds`; then the doc.
    /// Child deletes are best-effort, so one refused step doesn't leave a half-deleted community.
    func deleteCommunity(communityId: String) async throws {
        let communityRef = db.collection("communities").document(communityId)
        guard !AppConfig.serverFunctionsEnabled else {
            try await communityRef.delete()
            return
        }

        if let channels = try? await communityRef.collection("channels").getDocuments() {
            for channel in channels.documents {
                await deleteCollection(channel.reference.collection("messages"))
                await deleteCollection(channel.reference.collection("typing"))
                try? await channel.reference.delete()
            }
        }
        if let courses = try? await communityRef.collection("courses").getDocuments() {
            for course in courses.documents {
                await deleteCollection(course.reference.collection("lessons"))
                try? await course.reference.delete()
            }
        }
        if let events = try? await communityRef.collection("events").getDocuments() {
            for event in events.documents {
                await deleteCollection(event.reference.collection("rsvps"))
                try? await event.reference.delete()
            }
        }
        for name in ["rules", "bans", "traderStats"] {
            await deleteCollection(communityRef.collection(name))
        }
        await deleteCollection(db.collection("communityInvites").whereField("communityId", isEqualTo: communityId))

        // Members last among the children: the owner's own member doc goes too.
        await deleteCollection(communityRef.collection("members"))

        if let userId = Auth.auth().currentUser?.uid {
            try? await db.collection("users").document(userId)
                .updateData(["communityIds": FieldValue.arrayRemove([communityId])])
        }
        try await communityRef.delete()
    }

    /// Deletes every document a query returns, 300 at a time. Errors stop quietly.
    private func deleteCollection(_ query: Query) async {
        while true {
            guard let snapshot = try? await query.limit(to: 300).getDocuments(),
                  !snapshot.documents.isEmpty else { return }
            let batch = db.batch()
            snapshot.documents.forEach { batch.deleteDocument($0.reference) }
            do {
                try await batch.commit()
            } catch {
                return
            }
            if snapshot.documents.count < 300 { return }
        }
    }

    /// The biggest public communities. Private communities never appear in lists.
    func getCommunities(limit: Int = 20) async throws -> [Community] {
        let snapshot = try await db.collection("communities")
            .whereField("isPrivate", isEqualTo: false)
            .order(by: "memberCount", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            try? Community.fromFirestore(data: document.data(), id: document.documentID)
        }
    }

    /// The communities in the user's `communityIds`, each read by id. A query can't be used:
    /// the rules allow a private community only after checking the reader's member doc, which
    /// Firestore can only do one document at a time. Ones that are gone or no longer readable
    /// are left out; it throws only when every read fails.
    func getUserCommunities(userId: String) async throws -> [Community] {
        let user = try await getUserById(userId: userId)
        guard let communityIds = user?.communityIds, !communityIds.isEmpty else { return [] }
        let ids = Array(Set(communityIds.filter { !$0.isEmpty }))

        let results = await withTaskGroup(of: Result<Community?, Error>.self) { group in
            for id in ids {
                group.addTask { [db] in
                    do {
                        let doc = try await db.collection("communities").document(id).getDocument()
                        guard let data = doc.data() else { return .success(nil) }
                        return .success(try? Community.fromFirestore(data: data, id: doc.documentID))
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var all: [Result<Community?, Error>] = []
            for await result in group { all.append(result) }
            return all
        }

        var communities: [Community] = []
        var errors: [Error] = []
        for result in results {
            switch result {
            case .success(let community): if let community { communities.append(community) }
            case .failure(let error): errors.append(error)
            }
        }
        if errors.count == results.count, let first = errors.first { throw first }
        return communities
    }

    /// Case-insensitive search over public community names, descriptions, types and tags.
    /// Firestore has no substring search, so this matches locally over the 200 biggest public
    /// communities, kept for two minutes so typing doesn't re-read them.
    func searchCommunities(query: String, limit: Int = 20) async throws -> [Community] {
        let terms = query.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard !terms.isEmpty else { return [] }

        let communities: [Community]
        if let cached = CommunitySearchPool.shared.fresh() {
            communities = cached
        } else {
            communities = try await getCommunities(limit: 200)
            CommunitySearchPool.shared.store(communities)
        }

        func score(_ community: Community) -> Int {
            let name = community.name.lowercased()
            let rest = ([community.description, community.type.displayName] + community.tags).joined(separator: " ").lowercased()
            var total = 0
            for term in terms {
                if name.hasPrefix(term) { total += 3 }
                else if name.contains(term) { total += 2 }
                else if rest.contains(term) { total += 1 }
                else { return 0 } // every term has to match somewhere
            }
            return total
        }

        let ranked = communities
            .map { (community: $0, score: score($0)) }
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.community.memberCount > rhs.community.memberCount
            }
        return Array(ranked.prefix(limit).map { $0.community })
    }

    /// True when a public community already uses this name (any case). Reads at most two docs:
    /// `nameLower` (written on create and rename), and the exact `name` for older communities.
    func isCommunityNameTaken(_ name: String) async throws -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let communities = db.collection("communities").whereField("isPrivate", isEqualTo: false)
        async let byLower = communities
            .whereField("nameLower", isEqualTo: Community.normalizedName(trimmed))
            .limit(to: 1).getDocuments()
        async let byName = communities
            .whereField("name", isEqualTo: trimmed)
            .limit(to: 1).getDocuments()
        let (lower, exact) = try await (byLower, byName)
        return !lower.documents.isEmpty || !exact.documents.isEmpty
    }

    // MARK: - Membership

    /// Joins a community. Banned users can't join. With paid communities on, paid ones are joined
    /// only through Stripe Checkout (the webhook creates the membership); in free mode every community is free.
    /// Private communities need an invite code: the member doc then carries `inviteCode`.
    /// After joining, the owner gets a `member_joined` notification.
    func joinCommunity(communityId: String, userId: String, inviteCode: String? = nil) async throws {
        if try await isUserBanned(communityId: communityId, userId: userId) {
            throw CommunityJoinError.banned
        }
        let communityRef = db.collection("communities").document(communityId)

        // Someone joining with an invite can't read a private community until they're in it
        var communityData: [String: Any] = [:]
        if inviteCode == nil {
            communityData = try await communityRef.getDocument().data() ?? [:]
            if AppConfig.paidCommunitiesEnabled && communityData["isPaid"] as? Bool == true {
                throw CommunityJoinError.requiresSubscription
            }
            if communityData["isPrivate"] as? Bool == true {
                throw CommunityJoinError.needsInvite
            }
        }

        let batch = db.batch()
        var member: [String: Any] = [
            "userId": userId,
            "role": "member",
            "joinedAt": Timestamp(date: Date())
        ]
        if let inviteCode { member["inviteCode"] = inviteCode }
        batch.setData(member, forDocument: communityRef.collection("members").document(userId))
        batch.updateData(["memberCount": FieldValue.increment(Int64(1))], forDocument: communityRef)
        batch.updateData(["communityIds": FieldValue.arrayUnion([communityId])],
                         forDocument: db.collection("users").document(userId))
        try await batch.commit()

        if communityData.isEmpty {
            communityData = (try? await communityRef.getDocument().data()) ?? [:]
        }
        await notifyOwnerOfNewMember(communityId: communityId, communityData: communityData, userId: userId)
    }

    /// Tells the owner someone joined. Best-effort: a failure here never fails the join.
    private func notifyOwnerOfNewMember(communityId: String, communityData: [String: Any], userId: String) async {
        guard let ownerId = communityData["createdBy"] as? String,
              !ownerId.isEmpty, ownerId != userId else { return }
        let communityName = communityData["name"] as? String ?? "your community"

        // The joiner is normally the signed-in user; read their profile only if not
        var username = await MainActor.run { () -> String? in
            guard let user = FirebaseAuthService.shared.currentUser, user.id == userId else { return nil }
            return user.username
        }
        if username == nil {
            username = (try? await db.collection("users").document(userId).getDocument())?.data()?["username"] as? String
        }

        await createNotification(
            to: ownerId,
            type: "member_joined",
            title: "New member",
            body: "\(username ?? "Someone") joined \(communityName)",
            data: ["route": "community", "communityId": communityId]
        )
    }

    func leaveCommunity(communityId: String, userId: String) async throws {
        let batch = db.batch()
        let communityRef = db.collection("communities").document(communityId)
        batch.deleteDocument(communityRef.collection("members").document(userId))
        batch.updateData(["memberCount": FieldValue.increment(Int64(-1))], forDocument: communityRef)
        batch.updateData(["communityIds": FieldValue.arrayRemove([communityId])],
                         forDocument: db.collection("users").document(userId))
        try await batch.commit()
    }

    // MARK: - Invites (private communities)

    /// Creates `communityInvites/{code}` = { communityId, createdBy, createdAt } and returns the code.
    func createCommunityInvite(communityId: String, createdBy: String) async throws -> String {
        let code = CommunityInvite.randomCode()
        try await db.collection("communityInvites").document(code).setData([
            "communityId": communityId,
            "createdBy": createdBy,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return code
    }

    /// Replaces an invite code with a new one; the old code stops working. Invite docs can't be
    /// listed (rules), so the caller passes the code it knows about.
    func regenerateCommunityInvite(communityId: String, userId: String, replacing oldCode: String?) async throws -> String {
        if let oldCode, CommunityInvite.isWellFormed(oldCode) {
            try? await db.collection("communityInvites").document(oldCode).delete()
        }
        return try await createCommunityInvite(communityId: communityId, createdBy: userId)
    }

    /// The community an invite code opens, or nil when the code doesn't exist.
    func communityId(forInviteCode code: String) async throws -> String? {
        let clean = CommunityInvite.normalize(code)
        guard CommunityInvite.isWellFormed(clean) else { return nil }
        let doc = try await db.collection("communityInvites").document(clean).getDocument()
        return doc.data()?["communityId"] as? String
    }

    // MARK: - Members and roles

    /// One page of members, as user profiles: member ids in pages of `pageSize`, then the users
    /// in `in` queries of 30.
    func getCommunityMembers(communityId: String, pageSize: Int = 200) async throws -> [User] {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("members")
            .limit(to: pageSize)
            .getDocuments()
        return try await users(withIds: snapshot.documents.map(\.documentID))
    }

    /// User profiles for a list of ids, in `in` queries of 30. Missing users are left out.
    func users(withIds ids: [String]) async throws -> [User] {
        guard !ids.isEmpty else { return [] }
        var users: [User] = []
        for chunk in ids.chunked(into: 30) {
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            users += snapshot.documents.compactMap { try? User.fromFirestore(data: $0.data(), id: $0.documentID) }
        }
        return users
    }

    /// Roles of the community's staff (admins and moderators), keyed by user id, plus the owner.
    /// Everyone not listed is a plain member (or not a member at all).
    func getCommunityStaffRoles(communityId: String, createdBy: String) async throws -> [String: CommunityRole] {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("members")
            .whereField("role", in: [CommunityRole.admin.rawValue, CommunityRole.moderator.rawValue])
            .limit(to: 100)
            .getDocuments()
        var roles: [String: CommunityRole] = [:]
        for doc in snapshot.documents {
            roles[doc.documentID] = CommunityRole(rawValue: doc.data()["role"] as? String ?? "") ?? .member
        }
        if !createdBy.isEmpty { roles[createdBy] = .owner }
        return roles
    }

    /// Which of `userIds` are members of the community (one read per 30 ids).
    func memberIds(in communityId: String, among userIds: [String]) async -> Set<String> {
        let ids = Array(Set(userIds)).filter { !$0.isEmpty }
        guard !ids.isEmpty else { return [] }
        var found: Set<String> = []
        for chunk in ids.chunked(into: 30) {
            if let snapshot = try? await db.collection("communities").document(communityId)
                .collection("members")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments() {
                found.formUnion(snapshot.documents.map(\.documentID))
            }
        }
        return found
    }

    /// A single user's role, or nil if they aren't a member. The member doc is the source of
    /// truth (not `users.communityIds`); the creator is always the owner.
    func getMemberRole(communityId: String, userId: String, createdBy: String) async throws -> CommunityRole? {
        if userId == createdBy { return .owner }
        let doc = try await db.collection("communities").document(communityId)
            .collection("members").document(userId).getDocument()
        guard doc.exists else { return nil }
        return CommunityRole(rawValue: doc.data()?["role"] as? String ?? "") ?? .member
    }

    func updateCommunityMemberRole(communityId: String, userId: String, role: String) async throws {
        try await db.collection("communities").document(communityId)
            .collection("members").document(userId)
            .updateData(["role": role])
    }

    /// Live view of the signed-in user's own member doc: whether it exists, the role, and a
    /// mute that hasn't run out.
    func listenToOwnMembership(communityId: String, userId: String,
                               onChange: @escaping (_ isMember: Bool, _ role: CommunityRole?, _ mutedUntil: Date?) -> Void) -> ListenerRegistration {
        db.collection("communities").document(communityId)
            .collection("members").document(userId)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                let data = snapshot.data() ?? [:]
                let role = snapshot.exists ? (CommunityRole(rawValue: data["role"] as? String ?? "") ?? .member) : nil
                let until = (data["mutedUntil"] as? Timestamp)?.dateValue()
                onChange(snapshot.exists, role, until.flatMap { $0 > Date() ? $0 : nil })
            }
    }

    // MARK: - Channels

    /// #general (open) and #callouts (admins only). Fixed ids, so creating them twice
    /// can't make duplicates.
    static func defaultChannels(for communityId: String) -> [Channel] {
        var general = Channel(name: "general", type: .text, communityId: communityId, isDefault: true, adminOnly: false)
        general.id = "general"
        var callouts = Channel(name: "callouts", type: .callouts, communityId: communityId, isDefault: true, adminOnly: true)
        callouts.id = "callouts"
        return [general, callouts]
    }

    func createDefaultChannels(for communityId: String) async throws {
        let batch = db.batch()
        for channel in Self.defaultChannels(for: communityId) {
            let ref = db.collection("communities").document(communityId)
                .collection("channels").document(channel.id)
            batch.setData(channel.toFirestore(), forDocument: ref)
        }
        try await batch.commit()
    }

    func getCommunityChannels(communityId: String) async throws -> [Channel] {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("channels")
            .order(by: "createdAt", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            try? Channel.fromFirestore(data: document.data(), id: document.documentID)
        }
    }

    func getChannel(communityId: String, channelId: String) async throws -> Channel? {
        let doc = try await db.collection("communities").document(communityId)
            .collection("channels").document(channelId).getDocument()
        guard let data = doc.data() else { return nil }
        return try? Channel.fromFirestore(data: data, id: doc.documentID)
    }

    func createChannel(_ channel: Channel) async throws {
        let channelRef = db.collection("communities").document(channel.communityId)
            .collection("channels").document(channel.id)

        try await channelRef.setData(channel.toFirestore())
    }

    /// Save a channel's editable fields (name, type, posting permission, icon)
    func updateChannel(_ channel: Channel) async throws {
        try await db.collection("communities").document(channel.communityId)
            .collection("channels").document(channel.id)
            .updateData([
                "name": channel.name,
                "type": channel.type.rawValue,
                "adminOnly": channel.adminOnly,
                "icon": channel.icon.map { $0 as Any } ?? FieldValue.delete()
            ])
    }

    func deleteChannel(channelId: String, communityId: String) async throws {
        let channelRef = db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
        let channelSnapshot = try await channelRef.getDocument()

        if let data = channelSnapshot.data(), data["isDefault"] as? Bool == true {
            throw CommunityError.cannotDeleteDefaultChannel
        }

        // Free mode: its messages go first (best-effort), then the channel
        if !AppConfig.serverFunctionsEnabled {
            await deleteCollection(channelRef.collection("messages"))
            await deleteCollection(channelRef.collection("typing"))
        }
        try await channelRef.delete()
    }

    // MARK: - Messages

    /// Writes a new channel message with `createdAt` set by the server.
    /// - Parameter overrides: top-level fields that replace the encoded ones. Trade shares use it to
    ///   send `tradeShare` with the values exactly as stored on the trade doc (the rules compare them).
    func sendCommunityMessage(_ message: CommunityMessage, overrides: [String: Any] = [:]) async throws {
        let messageRef = channelMessageRef(communityId: message.communityId, channelId: message.channelId,
                                           messageId: message.id)
        let communityRef = db.collection("communities").document(message.communityId)

        var data = message.toFirestore()
        data["createdAt"] = FieldValue.serverTimestamp()
        data.merge(overrides) { _, override in override }

        // Record activity on the community so discovery can surface active communities
        let batch = db.batch()
        batch.setData(data, forDocument: messageRef)
        batch.updateData(["lastActivityDate": FieldValue.serverTimestamp()], forDocument: communityRef)
        try await batch.commit()
    }

    func channelMessageRef(communityId: String, channelId: String, messageId: String) -> DocumentReference {
        db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages").document(messageId)
    }

    // MARK: - Callout follow-ups (docs/backend-contracts.md, section 11)

    /// Posts a `calloutUpdate` message and, for a stop or target move, changes the parent
    /// callout's level in the same batch, so members never see a move that didn't happen.
    /// - Parameter parentLevel: `("stopPrice", 245)` or `("targetPrice", 270)`; nil for trims, adds and notes.
    ///   Written as `callout.<field>` on the parent (firestore.rules `authorTracksCallout`).
    func sendCalloutUpdate(_ message: CommunityMessage, parentLevel: (field: String, value: Double)?) async throws {
        guard let update = message.calloutUpdate else { return }
        let messageRef = channelMessageRef(communityId: message.communityId, channelId: message.channelId,
                                           messageId: message.id)
        let parentRef = channelMessageRef(communityId: message.communityId, channelId: message.channelId,
                                          messageId: update.parentMessageId)
        let communityRef = db.collection("communities").document(message.communityId)

        var data = message.toFirestore()
        data["createdAt"] = FieldValue.serverTimestamp()

        let batch = db.batch()
        if let parentLevel {
            // R9: a level move names the update message that made it (same batch)
            batch.updateData(["callout.\(parentLevel.field)": parentLevel.value,
                              "callout.lastUpdateId": message.id], forDocument: parentRef)
        }
        batch.setData(data, forDocument: messageRef)
        batch.updateData(["lastActivityDate": FieldValue.serverTimestamp()], forDocument: communityRef)
        try await batch.commit()
    }

    /// Every update posted on a callout, oldest first. One-time read for the callout timeline.
    func getCalloutUpdates(communityId: String, channelId: String, parentMessageId: String) async throws -> [CommunityMessage] {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages")
            .whereField("calloutUpdate.parentMessageId", isEqualTo: parentMessageId)
            .limit(to: 100)
            .getDocuments()
        return snapshot.documents
            .compactMap { try? CommunityMessage.fromFirestore(data: $0.data(with: .estimate), id: $0.documentID) }
            .filter { !$0.isDeleted && $0.calloutUpdate != nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// The signed-in user's standing in a community, for deciding where they may post:
    /// their role (nil if not a member) and when a mute ends.
    func memberPostingStatus(communityId: String, userId: String, createdBy: String) async throws -> (role: CommunityRole?, mutedUntil: Date?) {
        if userId == createdBy { return (.owner, nil) }
        let doc = try await db.collection("communities").document(communityId)
            .collection("members").document(userId).getDocument()
        guard doc.exists, let data = doc.data() else { return (nil, nil) }
        let role = CommunityRole(rawValue: data["role"] as? String ?? "") ?? .member
        let mutedUntil = (data["mutedUntil"] as? Timestamp)?.dateValue()
        return (role, mutedUntil)
    }

    /// Live newest `limit` messages of a channel, oldest first. `oldest` is the cursor for
    /// `loadOlderChannelMessages`; `isFull` says the window was full (there may be older ones).
    @discardableResult
    func listenToChannelMessages(communityId: String, channelId: String, limit: Int = 50,
                                 onChange: @escaping (_ messages: [CommunityMessage], _ oldest: DocumentSnapshot?, _ isFull: Bool) -> Void,
                                 onError: @escaping (Error) -> Void = { _ in }) -> ListenerRegistration {
        db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    if let error { onError(error) }
                    return
                }
                let messages = documents.compactMap { document -> CommunityMessage? in
                    try? CommunityMessage.fromFirestore(data: document.data(with: .estimate), id: document.documentID)
                }
                onChange(messages.reversed(), documents.last, documents.count >= limit)
            }
    }

    /// The page of messages before `cursor`, oldest first, with the next cursor.
    func loadOlderChannelMessages(communityId: String, channelId: String, before cursor: DocumentSnapshot,
                                  limit: Int = 50) async throws -> (messages: [CommunityMessage], oldest: DocumentSnapshot?, hasMore: Bool) {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .start(afterDocument: cursor)
            .limit(to: limit)
            .getDocuments()
        let messages = snapshot.documents.compactMap {
            try? CommunityMessage.fromFirestore(data: $0.data(with: .estimate), id: $0.documentID)
        }
        return (messages.reversed(), snapshot.documents.last, snapshot.documents.count >= limit)
    }

    func editCommunityMessage(messageId: String, channelId: String, communityId: String, newContent: String) async throws {
        try await channelMessageRef(communityId: communityId, channelId: channelId, messageId: messageId).updateData([
            "content": newContent,
            "editedAt": FieldValue.serverTimestamp(),
            "isEdited": true
        ])
    }

    // MARK: - Typing indicators

    /// Live list of people typing in a channel: (userId, username, lastSeen). Callers drop entries
    /// older than a few seconds, on a timer, since a stale doc sends no new snapshot.
    func listenToTyping(communityId: String, channelId: String,
                        completion: @escaping ([(userId: String, username: String, lastSeen: Date)]) -> Void) -> ListenerRegistration {
        db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("typing")
            .addSnapshotListener { snapshot, _ in
                let typing = (snapshot?.documents ?? []).compactMap { doc -> (userId: String, username: String, lastSeen: Date)? in
                    let data = doc.data(with: .estimate)
                    guard let username = data["username"] as? String,
                          let lastSeen = (data["lastSeen"] as? Timestamp)?.dateValue() else { return nil }
                    return (doc.documentID, username, lastSeen)
                }
                completion(typing)
            }
    }

    func setUserTyping(userId: String, username: String, channelId: String, communityId: String, isTyping: Bool) async throws {
        let typingRef = db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("typing").document(userId)

        if isTyping {
            try await typingRef.setData([
                "userId": userId,
                "username": username,
                "isTyping": true,
                "lastSeen": Timestamp(date: Date())
            ])
        } else {
            try await typingRef.delete()
        }
    }
}

// MARK: - Search pool

/// The public communities a search last read, kept for two minutes.
final class CommunitySearchPool: @unchecked Sendable {
    static let shared = CommunitySearchPool()
    private let lock = NSLock()
    private var communities: [Community] = []
    private var storedAt: Date = .distantPast

    func fresh() -> [Community]? {
        lock.lock(); defer { lock.unlock() }
        return Date().timeIntervalSince(storedAt) < 120 && !communities.isEmpty ? communities : nil
    }

    func store(_ communities: [Community]) {
        lock.lock(); defer { lock.unlock() }
        self.communities = communities
        storedAt = Date()
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        communities = []
        storedAt = .distantPast
    }
}

// MARK: - Invite codes

enum CommunityInvite {
    /// No 0/O or 1/I, so codes are easy to read out
    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let length = 8

    static func randomCode() -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    static func normalize(_ code: String) -> String {
        code.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    }

    static func isWellFormed(_ code: String) -> Bool {
        code.count == length && code.allSatisfy { alphabet.contains($0) }
    }

    /// Text for the share sheet
    static func shareText(code: String, communityName: String) -> String {
        "Join \(communityName) on Arkad. Open Communities, tap \"Join with invite code\" and enter \(code)."
    }
}

// MARK: - Join errors

enum CommunityJoinError: LocalizedError {
    case banned
    case requiresSubscription
    case needsInvite
    case invalidInvite

    var errorDescription: String? {
        switch self {
        case .banned:
            return "You can't join this community"
        case .requiresSubscription:
            return "This is a paid community. Open it to subscribe."
        case .needsInvite:
            return "This community is private. Ask a member for an invite code."
        case .invalidInvite:
            return "That invite code doesn't work. Check it and try again."
        }
    }
}
