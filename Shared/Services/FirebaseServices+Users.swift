// File: Shared/Services/FirebaseServices+Users.swift
// Profiles, usernames and account deletion.
//
//   users/{uid}                  public profile (anyone signed in can read it)
//   users/{uid}/private/profile  owner-only: email, startingCapital, experienceLevel,
//                                interests, notificationPrefs
//   usernames/{username}         { uid, createdAt }: one doc per lowercase username, written in
//                                the same batch as the users/{uid} change that takes it

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// The profile fields Edit Profile can change. nil means "leave as it is".
struct ProfileChanges {
    var fullName: String?
    /// An empty string removes the bio
    var bio: String?
    var username: String?
    var profileImageUrl: String?
}

extension FirebaseServices {
    // MARK: - References

    func userRef(_ userId: String) -> DocumentReference {
        db.collection("users").document(userId)
    }

    func privateProfileRef(_ userId: String) -> DocumentReference {
        userRef(userId).collection("private").document("profile")
    }

    func usernameRef(_ username: String) -> DocumentReference {
        db.collection("usernames").document(Self.normalizedUsername(username))
    }

    /// Usernames are stored and compared trimmed and lowercased.
    static func normalizedUsername(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func usernameClaim(for userId: String) -> [String: Any] {
        ["uid": userId, "createdAt": FieldValue.serverTimestamp()]
    }

    // MARK: - Create

    /// A new account: the public profile, the private profile and the username claim in one
    /// batch. The rules refuse the batch if the username is already claimed.
    func createUser(_ user: User) async throws {
        let batch = db.batch()
        batch.setData(user.toFirestore(), forDocument: userRef(user.id))
        batch.setData(user.privateFirestore(), forDocument: privateProfileRef(user.id))
        batch.setData(usernameClaim(for: user.id), forDocument: usernameRef(user.username))
        try await batch.commit()
    }

    // MARK: - Read

    /// Someone's public profile.
    func getUserById(userId: String) async throws -> User? {
        let document = try await userRef(userId).getDocument()
        guard let data = document.data() else { return nil }
        return try User.fromFirestore(data: data, id: userId)
    }

    /// The signed-in user's full profile: the public doc plus the private one, with the email
    /// from Firebase Auth. Also tidies up older accounts (see `upgradeLegacyProfile`).
    /// Returns nil when there's no profile doc.
    func getSignedInProfile(userId: String) async throws -> User? {
        let document = try await userRef(userId).getDocument()
        guard let publicData = document.data() else { return nil }
        var user = try User.fromFirestore(data: publicData, id: userId)

        // Older accounts keep these on the public doc until the upgrade below moves them
        user.applyPrivate(publicData)

        let privateData: [String: Any]?
        do {
            privateData = try await privateProfileRef(userId).getDocument().data() ?? [:]
        } catch {
            privateData = nil
        }
        if let privateData {
            user.applyPrivate(privateData)
        }
        if let email = Auth.auth().currentUser?.email {
            user.email = email
        }

        await upgradeLegacyProfile(userId: userId, publicData: publicData, privateData: privateData)
        return user
    }

    /// One-time and idempotent, on sign-in:
    /// - moves owner-only fields still on the public doc into the private doc, then deletes
    ///   them from the public doc (only when the private doc could be read, so nothing newer
    ///   is overwritten)
    /// - claims usernames/{username} for accounts created before claims existed, lowercasing
    ///   the stored username in the same batch if needed.
    /// Failures are ignored; it runs again next sign-in.
    private func upgradeLegacyProfile(userId: String, publicData: [String: Any], privateData: [String: Any]?) async {
        let legacyKeys = User.privateFieldNames.filter { publicData[$0] != nil }
        if let privateData, !legacyKeys.isEmpty {
            let batch = db.batch()
            var copy: [String: Any] = [:]
            for key in legacyKeys where privateData[key] == nil {
                copy[key] = publicData[key]
            }
            if !copy.isEmpty {
                batch.setData(copy, forDocument: privateProfileRef(userId), merge: true)
            }
            var removals: [String: Any] = [:]
            for key in legacyKeys {
                removals[key] = FieldValue.delete()
            }
            batch.updateData(removals, forDocument: userRef(userId))
            try? await batch.commit()
        }

        guard let stored = publicData["username"] as? String, !stored.isEmpty else { return }
        let name = Self.normalizedUsername(stored)
        guard let claim = try? await usernameRef(name).getDocument(), !claim.exists else { return }
        let batch = db.batch()
        batch.setData(usernameClaim(for: userId), forDocument: usernameRef(name))
        if stored != name {
            batch.updateData(["username": name, "updatedAt": FieldValue.serverTimestamp()], forDocument: userRef(userId))
        }
        try? await batch.commit()
    }

    // MARK: - Usernames

    /// Whether `username` is free for `userId` (your own username counts as free).
    /// Checks the claim doc, and for accounts from before claims, the profiles themselves.
    func isUsernameAvailable(_ username: String, for userId: String?) async throws -> Bool {
        let name = Self.normalizedUsername(username)
        guard !name.isEmpty else { return false }

        let claim = try await usernameRef(name).getDocument()
        if claim.exists {
            return userId != nil && claim.get("uid") as? String == userId
        }

        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: name)
            .limit(to: 2)
            .getDocuments()
        return snapshot.documents.allSatisfy { $0.documentID == userId }
    }

