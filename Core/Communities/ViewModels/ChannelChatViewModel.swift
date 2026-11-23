// File: Core/Communities/ViewModels/ChannelChatViewModel.swift
// FIREBASE INTEGRATED VERSION - Persistent Reactions

import Foundation
import Combine
import FirebaseCore
import FirebaseFirestore

@MainActor
class ChannelChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [CommunityMessage] = [] {
        didSet { rebuildMessageIndex() }
    }
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var canUserPost = true
    @Published var canUserManageChannel = false
    /// Roles of community members, keyed by user id (used for badges and permissions)
    @Published var memberRoles: [String: CommunityRole] = [:]
    /// Usernames of other people currently typing in this channel
    @Published var typingUsernames: [String] = []
    /// When the current user's mute in this community ends; nil when they aren't muted
    @Published var mutedUntil: Date?
    
    // Firebase-backed Message Reactions
    @Published var messageReactions: [String: [MessageReaction]] = [:] // messageId -> reactions
    @Published var userReactions: [String: Set<String>] = [:] // messageId -> user's reaction emojis
    
    // MARK: - Private Properties
    private var community: Community?
    private var channel: Channel?
    private let firebaseService = FirebaseServices.shared
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    /// Active Firestore listeners; removed in cleanup()
    private var listeners: [ListenerRegistration] = []
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

    /// Owners, admins and moderators can pin, and delete anyone's messages
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
            .sink { [weak self] blockedIds in
                MainActor.assumeIsolated {
                    self?.messages.removeAll { blockedIds.contains($0.authorId) }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Load channel data and start listening for messages
    func loadChannelData(community: Community, channel: Channel) {
        self.community = community
        self.channel = channel
        
        // Check user permissions (refined once member roles load)
        checkUserPermissions()
        
        // Load initial messages and start real-time listening
        startListeningForMute()
        Task {
            await blockStore.loadIfNeeded()
            await loadMemberRoles()
            await loadInitialMessages()
            await loadAllMessageReactions()
            startListeningForMessages()
            startListeningForReactions()
        }
    }
    
    /// Send a message to the channel
    /// - Parameter replyTo: the message being replied to; stored as `replyTo` and its author is notified.
    func sendMessage(content: String, replyTo: CommunityMessage? = nil) {
        guard let community = community,
              let channel = channel,
              let currentUser = authService.currentUser,
              canUserPost, !isMuted else {
            return
        }
        
        // Create the message
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
                await notifyMentions(in: content, messageId: sent.id, repliedTo: sent.replyTo)
                
                // Create activity for sending message
                try await authService.createActivity(
                    userId: currentUser.id,
                    type: .newPost,
                    content: "Posted in #\(channel.name): \(content.prefix(50))",
                    relatedId: community.id
                )
                
            } catch {
                await handleError(error, context: "sending message")
            }
        }
    }
    
    // MARK: - Trade Callouts
    
    /// Post a structured trade callout (admins only in callout channels).
    func sendCallout(_ callout: TradeCallout) {
        guard let community = community, let channel = channel,
              let currentUser = authService.currentUser, canUserPost, !isMuted else { return }
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
    /// Only people who are in the community are notified, since others can't open the channel.
    private func notifyMentions(in text: String, messageId: String, repliedTo: MessageReplyRef? = nil) async {
        guard !AppConfig.serverFunctionsEnabled,
              let community = community, let channel = channel,
              let currentUser = authService.currentUser else { return }
        var ids: [String] = []
        if text.contains("@") {
            ids = await firebaseService.userIdsMentioned(in: text)
        }
        if !memberRoles.isEmpty {
            ids = ids.filter { memberRoles[$0] != nil }
        }
        ids.removeAll { $0 == currentUser.id }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.count > 140 ? String(trimmed.prefix(140)) + "…" : trimmed
        let route = TrackRecordWriter.channelRoute(communityId: community.id, channelId: channel.id, messageId: messageId)

        if let repliedTo, !repliedTo.authorId.isEmpty, repliedTo.authorId != currentUser.id,
           !ids.contains(repliedTo.authorId),
           memberRoles.isEmpty || memberRoles[repliedTo.authorId] != nil {
            await firebaseService.createNotification(
                to: repliedTo.authorId,
                type: "mention",
                title: "\(currentUser.username) replied to you in #\(channel.name)",
                body: body,
                data: route
            )
        }

        guard !ids.isEmpty else { return }
        for id in ids {
            await firebaseService.createNotification(
                to: id,
                type: "mention",
                title: "\(currentUser.username) mentioned you in #\(channel.name)",
                body: body,
                data: route
            )
        }
    }
    
    
    // MARK: - Game plan

    /// Posts a game plan: up to 15 tickers with a bias, plus a text summary as `content`.
    func sendGamePlan(_ plan: GamePlan) {
        guard let community = community, let channel = channel,
              let currentUser = authService.currentUser, canPostGamePlan else { return }
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
    
    // MARK: - Firebase-Backed Message Reactions
    
    /// Add or remove reaction to a message (toggle behavior)
    func addReaction(to messageId: String, emoji: String) {
        guard let currentUser = authService.currentUser,
              let community = community,
              let channel = channel else {
            return
        }
        
        Task {
            do {
                // Check if user already reacted with this emoji
                let userReactionsForMessage = userReactions[messageId] ?? Set<String>()
                
                if userReactionsForMessage.contains(emoji) {
                    // User already reacted with this emoji, remove it
                    try await firebaseService.removeMessageReaction(
                        messageId: messageId,
                        channelId: channel.id,
                        communityId: community.id,
                        emoji: emoji,
                        userId: currentUser.id
                    )
                    
                    // Update local state optimistically
                    removeLocalReaction(messageId: messageId, emoji: emoji, userId: currentUser.id)
                    
                } else {
                    // Add new reaction
                    try await firebaseService.addMessageReaction(
                        messageId: messageId,
                        channelId: channel.id,
                        communityId: community.id,
                        emoji: emoji,
                        userId: currentUser.id,
                        username: currentUser.username
                    )
                    
                    // Update local state optimistically
                    addLocalReaction(messageId: messageId, emoji: emoji, userId: currentUser.id, username: currentUser.username)
                }
                
            } catch {
                await handleError(error, context: "toggling reaction")
            }
        }
    }
    
    /// Get reactions for a specific message (for UI display)
    func getReactionsFor(_ messageId: String) -> [String] {
        let reactions = messageReactions[messageId] ?? []
        // Return unique emojis for simple display
        return Array(Set(reactions.map { $0.emoji }))
    }
    
    /// Get grouped reactions for display with counts
    func getGroupedReactions(for messageId: String) -> [EmojiReactionGroup] {
        let reactions = messageReactions[messageId] ?? []
        let grouped = Dictionary(grouping: reactions) { $0.emoji }
        
        return grouped.map { emoji, reactionList in
            let usernames = reactionList.map { $0.username }
            let hasUserReacted = reactionList.contains { $0.userId == currentUserId }
            
            return EmojiReactionGroup(
                emoji: emoji,
                count: reactionList.count,
                usernames: usernames,
                hasUserReacted: hasUserReacted
            )
        }.sorted { $0.count > $1.count } // Sort by popularity
    }
    
    /// Check if current user has reacted with specific emoji
    func hasUserReacted(to messageId: String, with emoji: String) -> Bool {
        return userReactions[messageId]?.contains(emoji) ?? false
    }
    
    /// Get reaction count for specific emoji on message
    func getReactionCount(for messageId: String, emoji: String) -> Int {
        let reactions = messageReactions[messageId] ?? []
        return reactions.filter { $0.emoji == emoji }.count
    }
    
    // MARK: - Message Management

    /// Authors can edit their own text messages for five minutes after sending.
    /// Callouts, updates, results, trade shares and game plans can't be edited: their text is a
    /// generated summary of the structured data.
    func canEditMessage(_ message: CommunityMessage) -> Bool {
        guard let currentUserId = currentUserId,
              message.authorId == currentUserId,
              !message.isDeleted, !message.hasStructuredKind else { return false }

        let editTimeLimit: TimeInterval = 5 * 60
        return Date().timeIntervalSince(message.createdAt) <= editTimeLimit
    }

    /// Authors can delete their own messages; owners, admins and moderators can delete any
    func canDeleteMessage(_ message: CommunityMessage) -> Bool {
        guard let currentUserId = currentUserId, !message.isDeleted else { return false }
        return message.authorId == currentUserId || canUserManageChannel
    }

    func canPin(_ message: CommunityMessage) -> Bool {
        canPinMessages && !message.isDeleted
    }

    /// Saves an edit to Firestore (`content` and `editedAt`), so every listener sees it.
    func editMessage(_ message: CommunityMessage, newContent: String) {
        guard let community = community, let channel = channel, canEditMessage(message) else { return }
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != message.content else { return }

        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].content = trimmed  // optimistic; the listener confirms
            messages[index].editedAt = Date()
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

        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].isDeleted = true  // optimistic; the listener confirms
            messages[index].content = ""
            messages[index].callout = nil
            messages[index].calloutUpdate = nil
            messages[index].calloutResult = nil
            messages[index].tradeShare = nil
            messages[index].gamePlan = nil
            messages[index].replyTo = nil
            messages[index].deletedBy = currentUserId
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

        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].isPinned = pin  // optimistic; the listener confirms
            messages[index].pinnedAt = pin ? Date() : nil
            messages[index].pinnedBy = pin ? currentUserId : nil
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
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        }
    }
    
    /// Cleanup when view disappears
    func cleanup() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        muteExpiryTask?.cancel()
        muteExpiryTask = nil
        setTyping(false)
    }
    
    // MARK: - Private Methods
    
    /// Check user permissions for the channel
    private func checkUserPermissions() {
        guard let channel = channel,
              let community = community,
              let currentUserId = currentUserId else {
            canUserPost = false
            canUserManageChannel = false
            return
        }
        
        let role: CommunityRole = community.createdBy == currentUserId ? .owner : role(for: currentUserId)
        let isAdmin = role == .owner || role == .admin
        
        // Admin-only channels (like #callouts) accept posts from owners and admins only.
        // Muting is checked separately (`isMuted`) so the composer can say until when.
        canUserPost = !channel.adminOnly || isAdmin
        
        // Owners, admins and moderators can moderate the channel
        canUserManageChannel = isAdmin || role == .moderator
    }
    
    /// Hide everything from a user the current user just blocked
    func hideMessages(from userId: String) {
        messages.removeAll { $0.authorId == userId }
    }

    /// Follows the current user's `mutedUntil` in this community
    private func startListeningForMute() {
        guard let community = community, let currentUserId = currentUserId else { return }
        let listener = firebaseService.listenToMemberMute(communityId: community.id, userId: currentUserId) { [weak self] until in
            Task { @MainActor in
                self?.applyMute(until: until)
            }
        }
        listeners.append(listener)
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
    
    /// A member's role in this community (defaults to member)
    func role(for userId: String) -> CommunityRole {
        if let community = community, community.createdBy == userId { return .owner }
        return memberRoles[userId] ?? .member
    }
    
    /// Load every member's role, then re-check what the current user may do
    private func loadMemberRoles() async {
        guard let community = community else { return }
        do {
            memberRoles = try await firebaseService.getCommunityMemberRoles(communityId: community.id)
        } catch {
            // Everyone shows as a member until roles load; permissions stay at their safe defaults.
        }
        checkUserPermissions()
    }
    
    /// Load initial messages
    private func loadInitialMessages() async {
        guard let community = community,
              let channel = channel else { return }
        
        do {
            let loadedMessages = try await firebaseService.getChannelMessages(
                communityId: community.id,
                channelId: channel.id,
                limit: 50
            )
            
            messages = loadedMessages.filter { !blockStore.isBlocked($0.authorId) }
            
        } catch {
            await handleError(error, context: "loading messages")
        }
    }
    
    /// Load reactions for all current messages
    private func loadAllMessageReactions() async {
        guard let community = community,
              let channel = channel else { return }
        
        do {
            // Load reactions for all current messages
            for message in messages {
                let reactions = try await firebaseService.getMessageReactions(
                    messageId: message.id,
                    channelId: channel.id,
                    communityId: community.id
                )
                
                messageReactions[message.id] = reactions
                
                // Update user reactions tracking
                if let currentUserId = currentUserId {
                    let userReactedEmojis = reactions
                        .filter { $0.userId == currentUserId }
                        .map { $0.emoji }
                    userReactions[message.id] = Set(userReactedEmojis)
                }
            }
            

        } catch {
            await handleError(error, context: "loading reactions")
        }
    }
    
    /// Start listening for real-time messages
    private func startListeningForMessages() {
        guard let community = community,
              let channel = channel else { return }
        
        let listener = firebaseService.listenToChannelMessages(
            communityId: community.id,
            channelId: channel.id
        ) { [weak self] newMessages in
            Task { @MainActor in
                guard let self else { return }
                self.messages = newMessages.filter { !self.blockStore.isBlocked($0.authorId) }
                
                // Load reactions for any new messages
                await self.loadReactionsForNewMessages(self.messages)
            }
        }
        listeners.append(listener)
        
        let typingListener = firebaseService.listenToTyping(
            communityId: community.id,
            channelId: channel.id
        ) { [weak self] typing in
            Task { @MainActor in
                guard let self else { return }
                self.typingUsernames = typing
                    .filter { $0.userId != self.currentUserId }
                    .map(\.username)
            }
        }
        listeners.append(typingListener)
    }
    
    /// Tell other members we're typing (or stopped). Writes at most every 3 seconds while typing.
    func setTyping(_ isTyping: Bool) {
        guard let community = community, let channel = channel,
              let user = authService.currentUser else { return }
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
    
    /// Start listening for real-time reactions
    private func startListeningForReactions() {
        guard let community = community,
              let channel = channel else { return }
        
        let listener = firebaseService.listenToChannelReactions(
            communityId: community.id,
            channelId: channel.id
        ) { [weak self] reactions in
            Task { @MainActor in
                await self?.updateReactionsFromListener(reactions)
            }
        }
        listeners.append(listener)
    }
    
    /// Load reactions for new messages that came from real-time listener
    private func loadReactionsForNewMessages(_ newMessages: [CommunityMessage]) async {
        guard let community = community,
              let channel = channel else { return }
        
        for message in newMessages {
            // Only load if we don't already have reactions for this message
            if messageReactions[message.id] == nil {
                do {
                    let reactions = try await firebaseService.getMessageReactions(
                        messageId: message.id,
                        channelId: channel.id,
                        communityId: community.id
                    )
                    
                    messageReactions[message.id] = reactions
                    
                    // Update user reactions tracking
                    if let currentUserId = currentUserId {
                        let userReactedEmojis = reactions
                            .filter { $0.userId == currentUserId }
                            .map { $0.emoji }
                        userReactions[message.id] = Set(userReactedEmojis)
                    }
                } catch {
                    // Reactions for this message load with the next listener update
                }
            }
        }
    }
    
    /// Update reactions from real-time listener
    private func updateReactionsFromListener(_ reactions: [String: [MessageReaction]]) async {
        messageReactions = reactions
        
        // Update user reactions tracking
        if let currentUserId = currentUserId {
            for (messageId, messageReactionList) in reactions {
                let userReactedEmojis = messageReactionList
                    .filter { $0.userId == currentUserId }
                    .map { $0.emoji }
                userReactions[messageId] = Set(userReactedEmojis)
            }
        }
    }
    
    /// Add reaction to local state optimistically (for immediate UI feedback)
    private func addLocalReaction(messageId: String, emoji: String, userId: String, username: String) {
        var reactions = messageReactions[messageId] ?? []
        let newReaction = MessageReaction(
            emoji: emoji,
            userId: userId,
            username: username
        )
        reactions.append(newReaction)
        messageReactions[messageId] = reactions
        
        // Update user reactions
        var userReactionsForMessage = userReactions[messageId] ?? Set<String>()
        userReactionsForMessage.insert(emoji)
        userReactions[messageId] = userReactionsForMessage
    }
    
    /// Remove reaction from local state optimistically
    private func removeLocalReaction(messageId: String, emoji: String, userId: String) {
        var reactions = messageReactions[messageId] ?? []
        reactions.removeAll { $0.userId == userId && $0.emoji == emoji }
        messageReactions[messageId] = reactions
        
        // Update user reactions
        var userReactionsForMessage = userReactions[messageId] ?? Set<String>()
        userReactionsForMessage.remove(emoji)
        userReactions[messageId] = userReactionsForMessage
    }
    
    /// Handle errors with user-friendly messages
    private func handleError(_ error: Error, context: String) async {
        let friendlyMessage = getFriendlyErrorMessage(error)
        errorMessage = "Error \(context): \(friendlyMessage)"
        
        // Auto-clear error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.errorMessage == "Error \(context): \(friendlyMessage)" {
                self?.errorMessage = ""
            }
        }
    }
    
    /// Convert technical errors to user-friendly messages
    private func getFriendlyErrorMessage(_ error: Error) -> String {
        if error.localizedDescription.contains("network") {
            return "Check your internet connection"
        } else if error.localizedDescription.contains("permission") {
            return "You don't have permission for this action"
        } else if error.localizedDescription.contains("not found") {
            return "Message or channel not found"
        } else {
            return "Something went wrong. Please try again."
        }
    }
    
    // MARK: - Helper Methods
    
    /// Clear error message
    func clearError() {
        errorMessage = ""
    }
}

