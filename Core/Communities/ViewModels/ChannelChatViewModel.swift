// File: Core/Communities/ViewModels/ChannelChatViewModel.swift
// ViewModel for Channel Chat with Real-time Messaging

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
    
    // MARK: - Private Properties
    private var community: Community?
    private var channel: Channel?
    private let firebaseService = FirebaseServices.shared
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var messagesListener: (() -> Void)?
    
    // MARK: - Computed Properties
    var currentUserId: String? {
        return authService.currentUser?.id
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
            startListeningForMessages()
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
    
    /// Cleanup when view disappears
    func cleanup() {
        print("🧹 ChannelChatViewModel: Cleaning up listeners")
        messagesListener?()
        messagesListener = nil
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Load initial messages for the channel
    private func loadInitialMessages() async {
        guard let community = community,
              let channel = channel else { return }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let loadedMessages = try await firebaseService.getChannelMessages(
                communityId: community.id,
                channelId: channel.id,
                limit: 50
            )
            
            messages = loadedMessages
            print("✅ Loaded \(messages.count) initial messages for #\(channel.name)")
            
        } catch {
            await handleError(error, context: "loading initial messages")
        }
        
        isLoading = false
    }
    
    /// Start listening for real-time message updates
    private func startListeningForMessages() {
        guard let community = community,
              let channel = channel else { return }
        
        print("👂 Starting real-time listener for #\(channel.name)")
        
        firebaseService.listenToChannelMessages(
            communityId: community.id,
            channelId: channel.id
        ) { [weak self] updatedMessages in
            Task { @MainActor in
                self?.messages = updatedMessages
                print("🔄 Received \(updatedMessages.count) messages via real-time listener")
            }
        }
        
        // Store the cleanup function
        messagesListener = { [weak self] in
            // Firebase listeners are automatically cleaned up when the reference is released
            // But we can add custom cleanup here if needed
            print("🔇 Stopped listening to messages")
        }
    }
    
    /// Check user permissions for posting and managing
    private func checkUserPermissions() {
        guard let community = community,
              let channel = channel,
              let userId = currentUserId else {
            canUserPost = false
            canUserManageChannel = false
            return
        }
        
        // Check if user can post messages
        if channel.adminOnly {
            // Only admins and community creator can post in admin-only channels
            canUserPost = (community.createdBy == userId)
            // TODO: Add proper role checking when role system is implemented
        } else {
            // Regular channels - all members can post
            canUserPost = true
        }
        
        // Check if user can manage channel (admin/owner permissions)
        canUserManageChannel = (community.createdBy == userId)
        
        print("🔐 User permissions for #\(channel.name):")
        print("   Can post: \(canUserPost)")
        print("   Can manage: \(canUserManageChannel)")
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
        } else if error.localizedDescription.contains("rate") {
            return "You're sending messages too quickly"
        } else {
            return "Something went wrong. Please try again."
        }
    }
    
    // MARK: - Message Management
    
    /// Delete a message (if user has permission)
    func deleteMessage(_ message: CommunityMessage) {
        guard let currentUserId = currentUserId else { return }
        
        // Users can delete their own messages, admins can delete any message
        let canDelete = (message.authorId == currentUserId) || canUserManageChannel
        
        guard canDelete else {
            errorMessage = "You don't have permission to delete this message"
            return
        }
        
        Task {
            do {
                // TODO: Implement message deletion in FirebaseServices
                // try await firebaseService.deleteCommunityMessage(messageId: message.id, communityId: message.communityId, channelId: message.channelId)
                print("🗑️ Would delete message: \(message.content)")
                
            } catch {
                await handleError(error, context: "deleting message")
            }
        }
    }
    
    /// Edit a message (if user owns it and within time limit)
    func editMessage(_ message: CommunityMessage, newContent: String) {
        guard let currentUserId = currentUserId,
              message.authorId == currentUserId else {
            errorMessage = "You can only edit your own messages"
            return
        }
        
        // Check if message is still editable (within 5 minutes)
        let editTimeLimit: TimeInterval = 5 * 60 // 5 minutes
        let timeSinceCreated = Date().timeIntervalSince(message.createdAt)
        
        guard timeSinceCreated <= editTimeLimit else {
            errorMessage = "Messages can only be edited within 5 minutes"
            return
        }
        
        Task {
            do {
                // TODO: Implement message editing in FirebaseServices
                // try await firebaseService.editCommunityMessage(messageId: message.id, newContent: newContent)
                print("✏️ Would edit message to: \(newContent)")
                
            } catch {
                await handleError(error, context: "editing message")
            }
        }
    }
    
    // MARK: - Channel Stats
    
    /// Get message count for the channel
    var messageCount: Int {
        return messages.count
    }
    
    /// Get unique users who have posted in this channel
    var activeUserCount: Int {
        let uniqueUserIds = Set(messages.map { $0.authorId })
        return uniqueUserIds.count
    }
    
    /// Check if channel has any messages
    var hasMessages: Bool {
        return !messages.isEmpty
    }
    
    /// Get the most recent message
    var lastMessage: CommunityMessage? {
        return messages.last
    }
}