    // MARK: - Update

    /// Writes only the edited fields (and `updatedAt`), so counts, communities and stats that
    /// changed elsewhere aren't overwritten with stale copies. A new username is claimed and
    /// the old claim released in the same batch. Throws `AuthError.usernameTaken`.
    func updateProfile(userId: String, currentUsername: String, changes: ProfileChanges) async throws {
        let batch = db.batch()
        var data: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]

        if let fullName = changes.fullName {
            data["fullName"] = fullName
        }
        if let bio = changes.bio {
            data["bio"] = bio.isEmpty ? FieldValue.delete() : bio
        }
        if let profileImageUrl = changes.profileImageUrl {
            data["profileImageUrl"] = profileImageUrl
        }

        if let requested = changes.username {
            let newName = Self.normalizedUsername(requested)
            if newName != currentUsername {
                data["username"] = newName
                try await addUsernameClaim(newName, userId: userId, to: batch)

                // Release the old claim (a case-only rename keeps the same one)
                let oldName = Self.normalizedUsername(currentUsername)
                if oldName != newName, !oldName.isEmpty,
                   let old = try? await usernameRef(oldName).getDocument(),
                   old.exists, old.get("uid") as? String == userId {
                    batch.deleteDocument(old.reference)
                }
            }
        }

        batch.updateData(data, forDocument: userRef(userId))
        try await batch.commit()
    }

    /// Adds a create of usernames/{name} to `batch`, unless you already hold it.
    private func addUsernameClaim(_ name: String, userId: String, to batch: WriteBatch) async throws {
        let claim = try await usernameRef(name).getDocument()
        if claim.exists {
            guard claim.get("uid") as? String == userId else { throw AuthError.usernameTaken }
            return
        }
        // Accounts from before claims
        let taken = try await db.collection("users")
            .whereField("username", isEqualTo: name)
            .limit(to: 2)
            .getDocuments()
            .documents.contains { $0.documentID != userId }
        guard !taken else { throw AuthError.usernameTaken }
        batch.setData(usernameClaim(for: userId), forDocument: usernameRef(name))
    }

    /// Merges fields into the owner-only users/{uid}/private/profile.
    func updatePrivateProfile(userId: String, fields: [String: Any]) async throws {
        try await privateProfileRef(userId).setData(fields, merge: true)
    }

    /// The trades P&L and win rate (0...100) shown on the public profile.
    func updateUserStats(userId: String, totalProfitLoss: Double, winRate: Double) async throws {
        try await userRef(userId).updateData([
            "totalProfitLoss": totalProfitLoss,
            "winRate": winRate,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Owner-only, so it lives in the private doc.
    func updateUserStartingCapital(userId: String, startingCapital: Double) async throws {
        try await updatePrivateProfile(userId: userId, fields: ["startingCapital": startingCapital])
    }

    // MARK: - Search and discovery

    func searchUsers(query: String, limit: Int = 20) async throws -> [User] {
        let name = Self.normalizedUsername(query)
        let snapshot = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: name)
            .whereField("username", isLessThan: name + "\u{f8ff}")
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            try? User.fromFirestore(data: document.data(), id: document.documentID)
        }
    }

    func getPopularUsers(limit: Int = 20) async throws -> [User] {
        let snapshot = try await db.collection("users")
            .order(by: "followersCount", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            try? User.fromFirestore(data: document.data(), id: document.documentID)
        }
    }

    /// Profiles for a list of ids, 30 per query. Missing and unreadable profiles are skipped;
    /// throws only if every query failed.
    func getUsers(ids: [String]) async throws -> [User] {
        let unique = Array(Set(ids.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [] }

        var users: [User] = []
        var lastError: Error?
        var succeeded = false
        for chunk in unique.chunked(into: 30) {
            do {
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                succeeded = true
                users += snapshot.documents.compactMap { document in
                    try? User.fromFirestore(data: document.data(), id: document.documentID)
                }
            } catch {
                lastError = error
            }
        }
        if !succeeded, let lastError { throw lastError }
        return users
    }

    // MARK: - Account deletion (free mode)

    /// `users/{uid}` subcollections removed when an account is deleted. The first nine are the
    /// ones in docs/backend-contracts.md, section 0; the rest are older per-user lists the app
    /// also writes (likes, bookmarks, comment likes). `private` goes last, with the profile.
    static let accountSubcollections = [
        "watchlist", "priceAlerts", "learnProgress", "callouts", "fcmTokens",
        "following", "followers", "blockedUsers", "reportedPosts",
        "likedPosts", "likes", "bookmarks", "commentLikes", "communityLessonProgress"
    ]

    /// Marks the account as being deleted: deletionRequests/{uid} = { requestedAt }. The rules
    /// then let the owner delete trades that are otherwise locked. Created once, never changed.
    func createDeletionRequest(userId: String) async throws {
        let reference = db.collection("deletionRequests").document(userId)
        let existing = try? await reference.getDocument()
        if existing?.exists == true { return }
        do {
            try await reference.setData(["requestedAt": FieldValue.serverTimestamp()])
        } catch {
            // A retry after an earlier attempt: it may exist even though it couldn't be read.
            if existing == nil { return }
            throw error
        }
    }

    /// Free mode (docs/backend-contracts.md, section 0): removes what the user created, after
    /// `createDeletionRequest` and before FirebaseAuthService deletes the profile. Each step is
    /// separate so one failure doesn't stop the rest. Community chat messages stay.
    ///
    /// Runs while `users/{uid}` still exists: unfollowing and leaving update its counts and
    /// `communityIds`, and those updates fail on a deleted document.
    /// Returns what couldn't be removed, in words for the user (empty when everything went).
    func deleteAccountData(userId: String) async -> [String] {
        var failed: [String] = []
        func step(_ label: String, _ work: () async throws -> Void) async {
            do {
                try await work()
            } catch {
                #if DEBUG
                print("Account deletion: \(label) failed: \(error.localizedDescription)")
                #endif
                if !failed.contains(label) { failed.append(label) }
            }
        }

        let profile = try? await getUserById(userId: userId)

        // Your posts, with their comments and likes
        await step("posts") {
            let snapshot = try await db.collection("posts")
                .whereField("authorId", isEqualTo: userId)
                .getDocuments()
            var failures = 0
            for document in snapshot.documents {
                do {
                    try await deletePost(postId: document.documentID)
                } catch {
                    // The comments or likes couldn't all be removed; remove the post itself.
                    do { try await document.reference.delete() } catch { failures += 1 }
                }
            }
            if failures > 0 { throw AccountDeletionError.partial }
        }

        // Your comments and likes on other people's posts
        await step("comments on other posts") {
            try await deleteCommentsOnOthersPosts(userId: userId)
        }
        await step("likes") {
            try await deleteLikesOnOthersContent(userId: userId)
        }

        // Follows in both directions, through unfollow so everyone's counts stay right
        await step("follows") {
            var failures = 0
            for followedId in try await getUserFollowing(userId: userId) {
                do { try await unfollowUser(userId: followedId, followerId: userId) } catch { failures += 1 }
            }
            for followerId in try await getUserFollowers(userId: userId) {
                do { try await unfollowUser(userId: userId, followerId: followerId) } catch { failures += 1 }
            }
            if failures > 0 { throw AccountDeletionError.partial }
        }

        // Communities: leave the ones you joined, delete the ones you own
        var ownedIds: [String] = []
        await step("communities") {
            ownedIds = try await db.collection("communities")
                .whereField("createdBy", isEqualTo: userId)
                .getDocuments()
                .documents.map(\.documentID)
        }
        for communityId in (profile?.communityIds ?? []) where !ownedIds.contains(communityId) {
            // The community leaderboard entry first: the rules allow it only while a member
            await step("communities") {
                try await db.collection("communities").document(communityId)
                    .collection("traderStats").document(userId)
                    .delete()
            }
            await step("communities") {
                try await leaveCommunity(communityId: communityId, userId: userId)
            }
        }
        for communityId in ownedIds {
            // Its photos first (images/community_*_{cid}), while the community still exists
            await step("community photos") {
                try await ImageStore.shared.deleteImage(id: ImageStore.communityAvatarId(communityId: communityId))
                try await ImageStore.shared.deleteImage(id: ImageStore.communityBannerId(communityId: communityId))
            }
            await step("communities you own") {
                try await deleteCommunity(communityId: communityId)
            }
        }

        // Everything under users/{uid} (except the private profile, removed with the profile)
        let account = userRef(userId)
        for name in Self.accountSubcollections {
            await step("saved lists and settings") {
                let snapshot = try await account.collection(name).getDocuments()
                try await deleteDocuments(snapshot.documents.map(\.reference))
            }
        }

        // Linked brokerages: the Worker removes the SnapTrade user and the brokerage docs,
        // which the rules don't let the app delete. Imported trades go with the trades below.
        if AppConfig.brokerageLinkingEnabled {
            await step("linked brokerages") {
                try await BrokerageService.deleteLinkedData()
            }
        }

        // Track record
        await step("track record") {
            try await db.collection("traderStats").document(userId).delete()
        }

        // Your own inbox
        await step("notifications") {
            let snapshot = try await db.collection("notifications")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            try await deleteDocuments(snapshot.documents.map(\.reference))
        }

        // Profile photo in Firestore (images/avatar_{uid})
        await step("profile photo") {
            try await ImageStore.shared.deleteImage(id: ImageStore.avatarId(userId: userId))
        }

        // Legacy profile photo in Cloud Storage, at the path uploadProfileImage used. Only when
        // Storage is available; on the free plan the request would just fail.
        if AppConfig.mediaUploadsEnabled, let url = profile?.profileImageUrl, ImageStore.imageId(from: url) == nil {
            await step("profile photo") {
                try await Storage.storage().reference()
                    .child("profile_images").child("\(userId).jpg")
                    .delete()
            }
        }

        // Trades last: deletionRequests/{uid} exists by now, which the rules need for
        // price-checked trades older than 15 minutes. One at a time so one refusal doesn't
        // block the rest.
        await step("trades") {
            let snapshot = try await db.collection("trades")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            var failures = 0
            for document in snapshot.documents {
                do { try await document.reference.delete() } catch { failures += 1 }
            }
            if failures > 0 { throw AccountDeletionError.partial }
        }

        return failed
    }

    /// The profile docs, deleted last while still signed in: the private profile, the username
    /// claim and users/{uid}. Returns what was there, so it can be put back if Firebase then
    /// refuses to delete the sign-in.
    func deleteProfileDocuments(userId: String, username: String) async -> SavedProfile {
        let claimRef = usernameRef(username)
        let saved = SavedProfile(
            publicData: try? await userRef(userId).getDocument().data(),
            privateData: try? await privateProfileRef(userId).getDocument().data(),
            ownsClaim: (try? await claimRef.getDocument())?.get("uid") as? String == userId,
            username: Self.normalizedUsername(username)
        )

        try? await privateProfileRef(userId).delete()
        if saved.ownsClaim {
            try? await claimRef.delete()
        }
        try? await userRef(userId).delete()
        return saved
    }

    /// Puts the profile docs back after a failed sign-in deletion (best-effort).
    func restoreProfileDocuments(userId: String, saved: SavedProfile) async {
        let batch = db.batch()
        if let publicData = saved.publicData {
            batch.setData(publicData, forDocument: userRef(userId))
        }
        if let privateData = saved.privateData {
            batch.setData(privateData, forDocument: privateProfileRef(userId))
        }
        if saved.ownsClaim {
            batch.setData(usernameClaim(for: userId), forDocument: usernameRef(saved.username))
        }
        try? await batch.commit()
    }

    struct SavedProfile {
        let publicData: [String: Any]?
        let privateData: [String: Any]?
        let ownsClaim: Bool
        let username: String
    }

    enum AccountDeletionError: Error {
        /// Some items in a step couldn't be removed
        case partial
    }

    /// Your comments on other people's posts (collection group `comments`, `authorId == me`).
    /// A top-level comment goes in a batch with its post's `commentsCount - 1` and
    /// `lastCommentId`; replies are deleted on their own, 450 per batch.
    private func deleteCommentsOnOthersPosts(userId: String) async throws {
        let snapshot = try await db.collectionGroup("comments")
            .whereField("authorId", isEqualTo: userId)
            .getDocuments()

        var replies: [DocumentReference] = []
        var failures = 0
        for document in snapshot.documents {
            guard let postRef = document.reference.parent.parent,
                  postRef.parent.collectionID == "posts" else { continue }

            if let parentId = document.get("parentCommentId") as? String, !parentId.isEmpty {
                replies.append(document.reference)
                continue
            }

            let batch = db.batch()
            batch.deleteDocument(document.reference)
            batch.updateData([
                "commentsCount": FieldValue.increment(Int64(-1)),
                "lastCommentId": document.documentID
            ], forDocument: postRef)
            do {
                try await batch.commit()
            } catch {
                // The post may be gone already; then the comment can go on its own.
                do { try await document.reference.delete() } catch { failures += 1 }
            }
        }

        do {
            try await deleteDocuments(replies)
        } catch {
            failures += 1
        }
        if failures > 0 { throw AccountDeletionError.partial }
    }

    /// Your likes on posts and comments (collection group `likes`, `userId == me`), each deleted
    /// in the same batch as its target's `likesCount - 1`. Up to 225 likes (450 writes) per
    /// batch; a refused batch is retried one like at a time. Falls back to
    /// users/{uid}/likedPosts if the collection-group query isn't available.
    private func deleteLikesOnOthersContent(userId: String) async throws {
        var likes: [DocumentReference] = []
        do {
            let snapshot = try await db.collectionGroup("likes")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            likes = snapshot.documents.map(\.reference).filter { reference in
                guard let target = reference.parent.parent else { return false }
                let kind = target.parent.collectionID
                return kind == "posts" || kind == "comments"
            }
        } catch {
            let liked = try await userRef(userId).collection("likedPosts").getDocuments()
            for document in liked.documents {
                let like = db.collection("posts").document(document.documentID)
                    .collection("likes").document(userId)
                // Only real likes, so no count goes down for nothing
                if (try? await like.getDocument())?.exists == true {
                    likes.append(like)
                }
            }
        }

        var failures = 0
        for chunk in likes.chunked(into: 225) {
            let batch = db.batch()
            for like in chunk {
                addLikeRemoval(like, to: batch)
            }
            do {
                try await batch.commit()
            } catch {
                for like in chunk {
                    let single = db.batch()
                    addLikeRemoval(like, to: single)
                    do {
                        try await single.commit()
                    } catch {
                        // The liked post or comment may be gone; then the like can go alone.
                        do { try await like.delete() } catch { failures += 1 }
                    }
                }
            }
        }
        if failures > 0 { throw AccountDeletionError.partial }
    }

    private func addLikeRemoval(_ like: DocumentReference, to batch: WriteBatch) {
        batch.deleteDocument(like)
        if let target = like.parent.parent {
            batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: target)
        }
    }

    /// Deletes documents in batches of 450.
    private func deleteDocuments(_ references: [DocumentReference]) async throws {
        for chunk in references.chunked(into: 450) {
            let batch = db.batch()
            for reference in chunk {
                batch.deleteDocument(reference)
            }
            try await batch.commit()
        }
    }
}
