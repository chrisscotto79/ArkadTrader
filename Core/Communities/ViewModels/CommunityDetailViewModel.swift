// File: Core/Communities/ViewModels/CommunityDetailViewModel.swift
// A community's page: membership (from the member doc), channels, joining (free, or with an
// invite code for private communities) and leaving.

import Foundation
import FirebaseFirestore

@MainActor
class CommunityDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var channels: [Channel] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    // User & Community State
    @Published var community: Community?
    @Published var userRole: String = "member"
    @Published var isUserMember = false
    @Published var canManageChannels = false
    /// When the current user joined, read from communities/{id}/members/{uid}
    @Published var memberSince: Date?
    /// True once membership has been read, so locked states don't flash while loading
    @Published private(set) var didLoadMembership = false
    @Published private(set) var isJoining = false

    // Paid communities
    /// The current user's subscription, for members of paid communities (the owner has none)
    @Published var subscription: MemberSubscription?
    /// True when the current user is banned from this community
    @Published var isBanned = false
    /// Rules, loaded for the paid preview that non-members see
    @Published var rules: [CommunityRule] = []

    // MARK: - Private Properties
    private let firebaseService = FirebaseServices.shared
    private let authService = FirebaseAuthService.shared
    private var errorClearTask: Task<Void, Never>?

    // MARK: - Computed Properties
    var currentUserId: String? {
        return authService.currentUser?.id
    }

    /// Owners, admins and moderators: they write Classroom courses and Events
    /// (`isStaff` in firestore.rules: role level 2 or higher).
    var isStaff: Bool {
        guard isUserMember else { return false }
        return userRole == CommunityRole.owner.rawValue
            || userRole == CommunityRole.admin.rawValue
            || userRole == CommunityRole.moderator.rawValue
    }

    /// Members see the channels. Others only see a free, public community's channels:
    /// paid ones show a preview and private ones are locked.
    var canViewChannels: Bool {
        guard let community else { return false }
        return isUserMember || (!community.requiresSubscription && !community.isPrivate)
    }

    /// A private community the viewer hasn't joined
    var isLockedPrivate: Bool {
        guard let community else { return false }
        return community.isPrivate && didLoadMembership && !isUserMember
    }

    // MARK: - Initialization
    init() {}

    // MARK: - Loading

    /// Re-fetch the community document so edits (name, avatar, banner) show immediately.
    func reloadCommunity() async {
        guard let id = community?.id else { return }
        // Fails once a private community is left or a community is deleted; keep what's shown
        if let snapshot = try? await Firestore.firestore().collection("communities").document(id).getDocument(),
           let data = snapshot.data(),
           let fresh = try? Community.fromFirestore(data: data, id: id) {
            community = fresh
        }
    }

    /// Membership first (it decides whether the channels can be read), then the content.
    func loadCommunityData(community: Community) async {
        self.community = community
        isLoading = true
        errorMessage = ""
        await loadUserState(for: community)
        await loadContent(for: community)
        isLoading = false
    }

    /// Channels when the viewer can read them; rules for the paid preview
    private func loadContent(for community: Community) async {
        if canViewChannels {
            await loadChannels(for: community.id)
        } else {
            channels = []
        }
        if community.requiresSubscription && !isUserMember {
            rules = (try? await CommunityFirebaseService.shared.getCommunityRules(communityId: community.id)) ?? []
        }
    }

    /// Re-reads membership and the content it unlocks (after subscribing or managing a subscription)
    func refreshAfterSubscriptionChange() async {
        await reloadCommunity()
        guard let community else { return }
        await loadUserState(for: community)
        await loadContent(for: community)
    }

    /// Creates #general and #callouts (fixed ids, so never twice) with a short welcome in each.
    func setupDefaultChannels() async {
        guard let community, let currentUser = authService.currentUser else { return }
        do {
            try await firebaseService.createDefaultChannels(for: community.id)
            let defaults = FirebaseServices.defaultChannels(for: community.id)
            try? await sendWelcomeMessages(to: community, channels: defaults, user: currentUser)
            await loadChannels(for: community.id)
        } catch {
            handleError(error, context: "setting up default channels")
        }
    }

    /// Send welcome messages to new channels
    private func sendWelcomeMessages(to community: Community, channels: [Channel], user: User) async throws {
        if let generalChannel = channels.first(where: { $0.name == "general" }) {
            let welcomeMessage = CommunityMessage(
                content: "Welcome to \(community.name)! #general is open to every member, so say hello and share ideas.",
                authorId: user.id,
                authorUsername: user.username,
                channelId: generalChannel.id,
                communityId: community.id
            )
            try await firebaseService.sendCommunityMessage(welcomeMessage)
        }

        if let calloutsChannel = channels.first(where: { $0.name == "callouts" }) {
            let instructionsMessage = CommunityMessage(
                content: "#callouts is for trade ideas. Only admins can post here: tap the megaphone button next to the message box to share a callout with its entry, stop and target. Members can tap \"Track in Portfolio\" on a callout to add it to their own trades.",
                authorId: user.id,
                authorUsername: user.username,
                channelId: calloutsChannel.id,
                communityId: community.id
            )
            try await firebaseService.sendCommunityMessage(instructionsMessage)
        }
    }

    // MARK: - Joining and leaving

    /// Join a free, public community
    func joinCommunity() {
        guard let community, let userId = currentUserId, !isJoining else { return }
        isJoining = true

        Task {
            defer { isJoining = false }
            do {
                try await firebaseService.joinCommunity(communityId: community.id, userId: userId)
                await didJoin(community)

                if authService.currentUser?.username != nil {
                    try? await authService.createActivity(
                        userId: userId,
                        type: .joinedCommunity,
                        content: "Joined \(community.name)",
                        relatedId: community.id
                    )
                }
            } catch let error as CommunityJoinError {
                HapticManager.shared.notification(type: .error)
                if case .banned = error { isBanned = true }
                errorMessage = error.errorDescription ?? ""
            } catch {
                HapticManager.shared.notification(type: .error)
                handleError(error, context: "joining community")
            }
        }
    }

    /// Join this (private) community with an invite code. A code for another community is refused.
    func joinWithInviteCode(_ code: String) async throws {
        guard let community, let userId = currentUserId else { throw CommunityError.noPermission }
        let clean = CommunityInvite.normalize(code)
        guard let codeCommunityId = try await firebaseService.communityId(forInviteCode: clean),
              codeCommunityId == community.id else {
            throw CommunityJoinError.invalidInvite
        }
        try await firebaseService.joinCommunity(communityId: community.id, userId: userId, inviteCode: clean)
        await didJoin(community)
    }

    private func didJoin(_ community: Community) async {
        HapticManager.shared.notification(type: .success)
        isUserMember = true
        userRole = CommunityRole.member.rawValue
        memberSince = Date()
        isBanned = false
        await reloadCommunity()
        await loadContent(for: self.community ?? community)
    }

    /// Leave the community
    func leaveCommunity() {
        guard let community, let userId = currentUserId else { return }

        Task {
            do {
                try await firebaseService.leaveCommunity(communityId: community.id, userId: userId)
                isUserMember = false
                userRole = CommunityRole.member.rawValue
                canManageChannels = false
                memberSince = nil
                subscription = nil
                await loadContent(for: community)
            } catch {
                handleError(error, context: "leaving community")
            }
        }
    }

    // MARK: - Channels

    /// Reload the channel list (after a channel is created or edited)
    func reloadChannels() async {
        guard let communityId = community?.id, canViewChannels else { return }
        await loadChannels(for: communityId)
    }

    /// The channel a notification points at, from the list or read directly
    func channel(withId channelId: String) async -> Channel? {
        if let channel = channels.first(where: { $0.id == channelId }) { return channel }
        guard let communityId = community?.id, canViewChannels else { return nil }
        return try? await firebaseService.getChannel(communityId: communityId, channelId: channelId)
    }

    /// #general first, then #callouts, then the rest A-Z
    private func loadChannels(for communityId: String) async {
        do {
            let loadedChannels = try await firebaseService.getCommunityChannels(communityId: communityId)
            channels = loadedChannels.sorted { channel1, channel2 in
                if channel1.isDefault != channel2.isDefault {
                    return channel1.isDefault
                }
                if channel1.isDefault {
                    if channel1.name == "general" { return true }
                    if channel2.name == "general" { return false }
                }
                return channel1.name < channel2.name
            }
        } catch {
            handleError(error, context: "loading channels")
        }
    }

    /// Delete a channel (if user has permission and it's not default)
    func deleteChannel(_ channel: Channel) async throws {
        guard canManageChannels else {
            throw CommunityError.noPermission
        }
        guard !channel.isDefault else {
            throw CommunityError.cannotDeleteDefaultChannel
        }
        try await firebaseService.deleteChannel(channelId: channel.id, communityId: channel.communityId)
        channels.removeAll { $0.id == channel.id }
    }

    // MARK: - Membership

    /// Membership comes from the member doc (communities/{id}/members/{uid}); the owner always counts.
    private func loadUserState(for community: Community) async {
        defer { didLoadMembership = true }
        guard let userId = currentUserId else {
            isUserMember = false
            userRole = CommunityRole.member.rawValue
            canManageChannels = false
            subscription = nil
            return
        }

        let isOwner = community.createdBy == userId
        let memberData = await loadMemberData(communityId: community.id, userId: userId)
        isUserMember = isOwner || memberData != nil

        if isUserMember {
            let storedRole = CommunityRole(rawValue: memberData?["role"] as? String ?? "") ?? .member
            let role: CommunityRole = isOwner ? .owner : storedRole
            userRole = role.rawValue
            canManageChannels = role == .owner || role == .admin
            memberSince = (memberData?["joinedAt"] as? Timestamp)?.dateValue()
            // Free mode has no subscriptions, so a leftover subscription field never shows
            subscription = AppConfig.paidCommunitiesEnabled ? memberData.flatMap { MemberSubscription(data: $0) } : nil
            isBanned = false
        } else {
            userRole = CommunityRole.member.rawValue
            canManageChannels = false
            memberSince = nil
            subscription = nil
            isBanned = (try? await firebaseService.isUserBanned(communityId: community.id, userId: userId)) ?? false
        }
    }

    /// The member document, or nil if it's missing or can't be read
    private func loadMemberData(communityId: String, userId: String) async -> [String: Any]? {
        let doc = try? await Firestore.firestore()
            .collection("communities").document(communityId)
            .collection("members").document(userId)
            .getDocument()
        return doc?.data()
    }

    // MARK: - Errors

    /// Shows a friendly message for a few seconds
    private func handleError(_ error: Error, context: String) {
        let message = "Error \(context): \(getFriendlyErrorMessage(error))"
        errorMessage = message
        errorClearTask?.cancel()
        errorClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, self?.errorMessage == message else { return }
            self?.errorMessage = ""
        }
    }

    /// Convert technical errors to user-friendly messages
    private func getFriendlyErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain {
            switch FirestoreErrorCode.Code(rawValue: nsError.code) {
            case .permissionDenied: return "You don't have permission for this action"
            case .unavailable, .deadlineExceeded: return "Check your internet connection"
            case .notFound: return "Community or channel not found"
            default: break
            }
        }
        if nsError.domain == NSURLErrorDomain {
            return "Check your internet connection"
        }
        return "Something went wrong. Please try again."
    }

    func clearError() {
        errorMessage = ""
    }
}

// MARK: - Community Errors
enum CommunityError: LocalizedError {
    case noCommunity
    case noPermission
    case cannotDeleteDefaultChannel
    case invalidChannelName
    case channelAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .noCommunity:
            return "Community not found"
        case .noPermission:
            return "You don't have permission to perform this action"
        case .cannotDeleteDefaultChannel:
            return "Default channels cannot be deleted"
        case .invalidChannelName:
            return "Invalid channel name"
        case .channelAlreadyExists:
            return "A channel with this name already exists"
        }
    }
}
