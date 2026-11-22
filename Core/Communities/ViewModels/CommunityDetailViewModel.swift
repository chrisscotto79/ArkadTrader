// File: Core/Communities/ViewModels/CommunityDetailViewModel.swift
// UPDATED - Enhanced CommunityDetailViewModel with better functionality

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class CommunityDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var channels: [Channel] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showSetupPrompt = false
    
    // User & Community State
    @Published var community: Community?
    @Published var userRole: String = "member"
    @Published var isUserMember = false
    @Published var canManageChannels = false
    /// When the current user joined, read from communities/{id}/members/{uid}
    @Published var memberSince: Date?
    
    // MARK: - Private Properties
    private let firebaseService = FirebaseServices.shared
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var currentUserId: String? {
        return authService.currentUser?.id
    }
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Public Methods
    
    /// Re-fetch the community document so edits (name, avatar, banner) show immediately.
    func reloadCommunity() async {
        guard let id = community?.id else { return }
        do {
            let snapshot = try await Firestore.firestore().collection("communities").document(id).getDocument()
            if let data = snapshot.data() {
                community = try Community.fromFirestore(data: data, id: id)
            }
        } catch {
            print("⚠️ CommunityDetailViewModel: Failed to reload community: \(error)")
        }
    }
    
    /// Load community data, channels, and user permissions
    func loadCommunityData(community: Community) {
        print("🏘️ CommunityDetailViewModel: Loading data for \(community.name)")
        
        self.community = community
        
        Task {
            isLoading = true
            errorMessage = ""
            
            // Load data sequentially to avoid type inference warnings
            await loadChannels(for: community.id)
            await loadUserState(for: community)
            
            // Check if we should prompt for channel setup
            checkChannelSetupNeeded()
            
            isLoading = false
        }
    }
    
    /// Refresh channels after creation or updates
    func refreshChannels() {
        guard let community = community else { return }
        
        Task {
            await loadChannels(for: community.id)
        }
    }
    
    /// Setup default channels for the community
    func setupDefaultChannels() async {
        guard let community = community,
              let currentUser = authService.currentUser else { return }
        
        do {
            // Create default channels directly
            let defaultChannels = createDefaultChannels(for: community)
            
            for channel in defaultChannels {
                try await firebaseService.createChannel(channel)
                print("✅ Created default channel: #\(channel.name)")
            }
            
            // Send welcome messages
            try await sendWelcomeMessages(to: community, channels: defaultChannels, username: currentUser.username)
            
            // Refresh channels
            await loadChannels(for: community.id)
            
            print("✅ Default channels setup complete")
            
        } catch {
            await handleError(error, context: "setting up default channels")
        }
    }
    
    /// Create default channels for any community
    private func createDefaultChannels(for community: Community) -> [Channel] {
        var channels: [Channel] = []
        
        // 1. General Channel (always created)
        let generalChannel = Channel(
            name: "general",
            type: .text,
            communityId: community.id,
            isDefault: true,
            adminOnly: false
        )
        channels.append(generalChannel)
        
        // 2. Callouts Channel (admin-only)
        let calloutsChannel = Channel(
            name: "callouts",
            type: .callouts,
            communityId: community.id,
            isDefault: true,
            adminOnly: true
        )
        channels.append(calloutsChannel)
        
        return channels
    }
    
    /// Send welcome messages to new channels
    private func sendWelcomeMessages(to community: Community, channels: [Channel], username: String) async throws {
        guard let currentUser = authService.currentUser else { return }
        
        // Welcome message for general channel
        if let generalChannel = channels.first(where: { $0.name == "general" }) {
            let welcomeMessage = CommunityMessage(
                content: "Welcome to \(community.name)! #general is open to every member, so say hello and share ideas.",
                authorId: currentUser.id,
                authorUsername: username,
                channelId: generalChannel.id,
                communityId: community.id
            )
            
            try await firebaseService.sendCommunityMessage(welcomeMessage)
            print("✅ Sent welcome message to #general")
        }
        
        // Short guide for the callouts channel
        if let calloutsChannel = channels.first(where: { $0.name == "callouts" }) {
            let instructionsMessage = CommunityMessage(
                content: "#callouts is for trade ideas. Only admins can post here: tap the megaphone button next to the message box to share a callout with its entry, stop and target. Members can tap \"Track in Portfolio\" on a callout to add it to their own trades.",
                authorId: currentUser.id,
                authorUsername: username,
                channelId: calloutsChannel.id,
                communityId: community.id
            )
            
            try await firebaseService.sendCommunityMessage(instructionsMessage)
            print("✅ Sent instructions to #callouts")
        }
    }
    
    /// Join the community
    func joinCommunity() {
        guard let community = community,
              let userId = currentUserId else { return }
        
        Task {
            do {
                try await firebaseService.joinCommunity(communityId: community.id, userId: userId)
                
                // Update local state
                isUserMember = true
                userRole = "member"
                memberSince = Date()
                
                // Create activity (only if user has a username)
                if authService.currentUser?.username != nil {
                    try await authService.createActivity(
                        userId: userId,
                        type: .joinedCommunity,
                        content: "Joined \(community.name)",
                        relatedId: community.id
                    )
                }
                
                print("✅ Successfully joined community: \(community.name)")
                
            } catch {
                await handleError(error, context: "joining community")
            }
        }
    }
    
    /// Leave the community
    func leaveCommunity() {
        guard let community = community,
              let userId = currentUserId else { return }
        
        Task {
            do {
                try await firebaseService.leaveCommunity(communityId: community.id, userId: userId)
                
                // Update local state
                isUserMember = false
                userRole = "member"
                canManageChannels = false
                memberSince = nil
                
                print("✅ Successfully left community: \(community.name)")
                
            } catch {
                await handleError(error, context: "leaving community")
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Reload the channel list (after a channel is created or edited)
    func reloadChannels() async {
        guard let communityId = community?.id else { return }
        await loadChannels(for: communityId)
    }

    /// Load channels for the community
    private func loadChannels(for communityId: String) async {
        do {
            let loadedChannels = try await firebaseService.getCommunityChannels(communityId: communityId)
            
            // Sort channels: default channels first, then alphabetically
            let sortedChannels = loadedChannels.sorted { channel1, channel2 in
                // Default channels come first
                if channel1.isDefault && !channel2.isDefault {
                    return true
                } else if !channel1.isDefault && channel2.isDefault {
                    return false
                } else if channel1.isDefault && channel2.isDefault {
                    // Among default channels: general first, then callouts
                    if channel1.name == "general" { return true }
                    if channel2.name == "general" { return false }
                    return channel1.name < channel2.name
                } else {
                    // Non-default channels: alphabetically
                    return channel1.name < channel2.name
                }
            }
            
            channels = sortedChannels
            print("✅ Loaded \(channels.count) channels")
            
        } catch {
            await handleError(error, context: "loading channels")
        }
    }
    
    /// Load user state for the community
    private func loadUserState(for community: Community) async {
        guard let userId = currentUserId else {
            isUserMember = false
            userRole = "member"
            canManageChannels = false
            return
        }
        
        do {
            // Check if user is a member
            let userCommunities = try await firebaseService.getUserCommunities(userId: userId)
            isUserMember = userCommunities.contains { $0.id == community.id }
            
            if isUserMember {
                // Owners and admins can manage channels
                let role = try await firebaseService.getMemberRole(
                    communityId: community.id, userId: userId, createdBy: community.createdBy
                ) ?? .member
                userRole = role.rawValue
                canManageChannels = role == .owner || role == .admin
                memberSince = await loadJoinDate(communityId: community.id, userId: userId)
            } else {
                userRole = "member"
                canManageChannels = false
                memberSince = nil
            }
            
            print("👤 User state loaded:")
            print("   Is member: \(isUserMember)")
            print("   Role: \(userRole)")
            print("   Can manage channels: \(canManageChannels)")
            
        } catch {
            await handleError(error, context: "loading user state")
        }
    }
    
    /// The member document's joinedAt, or nil if it's missing or can't be read
    private func loadJoinDate(communityId: String, userId: String) async -> Date? {
        let doc = try? await Firestore.firestore()
            .collection("communities").document(communityId)
            .collection("members").document(userId)
            .getDocument()
        return (doc?.data()?["joinedAt"] as? Timestamp)?.dateValue()
    }
    
    /// Check if we should prompt for channel setup
    private func checkChannelSetupNeeded() {
        // Only show setup prompt if:
        // 1. User can manage channels (owner/admin)
        // 2. There are no channels
        // 3. We haven't shown the prompt yet
        if canManageChannels && channels.isEmpty && !showSetupPrompt {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showSetupPrompt = true
            }
        }
    }
    
    /// Handle errors with user-friendly messages
    private func handleError(_ error: Error, context: String) async {
        let friendlyMessage = getFriendlyErrorMessage(error)
        errorMessage = "Error \(context): \(friendlyMessage)"
        print("❌ CommunityDetailViewModel - Error \(context): \(error)")
        
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
            return "Community or channel not found"
        } else {
            return "Something went wrong. Please try again."
        }
    }
    
    // MARK: - Community Management
    
    /// Check if user can perform admin actions
    func canPerformAdminAction() -> Bool {
        return userRole == "owner" || userRole == "admin"
    }
    
    /// Get formatted member count
    func getFormattedMemberCount() -> String {
        guard let community = community else { return "0" }
        
        if community.memberCount >= 1000 {
            return String(format: "%.1fK", Double(community.memberCount) / 1000.0)
        }
        return "\(community.memberCount)"
    }
    
    /// Get community stats for display
    func getCommunityStats() -> (members: String, channels: String, role: String) {
        return (
            members: getFormattedMemberCount(),
            channels: "\(channels.count)",
            role: userRole.capitalized
        )
    }
    
    // MARK: - Channel Management
    
    /// Create a new channel
    func createChannel(name: String, type: ChannelType, isAdminOnly: Bool) async throws {
        guard let community = community else {
            throw CommunityError.noCommunity
        }
        
        guard canManageChannels else {
            throw CommunityError.noPermission
        }
        
        let channel = Channel(
            name: name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            communityId: community.id,
            isDefault: false,
            adminOnly: isAdminOnly
        )
        
        try await firebaseService.createChannel(channel)
        
        // Refresh channels
        await loadChannels(for: community.id)
        
        print("✅ Created channel: #\(channel.name)")
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
        
        // Remove from local array
        channels.removeAll { $0.id == channel.id }
        
        print("✅ Deleted channel: #\(channel.name)")
    }
    
    // MARK: - Validation
    
    /// Validate channel name
    func validateChannelName(_ name: String) -> (isValid: Bool, message: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if trimmedName.isEmpty {
            return (false, "Channel name cannot be empty")
        }
        
        if trimmedName.count < 2 {
            return (false, "Channel name must be at least 2 characters")
        }
        
        if trimmedName.count > 50 {
            return (false, "Channel name must be less than 50 characters")
        }
        
        // Check for invalid characters
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if trimmedName.unicodeScalars.contains(where: { !allowedCharacters.contains($0) }) {
            return (false, "Channel names can only contain letters, numbers, hyphens, and underscores")
        }
        
        // Check if name already exists
        if channels.contains(where: { $0.name == trimmedName }) {
            return (false, "A channel with this name already exists")
        }
        
        return (true, "")
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = ""
    }
    
    // MARK: - Refresh Methods
    
    /// Refresh all community data
    func refreshAllData() {
        guard let community = community else { return }
        loadCommunityData(community: community)
    }
    
    /// Force refresh user membership status
    func refreshUserMembership() async {
        guard let community = community else { return }
        await loadUserState(for: community)
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