// MARK: - Supporting Types

/// Message reaction model for Firebase
struct MessageReaction: Identifiable, Codable {
    var id: String { "\(userId)_\(emoji)_\(Int(createdAt.timeIntervalSince1970))" }
    let emoji: String
    let userId: String
    let username: String
    let createdAt: Date
    
    // Initializer for creating new reactions
    init(emoji: String, userId: String, username: String) {
        self.emoji = emoji
        self.userId = userId
        self.username = username
        self.createdAt = Date()
    }
    
    // Private initializer for loading from Firestore with custom createdAt
    private init(emoji: String, userId: String, username: String, createdAt: Date) {
        self.emoji = emoji
        self.userId = userId
        self.username = username
        self.createdAt = createdAt
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "emoji": emoji,
            "userId": userId,
            "username": username,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    static func fromFirestore(data: [String: Any]) throws -> MessageReaction {
        guard let emoji = data["emoji"] as? String,
              let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        return MessageReaction(
            emoji: emoji,
            userId: userId,
            username: username,
            createdAt: createdAtTimestamp.dateValue()
        )
    }
}

/// Grouped emoji reactions for display
struct EmojiReactionGroup: Identifiable {
    let id = UUID()
    let emoji: String
    let count: Int
    let usernames: [String]
    let hasUserReacted: Bool
    
    var displayText: String {
        if count == 1 {
            return usernames.first ?? ""
        } else if count == 2 {
            return "\(usernames[0]) and \(usernames[1])"
        } else if count == 3 {
            return "\(usernames[0]), \(usernames[1]) and \(usernames[2])"
        } else {
            return "\(usernames[0]), \(usernames[1]) and \(count - 2) others"
        }
    }
}
