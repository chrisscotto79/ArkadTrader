// File: Core/Communities/Services/CommunityFirebaseService.swift
// Community data for the community screens: discovery, membership, members with roles,
// rules and validation. Writes go through FirebaseServices+Communities.

import Foundation
import FirebaseFirestore

@MainActor
class CommunityFirebaseService: ObservableObject {
    // MARK: - Singleton
    static let shared = CommunityFirebaseService()

    // MARK: - Dependencies
    let firebaseService = FirebaseServices.shared
    let authService = FirebaseAuthService.shared

    init() {}

    // MARK: - Community CRUD

    func createCommunity(_ community: Community) async throws {
        try await firebaseService.createCommunity(community)
        CommunitySearchPool.shared.clear()
    }

    /// Saves name, description and privacy only
    func updateCommunity(_ community: Community) async throws {
        try await firebaseService.updateCommunity(community)
        CommunitySearchPool.shared.clear()
    }

    /// Saves only the fields passed in (a rename also updates `nameLower`)
    func updateCommunityDetails(communityId: String, name: String?, description: String?, isPrivate: Bool?) async throws {
        try await firebaseService.updateCommunityDetails(
            communityId: communityId, name: name, description: description, isPrivate: isPrivate
        )
        CommunitySearchPool.shared.clear()
    }

    func deleteCommunity(communityId: String) async throws {
        try await firebaseService.deleteCommunity(communityId: communityId)
        CommunitySearchPool.shared.clear()
    }

    // MARK: - Loading

    /// The biggest public communities, for Discover (one query; filters are applied on the phone)
    func loadDiscoveryCommunities(limit: Int = 100) async throws -> [Community] {
        try await firebaseService.getCommunities(limit: limit)
    }

    /// The user's communities (from `communityIds`, read by id)
    func loadUserCommunities(userId: String) async throws -> [Community] {
        try await firebaseService.getUserCommunities(userId: userId)
    }

    /// Communities created by the user
    func loadUserCreatedCommunities(userId: String) async throws -> [Community] {
        let userCommunities = try await firebaseService.getUserCommunities(userId: userId)
        return userCommunities.filter { $0.createdBy == userId }
    }

    /// Reads the community document directly, so private communities work for their members.
    func getSingleCommunity(communityId: String) async throws -> Community {
        let snapshot = try await Firestore.firestore().collection("communities").document(communityId).getDocument()
        guard let data = snapshot.data() else {
            throw CommunityError.noCommunity
        }
        return try Community.fromFirestore(data: data, id: communityId)
    }

    // MARK: - Membership

    func joinCommunity(communityId: String, userId: String, inviteCode: String? = nil) async throws {
        try await firebaseService.joinCommunity(communityId: communityId, userId: userId, inviteCode: inviteCode)
    }

    func leaveCommunity(communityId: String, userId: String) async throws {
        try await firebaseService.leaveCommunity(communityId: communityId, userId: userId)
    }

    /// Joins the community an invite code belongs to and returns it.
    func joinWithInviteCode(_ code: String, userId: String) async throws -> Community {
        let clean = CommunityInvite.normalize(code)
        guard let communityId = try await firebaseService.communityId(forInviteCode: clean) else {
            throw CommunityJoinError.invalidInvite
        }
        // Already a member: just open it
        if let existing = try? await getSingleCommunity(communityId: communityId),
           (try? await firebaseService.getMemberRole(communityId: communityId, userId: userId,
                                                     createdBy: existing.createdBy)) != nil {
            return existing
        }
        try await firebaseService.joinCommunity(communityId: communityId, userId: userId, inviteCode: clean)
        return try await getSingleCommunity(communityId: communityId)
    }

