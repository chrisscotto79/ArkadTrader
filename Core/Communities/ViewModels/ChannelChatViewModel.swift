// File: Core/Communities/ViewModels/ChannelChatViewModel.swift
// A channel's chat: the live newest 50 messages plus older pages, reactions (stored on each
// message), typing, the signed-in user's membership, role and mute, and every write the chat makes.

import Foundation
import Combine
import UIKit
import FirebaseCore
import FirebaseFirestore

@MainActor
class ChannelChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var messages: [CommunityMessage] = [] {
        didSet { rebuildMessageIndex() }
    }
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var canUserPost = true
    @Published var canUserManageChannel = false
    /// The signed-in user has a member doc here. Non-members of a free community can read but not post.
    @Published private(set) var isMember = false
    @Published private(set) var isJoining = false
    /// Roles of the owner and staff, keyed by user id; everyone else is a member
    @Published var memberRoles: [String: CommunityRole] = [:]
    /// Usernames of other people currently typing in this channel
    @Published var typingUsernames: [String] = []
    /// When the current user's mute in this community ends; nil when they aren't muted
    @Published var mutedUntil: Date?
    /// Older pages can be loaded (scrolling to the top)
    @Published private(set) var hasMoreOlder = false
    @Published private(set) var isLoadingOlder = false

    // MARK: - Private Properties
    private var community: Community?
    private var channel: Channel?
    private let firebaseService = FirebaseServices.shared
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    /// Active Firestore listeners; removed in cleanup() and deinit
    private let listeners = ListenerBag()
    /// Loads roles and starts the listeners; cancelled by cleanup()
    private var setupTask: Task<Void, Never>?
    /// Drops stale typing entries every few seconds
    private var typingRefreshTask: Task<Void, Never>?
    private var typingEntries: [(userId: String, username: String, lastSeen: Date)] = []
    /// Last time we told Firestore we're typing (throttles writes)
    private var lastTypingSent: Date?
    /// People the current user has blocked; their messages are hidden
    private let blockStore = BlockStore.shared
    /// Clears `mutedUntil` when the mute runs out while the chat is open
    private var muteExpiryTask: Task<Void, Never>?
    /// Position of each loaded message, by id (for replies and callout updates)
    private var indexById: [String: Int] = [:]
    /// Loaded `calloutUpdate` messages for each callout, oldest first, keyed by the callout's message id
    private(set) var calloutUpdatesByParent: [String: [CommunityMessage]] = [:]

    /// The live window (newest messages) and everything older that's been loaded or scrolled out of it
    private var liveMessages: [CommunityMessage] = []
    private var olderMessages: [String: CommunityMessage] = [:]
    private var olderCursor: DocumentSnapshot?
    /// The signed-in user's role from their member doc (nil when not a member)
    private var ownRole: CommunityRole?

    private static let pageSize = 50
    private static let typingTimeout: TimeInterval = 8

    // MARK: - Computed Properties
    var currentUserId: String? {
        return authService.currentUser?.id
    }

    var currentUsername: String? {
        return authService.currentUser?.username
    }

    /// Muted members can read but not post
    var isMuted: Bool {
        guard let mutedUntil else { return false }
        return mutedUntil > Date()
    }

    /// Owners, admins and moderators can pin, and delete messages of people they outrank
    var canPinMessages: Bool { canUserManageChannel }

    /// Owners, admins and moderators
    var isStaff: Bool { canUserManageChannel }

    /// Game plans: staff anywhere they can post, and anyone who can post in a callouts channel.
    var canPostGamePlan: Bool {
        canUserPost && !isMuted && (isStaff || channel?.type == .callouts)
    }

    /// A loaded message, by id
    func message(withId id: String) -> CommunityMessage? {
        indexById[id].flatMap { $0 < messages.count ? messages[$0] : nil }
    }

    /// The callout a `calloutUpdate` or `calloutResult` message refers to, when it's loaded.
    func parentCallout(of message: CommunityMessage) -> TradeCallout? {
        guard let parentId = message.calloutUpdate?.parentMessageId ?? message.calloutResult?.parentMessageId else { return nil }
        return self.message(withId: parentId)?.callout
    }

    /// Updates posted on a callout that are in the loaded messages, oldest first.
    func calloutUpdates(for messageId: String) -> [CommunityMessage] {
        calloutUpdatesByParent[messageId] ?? []
    }

    private func rebuildMessageIndex() {
        var index: [String: Int] = [:]
        var updates: [String: [CommunityMessage]] = [:]
        for (position, message) in messages.enumerated() {
            index[message.id] = position
            if !message.isDeleted, let parentId = message.calloutUpdate?.parentMessageId {
                updates[parentId, default: []].append(message)
            }
        }
        indexById = index
        calloutUpdatesByParent = updates
    }

    /// Pinned messages, newest pin first
    var pinnedMessages: [CommunityMessage] {
        messages
            .filter { $0.isPinned && !$0.isDeleted }
            .sorted { ($0.pinnedAt ?? $0.createdAt) > ($1.pinnedAt ?? $1.createdAt) }
    }

    // MARK: - Initialization
    init() {
        // Hide someone's messages as soon as they're blocked
        blockStore.$blockedIds
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.publishMessages()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        listeners.removeAll()
    }

    // MARK: - Loading

    /// Load channel data and start listening. Safe to call again (it restarts everything).
    func loadChannelData(community: Community, channel: Channel, isMember: Bool) {
        cleanup()
        self.community = community
        self.channel = channel
        self.isMember = isMember
        if let me = currentUserId, community.createdBy == me {
            ownRole = .owner
        }
        isLoading = liveMessages.isEmpty
        checkUserPermissions()

        setupTask = Task { [weak self] in
            guard let self else { return }
            await self.blockStore.loadIfNeeded()
            guard !Task.isCancelled else { return }
            self.startListeningForMembership()
            self.startListeningForMessages()
            self.startListeningForTyping()
            await self.loadStaffRoles()
        }
    }

    /// Stop every listener and timer (the view disappeared)
    func cleanup() {
        setupTask?.cancel()
        setupTask = nil
        listeners.removeAll()
        muteExpiryTask?.cancel()
        muteExpiryTask = nil
        typingRefreshTask?.cancel()
        typingRefreshTask = nil
        setTyping(false)
    }

    private func startListeningForMessages() {
        guard let community, let channel else { return }
        let listener = firebaseService.listenToChannelMessages(
            communityId: community.id,
            channelId: channel.id,
            limit: Self.pageSize,
            onChange: { [weak self] newMessages, oldest, isFull in
                Task { @MainActor in
                    self?.applyLiveWindow(newMessages, oldest: oldest, isFull: isFull)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.isLoading = false
                    await self?.handleError(error, context: "loading messages")
                }
            }
        )
        listeners.add(listener)
    }

    private func applyLiveWindow(_ newMessages: [CommunityMessage], oldest: DocumentSnapshot?, isFull: Bool) {
        // Messages that slid out of the live window (newer ones arrived) stay on screen
        let newIds = Set(newMessages.map(\.id))
        if isFull {
            for message in liveMessages where !newIds.contains(message.id) {
                olderMessages[message.id] = message
            }
        }
        if olderMessages.isEmpty {
            olderCursor = oldest
            hasMoreOlder = isFull
        }
        liveMessages = newMessages
        isLoading = false
        publishMessages()
    }

    /// Loads the 50 messages before the oldest one on screen.
    func loadOlderMessages() {
        guard let community, let channel, let cursor = olderCursor,
              hasMoreOlder, !isLoadingOlder else { return }
        isLoadingOlder = true
        Task {
            defer { isLoadingOlder = false }
            do {
                let page = try await firebaseService.loadOlderChannelMessages(
                    communityId: community.id, channelId: channel.id, before: cursor, limit: Self.pageSize
                )
                for message in page.messages { olderMessages[message.id] = message }
                if let oldest = page.oldest { olderCursor = oldest }
                hasMoreOlder = page.hasMore && page.oldest != nil
                publishMessages()
            } catch {
                await handleError(error, context: "loading older messages")
            }
        }
    }

    /// Older pages first, then the live window; blocked authors hidden.
    private func publishMessages() {
        let liveIds = Set(liveMessages.map(\.id))
        let older = olderMessages.values
            .filter { !liveIds.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        messages = (older + liveMessages).filter { !blockStore.isBlocked($0.authorId) }
    }

    /// Applies a local change to a message wherever it's held (optimistic updates)
    private func updateLocal(_ id: String, _ change: (inout CommunityMessage) -> Void) {
        if let index = liveMessages.firstIndex(where: { $0.id == id }) {
            change(&liveMessages[index])
        } else if var message = olderMessages[id] {
            change(&message)
            olderMessages[id] = message
        }
        publishMessages()
    }

    // MARK: - Membership

    /// Follows the current user's member doc: membership, role and `mutedUntil`
    private func startListeningForMembership() {
        guard let community, let currentUserId else { return }
        let listener = firebaseService.listenToOwnMembership(communityId: community.id, userId: currentUserId) { [weak self] isMember, role, until in
            Task { @MainActor in
                guard let self else { return }
                self.isMember = isMember || community.createdBy == currentUserId
                self.ownRole = community.createdBy == currentUserId ? .owner : role
                self.applyMute(until: until)
                self.checkUserPermissions()
            }
        }
        listeners.add(listener)
    }

    /// Joins this (free, public) community from the chat's "Join to chat" bar.
    func joinCommunity() async {
        guard let community, let userId = currentUserId, !isJoining else { return }
        isJoining = true
        defer { isJoining = false }
        do {
            try await firebaseService.joinCommunity(communityId: community.id, userId: userId)
            isMember = true
            ownRole = ownRole ?? .member
            checkUserPermissions()
            HapticManager.shared.notification(type: .success)
        } catch let error as CommunityJoinError {
            errorMessage = error.errorDescription ?? ""
        } catch {
            await handleError(error, context: "joining")
        }
    }

    private func applyMute(until: Date?) {
        mutedUntil = until
        muteExpiryTask?.cancel()
        guard let until else { return }
        let seconds = until.timeIntervalSinceNow
        muteExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, seconds)))
            guard !Task.isCancelled else { return }
            self?.mutedUntil = nil
        }
    }

    /// The owner and staff roles (one small query), then re-check what the current user may do
    private func loadStaffRoles() async {
        guard let community else { return }
        if let roles = try? await firebaseService.getCommunityStaffRoles(communityId: community.id, createdBy: community.createdBy) {
            guard !Task.isCancelled else { return }
            memberRoles = roles
        }
        checkUserPermissions()
    }

    /// A member's role in this community (defaults to member)
    func role(for userId: String) -> CommunityRole {
        if let community = community, community.createdBy == userId { return .owner }
        if userId == currentUserId, let ownRole { return ownRole }
        return memberRoles[userId] ?? .member
    }

    /// Check user permissions for the channel
    private func checkUserPermissions() {
        guard let channel, let currentUserId, isMember else {
            canUserPost = false
            canUserManageChannel = false
            return
        }
        let role = role(for: currentUserId)
        let isAdmin = role == .owner || role == .admin

        // Admin-only channels (like #callouts) accept posts from owners and admins only.
        // Muting is checked separately (`isMuted`) so the composer can say until when.
        canUserPost = !channel.adminOnly || isAdmin

        // Owners, admins and moderators can moderate the channel
        canUserManageChannel = isAdmin || role == .moderator
    }

    /// Hide everything from a user the current user just blocked
    func hideMessages(from userId: String) {
        publishMessages()
    }

    // MARK: - Sending

    /// Send a message to the channel
    /// - Parameter replyTo: the message being replied to; stored as `replyTo` and its author is notified.
    func sendMessage(content: String, replyTo: CommunityMessage? = nil) {
        guard let community = community,
              let channel = channel,
              let currentUser = authService.currentUser,
              isMember, canUserPost, !isMuted else {
            return
        }

        var message = CommunityMessage(
            content: ChatText.clip(content, max: ChatText.contentLimit),
            authorId: currentUser.id,
            authorUsername: currentUser.username,
            channelId: channel.id,
            communityId: community.id,
            authorAvatarURL: currentUser.profileImageUrl
        )
        if let replyTo, !replyTo.isDeleted {
            message.replyTo = MessageReplyRef(to: replyTo)
        }
        let sent = message

        Task {
            do {
                try await firebaseService.sendCommunityMessage(sent)
            } catch {
                await handleError(error, context: "sending message")
                return
            }
            await notifyMentions(in: content, messageId: sent.id, repliedTo: sent.replyTo)
        }
    }

    /// Sends a photo or file that's already uploaded, as a structured `media` field.
    func sendMedia(_ media: MessageMedia) {
        guard let community, let channel, let currentUser = authService.currentUser,
              isMember, canUserPost, !isMuted, media.isTrusted else { return }
        var message = CommunityMessage(
            content: "",
            authorId: currentUser.id,
            authorUsername: currentUser.username,
            channelId: channel.id,
            communityId: community.id,
            authorAvatarURL: currentUser.profileImageUrl
        )
        message.media = media
        let sent = message
        Task {
            do {
                try await firebaseService.sendCommunityMessage(sent)
            } catch {
                await handleError(error, context: "sending attachment")
            }
        }
    }

    // MARK: - Trade Callouts

    /// Post a structured trade callout (admins only in callout channels).
    func sendCallout(_ callout: TradeCallout) {
        guard let community = community, let channel = channel,
              let currentUser = authService.currentUser, isMember, canUserPost, !isMuted else { return }
        var message = CommunityMessage(
            content: callout.summary,
            authorId: currentUser.id,
            authorUsername: currentUser.username,
            channelId: channel.id,
            communityId: community.id,
            authorAvatarURL: currentUser.profileImageUrl
        )
        var stamped = callout.stamped(authorId: currentUser.id, communityId: community.id, postedAt: message.createdAt)
        // The create form sets the price check; anything else counts as not checked.
        if stamped.priceCheck != .live {
            stamped.priceCheck = .unchecked
            stamped.quoteAtPost = nil
        }
        message.callout = stamped
        let posted = message
        let postedCallout = stamped
        Task {
            do {
                try await firebaseService.sendCommunityMessage(posted)
            } catch {
                await handleError(error, context: "posting callout")
                return
            }
            // Free mode: mirror doc, stats and the members' `callout` notifications
            await TrackRecordWriter.shared.calloutPosted(
                postedCallout,
                authorId: currentUser.id,
                communityId: community.id,
                communityName: community.name,
                channelId: channel.id,
                messageId: posted.id
            )
            await notifyMentions(in: postedCallout.note ?? "", messageId: posted.id)
        }
    }

    /// Free mode: `mention` notifications for `@username`s in a message this user just sent, and
    /// for the author of the message it replies to ("… replied to you").
    /// Only people who are members are notified (the rules require it), checked with one read.
    private func notifyMentions(in text: String, messageId: String, repliedTo: MessageReplyRef? = nil) async {
        guard !AppConfig.serverFunctionsEnabled,
              let community = community, let channel = channel,
              let currentUser = authService.currentUser else { return }
        var ids: [String] = []
        if text.contains("@") {
            ids = await firebaseService.userIdsMentioned(in: text)
        }
        ids.removeAll { $0 == currentUser.id }
        var replyAuthor: String?
        if let repliedTo, !repliedTo.authorId.isEmpty, repliedTo.authorId != currentUser.id,
           !ids.contains(repliedTo.authorId) {
            replyAuthor = repliedTo.authorId
        }
        let candidates = ids + [replyAuthor].compactMap { $0 }
        guard !candidates.isEmpty else { return }
        let members = await firebaseService.memberIds(in: community.id, among: candidates)

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.count > 140 ? String(trimmed.prefix(140)) + "…" : trimmed
        let route = TrackRecordWriter.channelRoute(communityId: community.id, channelId: channel.id, messageId: messageId)

        if let replyAuthor, members.contains(replyAuthor) {
            await firebaseService.createNotification(
                to: replyAuthor,
                type: "mention",
                title: "\(currentUser.username) replied to you in #\(channel.name)",
                body: body,
                data: route
            )
        }

        let mentioned = ids.filter { members.contains($0) }
        guard !mentioned.isEmpty else { return }
        await firebaseService.createNotifications(
            to: mentioned,
            type: "mention",
            title: "\(currentUser.username) mentioned you in #\(channel.name)",
            body: body,
            data: route
        )
    }

    // MARK: - Game plan

    /// Posts a game plan: up to 15 tickers with a bias, plus a text summary as `content`.
    func sendGamePlan(_ plan: GamePlan) {
        guard let community = community, let channel = channel,
              let currentUser = authService.currentUser, isMember, canPostGamePlan else { return }
        var clean = plan
        clean.title = ChatText.clip(plan.title.trimmingCharacters(in: .whitespacesAndNewlines), max: ChatText.gamePlanTitleLimit)
        clean.tickers = Array(plan.tickers.prefix(GamePlan.maxTickers))
        guard !clean.title.isEmpty, !clean.tickers.isEmpty else { return }

        var message = CommunityMessage(
            content: ChatText.clip(clean.summary, max: ChatText.contentLimit),
            authorId: currentUser.id,
            authorUsername: currentUser.username,
            channelId: channel.id,
            communityId: community.id,
            authorAvatarURL: currentUser.profileImageUrl
        )
        message.gamePlan = clean
        let posted = message
        Task {
            do {
                try await firebaseService.sendCommunityMessage(posted)
            } catch {
                await handleError(error, context: "posting game plan")
            }
        }
    }

    /// Add a callout to the current user's portfolio as an open trade.
    func trackCallout(_ callout: TradeCallout, entryPrice: Double, quantity: Double) async throws {
        guard let currentUser = authService.currentUser else { throw FirestoreError.unauthorized }
        var trade = Trade(ticker: callout.ticker, tradeType: callout.assetType, entryPrice: entryPrice,
                          quantity: quantity, userId: currentUser.id)
        trade.stopLossPrice = callout.stopPrice
        trade.takeProfitPrice = callout.targetPrice
        trade.strategy = "Callout (\(callout.direction.displayName))"
        trade.notes = ["From a callout in \(community?.name ?? "a community")", callout.note]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        trade.tags = ["callout", callout.direction.rawValue]
        if let communityId = community?.id { trade.sharedCommunityIds = [communityId] }
        try await authService.addTrade(trade)
    }

    // MARK: - Reactions

    /// Adds the emoji if the current user hasn't used it on this message, removes it if they have.
    func addReaction(to messageId: String, emoji: String) {
        guard let currentUserId, let community, let channel, isMember,
              let message = message(withId: messageId), !message.isDeleted else { return }
        let mine = message.reactions[currentUserId] ?? []
        let adding = !mine.contains(emoji)
        if adding && mine.count >= FirebaseServices.maxReactionsPerUser {
            errorMessage = "You can add up to \(FirebaseServices.maxReactionsPerUser) reactions to a message"
            return
        }

        updateLocal(messageId) { message in
            var list = message.reactions[currentUserId] ?? []
            if adding { list.append(emoji) } else { list.removeAll { $0 == emoji } }
            message.reactions[currentUserId] = list.isEmpty ? nil : list
        }
        Task {
            do {
                try await firebaseService.setMessageReaction(
                    messageId: messageId, channelId: channel.id, communityId: community.id,
                    emoji: emoji, userId: currentUserId, adding: adding
                )
            } catch {
                updateLocal(messageId) { $0.reactions = message.reactions }
                await handleError(error, context: "reacting")
            }
        }
    }

    /// Grouped reactions for display with counts
    func getGroupedReactions(for message: CommunityMessage) -> [EmojiReactionGroup] {
        message.reactionGroups(currentUserId: currentUserId)
    }

    // MARK: - Message Management

    /// Authors can edit their own text messages for five minutes after sending.
    /// Callouts, updates, results, trade shares, game plans and attachments can't be edited:
    /// their text is a generated summary of the structured data.
    func canEditMessage(_ message: CommunityMessage) -> Bool {
        guard let currentUserId = currentUserId, isMember,
              message.authorId == currentUserId,
              !message.isDeleted, !message.hasStructuredKind else { return false }

        let editTimeLimit: TimeInterval = 5 * 60
        return Date().timeIntervalSince(message.createdAt) <= editTimeLimit
    }

    /// Authors can delete their own messages; staff can delete messages of people they outrank
    /// (a moderator can't delete an admin's or the owner's).
    func canDeleteMessage(_ message: CommunityMessage) -> Bool {
        guard let currentUserId = currentUserId, !message.isDeleted else { return false }
        if message.authorId == currentUserId { return true }
        guard canUserManageChannel else { return false }
        return role(for: currentUserId).canManage(role(for: message.authorId))
    }

    func canPin(_ message: CommunityMessage) -> Bool {
        canPinMessages && !message.isDeleted
    }

    /// Saves an edit to Firestore (`content` and `editedAt`), so every listener sees it.
    func editMessage(_ message: CommunityMessage, newContent: String) {
        guard let community = community, let channel = channel, canEditMessage(message) else { return }
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != message.content else { return }

        updateLocal(message.id) {
            $0.content = trimmed  // optimistic; the listener confirms
            $0.editedAt = Date()
        }
        Task {
            do {
                try await firebaseService.editCommunityMessage(
                    messageId: message.id, channelId: channel.id, communityId: community.id, newContent: trimmed
                )
            } catch {
                restore(message)
                await handleError(error, context: "editing message")
            }
        }
    }

    /// Soft-deletes a message: it shows as "Message deleted" for everyone.
    func deleteMessage(_ message: CommunityMessage) {
        guard let community = community, let channel = channel,
              let currentUserId = currentUserId, canDeleteMessage(message) else { return }

        updateLocal(message.id) {
            $0.isDeleted = true  // optimistic; the listener confirms
            $0.content = ""
            $0.callout = nil
            $0.calloutUpdate = nil
            $0.calloutResult = nil
            $0.tradeShare = nil
            $0.gamePlan = nil
            $0.replyTo = nil
            $0.media = nil
            $0.reactions = [:]
            $0.deletedBy = currentUserId
        }
        Task {
            do {
                try await firebaseService.softDeleteCommunityMessage(
                    messageId: message.id, channelId: channel.id, communityId: community.id, deletedBy: currentUserId
                )
            } catch {
                restore(message)
                await handleError(error, context: "deleting message")
                return
            }
            await closeDeletedCallout(in: message, communityId: community.id, channelId: channel.id)
        }
    }

    /// Free mode: deleting your own open callout doesn't erase it from your record. It closes
    /// in your mirror doc at its last price (or entry, 0%) and your stats are rebuilt.
    /// When a moderator deletes someone else's callout, the author's CalloutAutoTracker does this.
    private func closeDeletedCallout(in message: CommunityMessage, communityId: String, channelId: String) async {
        guard TrackRecordWriter.isActive,
              let callout = message.callout, callout.isOpen,
              let currentUserId = currentUserId,
              (callout.authorId ?? message.authorId) == currentUserId else { return }
        let writer = TrackRecordWriter.shared
        do {
            try await writer.closeDeleted(callout, authorId: currentUserId, communityId: communityId,
                                          channelId: channelId, messageId: message.id)
        } catch {
            return  // CalloutAutoTracker closes it on its next run
        }
        await writer.recomputeStats()
    }

    func togglePin(_ message: CommunityMessage) {
        guard let community = community, let channel = channel,
              let currentUserId = currentUserId, canPin(message) else { return }
        let pin = !message.isPinned

        updateLocal(message.id) {
            $0.isPinned = pin  // optimistic; the listener confirms
            $0.pinnedAt = pin ? Date() : nil
            $0.pinnedBy = pin ? currentUserId : nil
        }
        Task {
            do {
                try await firebaseService.setCommunityMessagePinned(
                    messageId: message.id, channelId: channel.id, communityId: community.id,
                    isPinned: pin, by: currentUserId
                )
            } catch {
                restore(message)
                await handleError(error, context: pin ? "pinning message" : "unpinning message")
            }
        }
    }

    /// Puts a message back the way it was after a failed write
    private func restore(_ message: CommunityMessage) {
        updateLocal(message.id) { $0 = message }
    }

    // MARK: - Typing

    private func startListeningForTyping() {
        guard let community, let channel else { return }
        let listener = firebaseService.listenToTyping(communityId: community.id, channelId: channel.id) { [weak self] typing in
            Task { @MainActor in
                self?.typingEntries = typing
                self?.refreshTyping()
            }
        }
        listeners.add(listener)

        // A doc that stops updating sends no snapshot, so re-check every 3 seconds
        typingRefreshTask?.cancel()
        typingRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self?.refreshTyping()
            }
        }
    }

    private func refreshTyping() {
        let cutoff = Date().addingTimeInterval(-Self.typingTimeout)
        let names = typingEntries
            .filter { $0.userId != currentUserId && $0.lastSeen > cutoff && !blockStore.isBlocked($0.userId) }
            .map(\.username)
        if names != typingUsernames { typingUsernames = names }
    }

    /// Tell other members we're typing (or stopped). Writes at most every 3 seconds while typing.
    func setTyping(_ isTyping: Bool) {
        guard let community = community, let channel = channel,
              let user = authService.currentUser, isMember else { return }
        if isTyping, let last = lastTypingSent, Date().timeIntervalSince(last) < 3 { return }
        if !isTyping && lastTypingSent == nil { return }
        lastTypingSent = isTyping ? Date() : nil
        Task {
            try? await firebaseService.setUserTyping(
                userId: user.id, username: user.username,
                channelId: channel.id, communityId: community.id, isTyping: isTyping
            )
        }
    }

    // MARK: - Errors

    /// Shows a short, friendly error for five seconds
    private func handleError(_ error: Error, context: String) async {
        let message = "Error \(context): \(getFriendlyErrorMessage(error))"
        errorMessage = message
        try? await Task.sleep(for: .seconds(5))
        if errorMessage == message {
            errorMessage = ""
        }
    }

    /// Convert technical errors to user-friendly messages
    private func getFriendlyErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain {
            switch FirestoreErrorCode.Code(rawValue: nsError.code) {
            case .permissionDenied: return "You don't have permission for this action"
            case .unavailable, .deadlineExceeded: return "Check your internet connection"
            case .notFound: return "Message or channel not found"
            default: break
            }
        }
        if error.localizedDescription.localizedCaseInsensitiveContains("network") {
            return "Check your internet connection"
        }
        return "Something went wrong. Please try again."
    }

    /// Clear error message
    func clearError() {
        errorMessage = ""
    }
}

// MARK: - Listener bag

/// Firestore listeners owned by a view model, removable from deinit.
final class ListenerBag: @unchecked Sendable {
    private let lock = NSLock()
    private var registrations: [ListenerRegistration] = []

    func add(_ registration: ListenerRegistration) {
        lock.lock(); defer { lock.unlock() }
        registrations.append(registration)
    }

    func removeAll() {
        lock.lock()
        let current = registrations
        registrations.removeAll()
        lock.unlock()
        current.forEach { $0.remove() }
    }
}
