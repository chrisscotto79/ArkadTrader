// File: Core/Communities/ViewModels/ChannelChatViewModel.swift
// FIREBASE INTEGRATED VERSION - Persistent Reactions

import Foundation
import Combine
import FirebaseCore
import FirebaseFirestore

@MainActor
class ChannelChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [CommunityMessage] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var canUserPost = true
    @Published var canUserManageChannel = false
    /// Roles of community members, keyed by user id (used for badges and permissions)
    @Published var memberRoles: [String: CommunityRole] = [:]
    /// Usernames of other people currently typing in this channel
    @Published var typingUsernames: [String] = []
    
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
    private var blockedUserIds: Set<String> = []
    
    // MARK: - Computed Properties
    var currentUserId: String? {
        return authService.currentUser?.id
    }
    
    var currentUsername: String? {
        return authService.currentUser?.username
    }
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Public Methods
    
    /// Load channel data and start listening for messages
    func loadChannelData(community: Community, channel: Channel) {
        print("🗨️ ChannelChatViewModel: Loading data for #\(channel.name)")
        
        self.community = community
        self.channel = channel
        
        // Check user permissions (refined once member roles load)
        checkUserPermissions()
        
        // Load initial messages and start real-time listening
        Task {
            await loadBlockedUsers()
            await loadMemberRoles()
            await loadInitialMessages()
            await loadAllMessageReactions()
            startListeningForMessages()
            startListeningForReactions()
        }
    }
    
    /// Send a message to the channel
    func sendMessage(content: String) {
        guard let community = community,
              let channel = channel,
              let currentUser = authService.currentUser,
              canUserPost else {
            print("❌ Cannot send message: Missing requirements")
            return
        }
        
        // Create the message
        let message = CommunityMessage(
            content: content,
            authorId: currentUser.id,
            authorUsername: currentUser.username,
            channelId: channel.id,
            communityId: community.id
        )
        
        Task {
            do {
                try await firebaseService.sendCommunityMessage(message)
                print("✅ Message sent successfully to #\(channel.name)")
                
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
              let currentUser = authService.currentUser, canUserPost else { return }
        var message = CommunityMessage(
            content: callout.summary,
            authorId: currentUser.id,
            authorUsername: currentUser.username,
            channelId: channel.id,
            communityId: community.id
        )
        message.callout = callout
        Task {
            do {
                try await firebaseService.sendCommunityMessage(message)
            } catch {
                await handleError(error, context: "posting callout")
            }
        }
    }
    
    /// The callout's author and community owners/admins can update its status.
    func canManageCallout(_ message: CommunityMessage) -> Bool {
        guard let userId = currentUserId else { return false }
        let role = role(for: userId)
        return message.authorId == userId || role == .owner || role == .admin
    }
    
    func updateCalloutStatus(_ message: CommunityMessage, to status: TradeCallout.Status) {
        guard let community = community, let channel = channel, canManageCallout(message) else { return }
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].callout?.status = status  // optimistic; listener confirms
        }
        Task {
            do {
                try await firebaseService.updateCalloutStatus(
                    messageId: message.id, channelId: channel.id, communityId: community.id, status: status
                )
            } catch {
                await handleError(error, context: "updating callout")
            }
        }
    }
    
    /// Add a callout to the current user's portfolio as an open trade.
    func trackCallout(_ callout: TradeCallout, entryPrice: Double, quantity: Int) async throws {
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
            print("❌ Cannot add reaction: Missing requirements")
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
                    
                    print("✅ Removed reaction \(emoji) from message \(messageId)")
                    
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
                    
                    print("✅ Added reaction \(emoji) to message \(messageId)")
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
    
    // MARK: - Message Management (Previous functionality)
    
    /// Check if user can edit message
    func canEditMessage(_ message: CommunityMessage) -> Bool {
        guard let currentUserId = currentUserId else { return false }
        guard message.authorId == currentUserId else { return false }
        
        let editTimeLimit: TimeInterval = 5 * 60 // 5 minutes
        let timeSinceCreated = Date().timeIntervalSince(message.createdAt)
        return timeSinceCreated <= editTimeLimit
    }
    
    /// Check if user can delete message
    func canDeleteMessage(_ message: CommunityMessage) -> Bool {
        guard let currentUserId = currentUserId else { return false }
        return (message.authorId == currentUserId) || canUserManageChannel
    }
    
    /// Cleanup when view disappears
    func cleanup() {
        print("🧹 ChannelChatViewModel: Cleaning up listeners")
        listeners.forEach { $0.remove() }
        listeners.removeAll()
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
        
        // Admin-only channels (like #callouts) accept posts from owners and admins only
        canUserPost = !channel.adminOnly || isAdmin
        
        // Owners, admins and moderators can moderate the channel
        canUserManageChannel = isAdmin || role == .moderator
    }
    
    /// Hide everything from a user the current user just blocked
    func hideMessages(from userId: String) {
        blockedUserIds.insert(userId)
        messages.removeAll { $0.authorId == userId }
    }
    
    /// Load the current user's block list so blocked people's messages stay hidden
    private func loadBlockedUsers() async {
        guard let currentUserId = currentUserId else { return }
        do {
            blockedUserIds = try await authService.getUserBlockedUsers(userId: currentUserId)
        } catch {
            print("⚠️ ChannelChatViewModel: Could not load blocked users: \(error)")
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
            print("⚠️ ChannelChatViewModel: Could not load member roles: \(error)")
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
            
            messages = loadedMessages.filter { !blockedUserIds.contains($0.authorId) }
            print("✅ Loaded \(messages.count) messages for #\(channel.name)")
            
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
            
            print("✅ Loaded reactions for \(messages.count) messages")
            
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
                self.messages = newMessages.filter { !self.blockedUserIds.contains($0.authorId) }
                
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
        
        print("🎭 Starting real-time reactions listener for #\(channel.name)")
        
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
                    print("Error loading reactions for new message: \(error)")
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
        
        print("🎭 Updated reactions from Firebase listener")
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
        print("❌ ChannelChatViewModel - Error \(context): \(error)")
        
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