    /// One page of members with their roles, `pageSize` at a time. User profiles are read in
    /// `in` queries of 30, not one read per member.
    func getMembersPage(
        communityId: String,
        createdBy: String,
        after cursor: DocumentSnapshot? = nil,
        pageSize: Int = 100
    ) async throws -> (members: [CommunityMemberWithRole], cursor: DocumentSnapshot?, hasMore: Bool) {
        var query: Query = Firestore.firestore().collection("communities").document(communityId)
            .collection("members")
            .order(by: FieldPath.documentID())
            .limit(to: pageSize)
        if let cursor { query = query.start(afterDocument: cursor) }
        let snapshot = try await query.getDocuments()

        let ids = snapshot.documents.map(\.documentID)
        let users = try await firebaseService.users(withIds: ids)
        let usersById = Dictionary(users.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let members = snapshot.documents.map { document -> CommunityMemberWithRole in
            let userId = document.documentID
            let data = document.data()
            let storedRole = CommunityRole(rawValue: data["role"] as? String ?? "") ?? .member
            let role: CommunityRole = userId == createdBy ? .owner : storedRole
            let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue() ?? Date()
            guard let user = usersById[userId] else {
                // Deleted account, or a profile that can't be read
                return CommunityMemberWithRole(userId: userId, username: "", fullName: "Unknown member",
                                               role: role, joinedAt: joinedAt)
            }
            return CommunityMemberWithRole(userId: userId, username: user.username, fullName: user.fullName,
                                           role: role, joinedAt: joinedAt,
                                           profileImageUrl: user.profileImageUrl, isVerified: user.isVerified)
        }
        return (members, snapshot.documents.last, snapshot.documents.count >= pageSize)
    }

    /// Change a member's role. Only the owner can do this, and the owner's own role can't change.
    func updateMemberRole(communityId: String, createdBy: String, userId: String, newRole: CommunityRole) async throws {
        guard let currentUser = authService.currentUser, createdBy == currentUser.id,
              userId != createdBy, newRole != .owner else {
            throw CommunityError.noPermission
        }
        try await firebaseService.updateCommunityMemberRole(
            communityId: communityId,
            userId: userId,
            role: newRole.rawValue
        )
    }

    /// Owners and admins manage a community (rules, channels): the same levels as the rules.
    func canUserManageCommunity(communityId: String, userId: String) async throws -> Bool {
        let community = try await getSingleCommunity(communityId: communityId)
        let role = try await firebaseService.getMemberRole(
            communityId: communityId, userId: userId, createdBy: community.createdBy
        )
        return role == .owner || role == .admin
    }

    // MARK: - Rules

    func deleteCommunityRule(communityId: String, ruleId: String) async throws {
        guard let currentUser = authService.currentUser,
              try await canUserManageCommunity(communityId: communityId, userId: currentUser.id) else {
            throw CommunityError.noPermission
        }

        let ruleRef = Firestore.firestore().collection("communities")
            .document(communityId)
            .collection("rules")
            .document(ruleId)

        // The default financial disclaimer rules can't be deleted
        let ruleDoc = try await ruleRef.getDocument()
        if ruleDoc.data()?["isDefault"] as? Bool == true {
            throw CommunityError.noPermission
        }
        try await ruleRef.delete()
    }

    func getCommunityRules(communityId: String) async throws -> [CommunityRule] {
        let snapshot = try await Firestore.firestore().collection("communities")
            .document(communityId)
            .collection("rules")
            .order(by: "order")
            .getDocuments()

        return snapshot.documents.compactMap { document in
            try? CommunityRule.fromFirestore(data: document.data(), id: document.documentID)
        }
    }

    func addCommunityRule(communityId: String, rule: CommunityRule) async throws {
        guard let currentUser = authService.currentUser,
              try await canUserManageCommunity(communityId: communityId, userId: currentUser.id) else {
            throw CommunityError.noPermission
        }
        try await Firestore.firestore().collection("communities")
            .document(communityId)
            .collection("rules")
            .document(rule.id)
            .setData(rule.toFirestore())
    }

    func createDefaultRules(communityId: String, rules: [CommunityRule]) async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        for rule in rules {
            let ruleRef = db.collection("communities")
                .document(communityId)
                .collection("rules")
                .document(rule.id)
            batch.setData(rule.toFirestore(), forDocument: ruleRef)
        }
        try await batch.commit()
    }

    // MARK: - Search & sorting

    /// Public communities matching the query
    func searchCommunities(query: String) async throws -> [Community] {
        try await firebaseService.searchCommunities(query: query)
    }

    /// True when no public community already uses this name (any case)
    func isNameAvailable(_ name: String) async throws -> Bool {
        !(try await firebaseService.isCommunityNameTaken(name))
    }

    func sortCommunities(_ communities: [Community], by sortType: CommunitySortType) -> [Community] {
        switch sortType {
        case .memberCount:
            return communities.sorted { $0.memberCount > $1.memberCount }
        case .newest:
            return communities.sorted { $0.createdAt > $1.createdAt }
        case .alphabetical:
            return communities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .mostActive:
            return communities.sorted {
                ($0.lastActivityDate ?? .distantPast) > ($1.lastActivityDate ?? .distantPast)
            }
        }
    }

    // MARK: - Validation

    func validateCommunityName(_ name: String) -> (isValid: Bool, message: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            return (false, "Community name is required")
        }
        if trimmedName.count < 3 {
            return (false, "Community name must be at least 3 characters")
        }
        if trimmedName.count > 30 {
            return (false, "Community name must be less than 30 characters")
        }
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        if trimmedName.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return (false, "Community name can only contain letters, numbers, spaces, hyphens, and underscores")
        }
        return (true, "")
    }

    func validateCommunityDescription(_ description: String) -> (isValid: Bool, message: String) {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedDescription.isEmpty {
            return (false, "Community description is required")
        }
        if trimmedDescription.count < 10 {
            return (false, "Description must be at least 10 characters")
        }
        if trimmedDescription.count > 280 {
            return (false, "Description must be less than 280 characters")
        }
        return (true, "")
    }

    /// Each person can own up to two communities
    func canUserCreateCommunity(userId: String) async throws -> (canCreate: Bool, message: String) {
        let ownedCommunities = try await loadUserCreatedCommunities(userId: userId)
        let maxCommunities = 2

        if ownedCommunities.count >= maxCommunities {
            return (false, "You've reached the maximum of \(maxCommunities) communities. Delete or transfer ownership of an existing community to create a new one.")
        }
        return (true, "")
    }

    func handleCommunityError(_ error: Error) -> String {
        "An error occurred: \(error.localizedDescription)"
    }
}

enum CommunitySortType: CaseIterable {
    case memberCount
    case newest
    case alphabetical
    case mostActive

    var displayName: String {
        switch self {
        case .memberCount: return "Most Members"
        case .newest: return "Newest"
        case .alphabetical: return "A-Z"
        case .mostActive: return "Most Active"
        }
    }
}
