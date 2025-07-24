//
//  CommunitySetupUtility.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/24/25.
//


// File: Core/Communities/Utils/CommunitySetupUtility.swift
// Utility to add default channels to existing communities

import Foundation

@MainActor
class CommunitySetupUtility {
    static let shared = CommunitySetupUtility()
    
    private let firebaseService = FirebaseServices.shared
    private let authService = FirebaseAuthService.shared
    
    private init() {}
    
    /// Add default channels to an existing community (for testing/migration)
    func addDefaultChannelsToExistingCommunity(_ community: Community) async throws {
        print("🔧 Adding default channels to existing community: \(community.name)")
        
        // Check if channels already exist
        let existingChannels = try await firebaseService.getCommunityChannels(communityId: community.id)
        
        if !existingChannels.isEmpty {
            print("ℹ️ Community already has \(existingChannels.count) channels")
            return
        }
        
        // Create default channels
        let defaultChannels = createDefaultChannels(for: community)
        
        for channel in defaultChannels {
            do {
                try await firebaseService.createChannel(channel)
                print("✅ Created channel: #\(channel.name)")
            } catch {
                print("❌ Failed to create channel #\(channel.name): \(error)")
                throw error
            }
        }
        
        // Send welcome messages
        try await sendWelcomeMessages(to: community, channels: defaultChannels)
        
        print("🎉 Successfully added default channels to: \(community.name)")
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
    private func sendWelcomeMessages(to community: Community, channels: [Channel]) async throws {
        guard let currentUser = authService.currentUser else { return }
        
        // Welcome message for general channel
        if let generalChannel = channels.first(where: { $0.name == "general" }) {
            let welcomeMessage = CommunityMessage(
                content: "🎉 Welcome to \(community.name)! This is the general discussion channel where all members can chat and share ideas.",
                authorId: currentUser.id,
                authorUsername: currentUser.username,
                channelId: generalChannel.id,
                communityId: community.id
            )
            
            try await firebaseService.sendCommunityMessage(welcomeMessage)
            print("✅ Sent welcome message to #general")
        }
        
        // Instructions for callouts channel
        if let calloutsChannel = channels.first(where: { $0.name == "callouts" }) {
            let instructionsMessage = CommunityMessage(
                content: """
📈 **CALLOUTS CHANNEL**

This channel is for trading callouts and signals. Only admins can post here.

Format your callouts like this:
**Symbol:** TSLA
**Action:** BUY
**Entry:** $245.50
**Stop Loss:** $240.00
**Target:** $255.00
**Notes:** Breaking resistance with volume
""",
                authorId: currentUser.id,
                authorUsername: currentUser.username,
                channelId: calloutsChannel.id,
                communityId: community.id
            )
            
            try await firebaseService.sendCommunityMessage(instructionsMessage)
            print("✅ Sent instructions to #callouts")
        }
    }
}

// MARK: - Extension for easy testing
extension CommunitySetupUtility {
    
    /// Quick setup method for testing - call this from your community detail view
    func quickSetupCommunity(_ community: Community) async {
        do {
            try await addDefaultChannelsToExistingCommunity(community)
            print("🚀 Quick setup completed for: \(community.name)")
        } catch {
            print("❌ Quick setup failed: \(error)")
        }
    }
}