//
//  CommunityInitializationService.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/24/25.
//


// File: Core/Communities/Services/CommunityInitializationService.swift
// Service to handle community setup and default channel creation

import Foundation

@MainActor
class CommunityInitializationService {
    static let shared = CommunityInitializationService()
    
    private let firebaseService = FirebaseServices.shared
    
    private init() {}
    
    /// Initialize a newly created community with default channels
    func initializeCommunity(_ community: Community) async throws {
        print("🏗️ Initializing community: \(community.name)")
        
        // Create default channels
        try await createDefaultChannels(for: community)
        
        print("✅ Community initialization complete for: \(community.name)")
    }
    
    /// Create the default channels for a community
    private func createDefaultChannels(for community: Community) async throws {
        let defaultChannels = getDefaultChannels(for: community)
        
        for channel in defaultChannels {
            do {
                try await firebaseService.createChannel(channel)
                print("✅ Created default channel: #\(channel.name)")
            } catch {
                print("❌ Failed to create channel #\(channel.name): \(error)")
                throw error
            }
        }
    }
    
    /// Get the list of default channels for a community
    private func getDefaultChannels(for community: Community) -> [Channel] {
        var channels: [Channel] = []
        
        // 1. General Channel (always created, everyone can post)
        let generalChannel = Channel(
            name: "general",
            type: .text,
            communityId: community.id,
            isDefault: true,
            adminOnly: false
        )
        channels.append(generalChannel)
        
        // 2. Callouts Channel (admin-only posting for trading signals)
        let calloutsChannel = Channel(
            name: "callouts",
            type: .callouts,
            communityId: community.id,
            isDefault: true,
            adminOnly: true
        )
        channels.append(calloutsChannel)
        
        // 3. Optional: Add type-specific default channels
        switch community.type {
        case .dayTrading:
            // Day trading communities get a real-time alerts channel
            let alertsChannel = Channel(
                name: "live-alerts",
                type: .text,
                communityId: community.id,
                isDefault: true,
                adminOnly: true
            )
            channels.append(alertsChannel)
            
        case .crypto:
            // Crypto communities get a news channel
            let newsChannel = Channel(
                name: "crypto-news",
                type: .text,
                communityId: community.id,
                isDefault: true,
                adminOnly: false
            )
            channels.append(newsChannel)
            
        case .options:
            // Options communities get a strategies channel
            let strategiesChannel = Channel(
                name: "strategies",
                type: .text,
                communityId: community.id,
                isDefault: true,
                adminOnly: false
            )
            channels.append(strategiesChannel)
            
        default:
            // General and other types just get the basic channels
            break
        }
        
        return channels
    }
    
    /// Send a welcome message to the general channel
    func sendWelcomeMessage(to community: Community, creatorUsername: String) async throws {
        // Find the general channel
        let channels = try await firebaseService.getCommunityChannels(communityId: community.id)
        guard let generalChannel = channels.first(where: { $0.name == "general" }) else {
            print("⚠️ No general channel found to send welcome message")
            return
        }
        
        let welcomeMessage = CommunityMessage(
            content: "🎉 Welcome to \(community.name)! This community was created by @\(creatorUsername). Use this channel for general discussion and introductions.",
            authorId: "system",
            authorUsername: "ArkadTrader",
            channelId: generalChannel.id,
            communityId: community.id
        )
        
        try await firebaseService.sendCommunityMessage(welcomeMessage)
        print("✅ Sent welcome message to #general")
    }
    
    /// Send initial callout instructions to the callouts channel
    func sendCalloutInstructions(to community: Community) async throws {
        let channels = try await firebaseService.getCommunityChannels(communityId: community.id)
        guard let calloutsChannel = channels.first(where: { $0.name == "callouts" }) else {
            print("⚠️ No callouts channel found to send instructions")
            return
        }
        
        let instructionsMessage = CommunityMessage(
            content: """
            📈 **CALLOUTS CHANNEL**
            
            This channel is for admins to post trading callouts and signals. Format your callouts like this:
            
            **Symbol:** TSLA
            **Action:** BUY
            **Entry:** $245.50
            **Stop Loss:** $240.00
            **Target:** $255.00
            **Notes:** Breaking resistance with volume
            
            Members can view and follow these callouts for trading ideas.
            """,
            authorId: "system",
            authorUsername: "ArkadTrader",
            channelId: calloutsChannel.id,
            communityId: community.id
        )
        
        try await firebaseService.sendCommunityMessage(instructionsMessage)
        print("✅ Sent callout instructions to #callouts")
    }
}

// MARK: - Extension to CommunityFirebaseService
extension CommunityFirebaseService {
    /// Create a community with proper initialization
    func createCommunityWithInitialization(_ community: Community, creatorUsername: String) async throws {
        // 1. Create the community document
        try await createCommunity(community)
        print("✅ Community document created: \(community.name)")
        
        // 2. Initialize with default channels and messages
        try await CommunityInitializationService.shared.initializeCommunity(community)
        
        // 3. Send welcome messages
        try await CommunityInitializationService.shared.sendWelcomeMessage(
            to: community,
            creatorUsername: creatorUsername
        )
        
        try await CommunityInitializationService.shared.sendCalloutInstructions(to: community)
        
        print("🎉 Community fully initialized: \(community.name)")
    }
}