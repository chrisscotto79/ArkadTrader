// File: Core/Communities/ViewModels/ChannelChatViewModel.swift
// FIREBASE INTEGRATED VERSION - Persistent Reactions

import Foundation
import Combine

@MainActor
class ChannelChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [CommunityMessage] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var canUserPost = true
    @Published var canUserManageChannel = false
    
    // Firebase-backed Message Reactions
    @Published var messageReactions: [String: [MessageReaction]] = [:] // messageId -> reactions
    @Published var userReactions: [String: Set<String>] = [:] // messageId -> user's reaction emojis
    
    // MARK: - Private Properties
    private var community: Community?
    private var channel: Channel?
    private let firebaseService = FirebaseServices.shared
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var messagesListener: (() -> Void)?
    private var reactionsListener: (() -> Void)?
    
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
        
        // Check user permissions
        checkUserPermissions()
        
        // Load initial messages and start real-time listening
        Task {
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
        messagesListener?()
        reactionsListener?()
        messagesListener = nil
        reactionsListener = nil
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
        
        // Check if user can post (not admin-only or user is admin)
        canUserPost = !channel.adminOnly || isUserAdmin()
        
        // Check if user can manage channel (owner or admin)
        canUserManageChannel = isUserAdmin() || community.createdBy == currentUserId
    }
    
    /// Check if current user is admin
    private func isUserAdmin() -> Bool {
        guard let community = community,
              let currentUserId = currentUserId else { return false }
        
        return community.createdBy == currentUserId
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
            
            messages = loadedMessages
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
        
        firebaseService.listenToChannelMessages(
            communityId: community.id,
            channelId: channel.id
        ) { [weak self] newMessages in
            Task { @MainActor in
                self?.messages = newMessages
                
                // Load reactions for any new messages
                await self?.loadReactionsForNewMessages(newMessages)
            }
        }
    }
    
    /// Start listening for real-time reactions
    private func startListeningForReactions() {
        guard let community = community,
              let channel = channel else { return }
        
        print("🎭 Starting real-time reactions listener for #\(channel.name)")
        
        firebaseService.listenToChannelReactions(
            communityId: community.id,
            channelId: channel.id
        ) { [weak self] reactions in
            Task { @MainActor in
                await self?.updateReactionsFromListener(reactions)
            }
        }
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
    let id = UUID()
    let emoji: String
    let userId: String
    let username: String
    let createdAt: Date
    
    init(emoji: String, userId: String, username: String) {
        self.emoji = emoji
        self.userId = userId
        self.username = username
        self.createdAt = Date()
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
        
        var reaction = MessageReaction(emoji: emoji, userId: userId, username: username)
        return reaction
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
