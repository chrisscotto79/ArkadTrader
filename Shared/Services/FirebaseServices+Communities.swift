// File: Shared/Services/FirebaseServices+Communities.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

extension FirebaseServices {
    // MARK: - Message Reactions
    func addMessageReaction(messageId: String, channelId: String, communityId: String, emoji: String, userId: String, username: String) async throws {
            print("🎭 Adding reaction \(emoji) to message \(messageId)")
            
            let reactionRef = db.collection("communities").document(communityId)
                .collection("channels").document(channelId)
                .collection("messages").document(messageId)
                .collection("reactions").document("\(userId)_\(emoji)")
            
            let reaction = MessageReaction(emoji: emoji, userId: userId, username: username)
            
            try await reactionRef.setData(reaction.toFirestore())
            
            print("✅ Successfully added reaction \(emoji) to Firebase")
        }
        
        /// Remove a reaction from a message
        func removeMessageReaction(messageId: String, channelId: String, communityId: String, emoji: String, userId: String) async throws {
            print("🗑️ Removing reaction \(emoji) from message \(messageId)")
            
            let reactionRef = db.collection("communities").document(communityId)
                .collection("channels").document(channelId)
                .collection("messages").document(messageId)
                .collection("reactions").document("\(userId)_\(emoji)")
            
            try await reactionRef.delete()
            
            print("✅ Successfully removed reaction \(emoji) from Firebase")
        }
        
        /// Get all reactions for a specific message
        func getMessageReactions(messageId: String, channelId: String, communityId: String) async throws -> [MessageReaction] {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("channels").document(channelId)
                .collection("messages").document(messageId)
                .collection("reactions")
                .getDocuments()
            
            let reactions = snapshot.documents.compactMap { document in
                try? MessageReaction.fromFirestore(data: document.data())
            }
            
            print("📊 Loaded \(reactions.count) reactions for message \(messageId)")
            return reactions
        }
        
        /// Listen to real-time reactions for all messages in a channel
    @discardableResult
    func listenToChannelReactions(communityId: String, channelId: String, completion: @escaping @Sendable ([String: [MessageReaction]]) -> Void) -> ListenerRegistration {
        print("👂 Setting up real-time reactions listener for channel \(channelId)")
        
        // Listen to all messages in the channel
        return db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages")
            .addSnapshotListener { [weak self] messagesSnapshot, error in
                guard let messagesSnapshot = messagesSnapshot else {
                    print("❌ Error fetching messages for reactions: \(error?.localizedDescription ?? "unknown")")
                    completion([:])
                    return
                }
                
                print("🔄 Messages snapshot changed, updating reactions...")
                
                Task { @MainActor in
                    await self?.processReactionsForMessages(
                        messagesSnapshot: messagesSnapshot,
                        channelId: channelId,
                        communityId: communityId,
                        completion: completion
                    )
                }
            }
    }

    @MainActor
    func processReactionsForMessages(
        messagesSnapshot: QuerySnapshot,
        channelId: String,
        communityId: String,
        completion: @escaping @Sendable ([String: [MessageReaction]]) -> Void
    ) async {
        var allReactions: [String: [MessageReaction]] = [:]
        
        // For each message, get its reactions
        for messageDoc in messagesSnapshot.documents {
            let messageId = messageDoc.documentID
            
            do {
                let reactions = try await getMessageReactions(
                    messageId: messageId,
                    channelId: channelId,
                    communityId: communityId
                )
                
                if !reactions.isEmpty {
                    allReactions[messageId] = reactions
                }
            } catch {
                print("❌ Error loading reactions for message \(messageId): \(error)")
            }
        }
        
        print("✅ Updated reactions for \(allReactions.count) messages")
        completion(allReactions)
    }
        
        /// Get popular emojis used in a channel (for emoji picker suggestions)
        func getPopularChannelEmojis(communityId: String, channelId: String, limit: Int = 8) async throws -> [String] {
            print("📊 Getting popular emojis for channel \(channelId)")
            
            let messagesSnapshot = try await db.collection("communities").document(communityId)
                .collection("channels").document(channelId)
                .collection("messages")
                .limit(to: 50) // Look at recent 50 messages
                .getDocuments()
            
            var emojiCount: [String: Int] = [:]
            
            // Count emoji usage across recent messages
            for messageDoc in messagesSnapshot.documents {
                let messageId = messageDoc.documentID
                
                let reactions = try await getMessageReactions(
                    messageId: messageId,
                    channelId: channelId,
                    communityId: communityId
                )
                
                for reaction in reactions {
                    emojiCount[reaction.emoji, default: 0] += 1
                }
            }
            
            // Return most popular emojis
            let popularEmojis = emojiCount
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { $0.key }
            
            print("✅ Found \(popularEmojis.count) popular emojis: \(popularEmojis)")
            return Array(popularEmojis)
        }
        
        /// Toggle reaction (add if not exists, remove if exists) - Alternative method
        func toggleMessageReaction(messageId: String, channelId: String, communityId: String, emoji: String, userId: String, username: String) async throws -> Bool {
            let reactionRef = db.collection("communities").document(communityId)
                .collection("channels").document(channelId)
                .collection("messages").document(messageId)
                .collection("reactions").document("\(userId)_\(emoji)")
            
            let reactionDoc = try await reactionRef.getDocument()
            
            if reactionDoc.exists {
                // Remove reaction
                try await reactionRef.delete()
                print("✅ Toggled OFF reaction \(emoji) for user \(userId)")
                return false // Reaction removed
            } else {
                // Add reaction
                let reaction = MessageReaction(emoji: emoji, userId: userId, username: username)
                try await reactionRef.setData(reaction.toFirestore())
                print("✅ Toggled ON reaction \(emoji) for user \(userId)")
                return true // Reaction added
            }
        }
        
        /// Get reaction stats for a message (count by emoji)
        func getMessageReactionStats(messageId: String, channelId: String, communityId: String) async throws -> [String: Int] {
            let reactions = try await getMessageReactions(messageId: messageId, channelId: channelId, communityId: communityId)
            
            var stats: [String: Int] = [:]
            for reaction in reactions {
                stats[reaction.emoji, default: 0] += 1
            }
            
            return stats
        }
        
        /// Check if a specific user has reacted to a message with a specific emoji
        func hasUserReacted(messageId: String, channelId: String, communityId: String, emoji: String, userId: String) async throws -> Bool {
            let reactionRef = db.collection("communities").document(communityId)
                .collection("channels").document(channelId)
                .collection("messages").document(messageId)
                .collection("reactions").document("\(userId)_\(emoji)")
            
            let reactionDoc = try await reactionRef.getDocument()
            return reactionDoc.exists
        }
        
        /// Get all users who reacted to a message with a specific emoji
        func getUsersWhoReacted(messageId: String, channelId: String, communityId: String, emoji: String) async throws -> [String] {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("channels").document(channelId)
                .collection("messages").document(messageId)
                .collection("reactions")
                .whereField("emoji", isEqualTo: emoji)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                document.data()["username"] as? String
            }
        }
    

    // MARK: - Community Management
    
    func createCommunity(_ community: Community) async throws {
        let batch = db.batch()
        
        // Create community document
        let communityRef = db.collection("communities").document(community.id)
        batch.setData(community.toFirestore(), forDocument: communityRef)
        
        // Add creator as first member with admin role
        let memberRef = communityRef.collection("members").document(community.createdBy)
        batch.setData([
            "userId": community.createdBy,
            "role": "admin",
            "joinedAt": Timestamp(date: Date())
        ], forDocument: memberRef)
        
        // Update user's community list
        let userRef = db.collection("users").document(community.createdBy)
        batch.updateData([
            "communityIds": FieldValue.arrayUnion([community.id])
        ], forDocument: userRef)
        
        try await batch.commit()
        
        // Create default channels after community is created
        try await createDefaultChannels(for: community.id)
    }
    
    func updateCommunity(_ community: Community) async throws {
        try await db.collection("communities").document(community.id).setData(community.toFirestore(), merge: true)
    }
    
    func deleteCommunity(communityId: String) async throws {
        let batch = db.batch()
        
        // Get all members
        let members = try await db.collection("communities").document(communityId)
            .collection("members").getDocuments()
        
        // Remove community from each member's list
        for member in members.documents {
            let userRef = db.collection("users").document(member.documentID)
            batch.updateData([
                "communityIds": FieldValue.arrayRemove([communityId])
            ], forDocument: userRef)
        }
        
        // Delete community
        batch.deleteDocument(db.collection("communities").document(communityId))
        
        try await batch.commit()
    }
    
    func getCommunities(limit: Int = 20) async throws -> [Community] {
        let snapshot = try await db.collection("communities")
            .whereField("isPrivate", isEqualTo: false)
            .order(by: "memberCount", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Community.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    func getUserCommunityIds(userId: String) async throws -> [String] {
        let firebaseServices = FirebaseServices.shared
        let userDoc = try await firebaseServices.db.collection("users").document(userId).getDocument()
        
        guard userDoc.exists else {
            print("⚠️ User document doesn't exist for ID: \(userId)")
            return []
        }
        
        let userData = userDoc.data() ?? [:]
        let communityIds = userData["communityIds"] as? [String] ?? []
        print("📋 User \(userId) is in \(communityIds.count) communities")
        return communityIds
    }

    
    func getUserCommunities(userId: String) async throws -> [Community] {
        let user = try await getUserById(userId: userId)
        guard let communityIds = user?.communityIds, !communityIds.isEmpty else { return [] }
        
        let snapshot = try await db.collection("communities")
            .whereField(FieldPath.documentID(), in: communityIds)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Community.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    
    // Replace your searchCommunities method in FirebaseServices.swift with this:

    func searchCommunities(query: String, limit: Int = 20) async throws -> [Community] {
        guard !query.isEmpty else { return [] }
        
        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 Searching communities for: '\(searchQuery)'")
        
        do {
            // FIRST: Let's get ALL communities to see what's actually in the database
            print("🔍 DEBUG: Getting ALL communities to see what exists...")
            let allCommunitiesSnapshot = try await db.collection("communities")
                .limit(to: 100)
                .getDocuments()
            
            print("📊 DEBUG: Found \(allCommunitiesSnapshot.documents.count) total communities:")
            for doc in allCommunitiesSnapshot.documents {
                if let name = doc.data()["name"] as? String {
                    print("   - Community: '\(name)' (contains '\(searchQuery)': \(name.lowercased().contains(searchQuery)))")
                }
            }
            
            // SECOND: Try the original search method
            print("🔍 DEBUG: Trying original range search...")
            let nameQuery = try await db.collection("communities")
                .whereField("name", isGreaterThanOrEqualTo: searchQuery)
                .whereField("name", isLessThan: searchQuery + "\u{f8ff}")
                .limit(to: limit)
                .getDocuments()
            
            print("📊 DEBUG: Range search found \(nameQuery.documents.count) communities")
            
            // THIRD: If range search fails, fall back to client-side filtering
            let communities: [Community]
            if nameQuery.documents.isEmpty && !allCommunitiesSnapshot.documents.isEmpty {
                print("🔄 DEBUG: Range search returned nothing, using client-side filtering...")
                
                communities = allCommunitiesSnapshot.documents.compactMap { document -> Community? in
                    guard let name = document.data()["name"] as? String else { return nil }
                    
                    // Check if name contains the search query (case-insensitive)
                    if name.lowercased().contains(searchQuery) {
                        do {
                            let community = try Community.fromFirestore(data: document.data(), id: document.documentID)
                            print("✅ DEBUG: Client-side match found: \(community.name)")
                            return community
                        } catch {
                            print("❌ DEBUG: Failed to parse community document \(document.documentID): \(error)")
                            return nil
                        }
                    }
                    return nil
                }
            } else {
                // Use the original results
                communities = nameQuery.documents.compactMap { document -> Community? in
                    do {
                        let community = try Community.fromFirestore(data: document.data(), id: document.documentID)
                        print("✅ DEBUG: Range search match: \(community.name)")
                        return community
                    } catch {
                        print("❌ DEBUG: Failed to parse community document \(document.documentID): \(error)")
                        return nil
                    }
                }
            }
            
            // Filter for privacy (only if user is authenticated)
            let filteredCommunities: [Community]
            if let currentUserId = Auth.auth().currentUser?.uid {
                print("🔍 DEBUG: Filtering for user \(currentUserId)")
                do {
                    let userCommunities = try await getUserCommunities(userId: currentUserId)
                    let userCommunityIds = Set(userCommunities.map { $0.id })
                    print("🔍 DEBUG: User is in \(userCommunityIds.count) communities: \(userCommunityIds)")
                    
                    filteredCommunities = communities.filter { community in
                        let isPublicOrMember = !community.isPrivate || userCommunityIds.contains(community.id)
                        print("🔍 DEBUG: Community '\(community.name)' - isPrivate: \(community.isPrivate), userIsMember: \(userCommunityIds.contains(community.id)), willShow: \(isPublicOrMember)")
                        return isPublicOrMember
                    }
                } catch {
                    print("⚠️ DEBUG: Couldn't get user communities, showing public only: \(error)")
                    filteredCommunities = communities.filter { !$0.isPrivate }
                }
            } else {
                print("⚠️ DEBUG: No authenticated user, showing public communities only")
                filteredCommunities = communities.filter { !$0.isPrivate }
            }
            
            print("🎯 DEBUG: Returning \(filteredCommunities.count) communities after privacy filtering")
            for community in filteredCommunities {
                print("   - Final result: '\(community.name)' (private: \(community.isPrivate))")
            }
            
            return filteredCommunities
            
        } catch {
            print("❌ Community search error: \(error)")
            throw SearchError.searchFailed("Failed to search communities: \(error.localizedDescription)")
        }
    }
    
    func getUserCommunityIds(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("communityMembers")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let communityIds = snapshot.documents.map { $0.data()["communityId"] as? String ?? "" }
        return Set(communityIds.filter { !$0.isEmpty })
    }
    
    func joinCommunity(communityId: String, userId: String) async throws {
        let batch = db.batch()
        
        // Add member to community
        let memberRef = db.collection("communities").document(communityId)
            .collection("members").document(userId)
        batch.setData([
            "userId": userId,
            "role": "member",
            "joinedAt": Timestamp(date: Date())
        ], forDocument: memberRef)
        
        // Update community member count
        let communityRef = db.collection("communities").document(communityId)
        batch.updateData([
            "memberCount": FieldValue.increment(Int64(1))
        ], forDocument: communityRef)
        
        // Add community to user's list
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "communityIds": FieldValue.arrayUnion([communityId])
        ], forDocument: userRef)
        
        try await batch.commit()
    }
    
    func leaveCommunity(communityId: String, userId: String) async throws {
        let batch = db.batch()
        
        // Remove member from community
        let memberRef = db.collection("communities").document(communityId)
            .collection("members").document(userId)
        batch.deleteDocument(memberRef)
        
        // Update community member count
        let communityRef = db.collection("communities").document(communityId)
        batch.updateData([
            "memberCount": FieldValue.increment(Int64(-1))
        ], forDocument: communityRef)
        
        // Remove community from user's list
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "communityIds": FieldValue.arrayRemove([communityId])
        ], forDocument: userRef)
        
        try await batch.commit()
    }
    
    func getCommunityMembers(communityId: String) async throws -> [User] {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("members").getDocuments()
        
        let userIds = snapshot.documents.map { $0.documentID }
        guard !userIds.isEmpty else { return [] }
        
        let usersSnapshot = try await db.collection("users")
            .whereField(FieldPath.documentID(), in: userIds)
            .getDocuments()
        
        return usersSnapshot.documents.compactMap { document in
            try? User.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    /// Every member's role in a community, keyed by user id. The creator is always the owner.
    func getCommunityMemberRoles(communityId: String) async throws -> [String: CommunityRole] {
        let communityRef = db.collection("communities").document(communityId)
        async let communityDoc = communityRef.getDocument()
        async let membersSnapshot = communityRef.collection("members").getDocuments()
        
        var roles: [String: CommunityRole] = [:]
        for doc in try await membersSnapshot.documents {
            roles[doc.documentID] = CommunityRole(rawValue: doc.data()["role"] as? String ?? "") ?? .member
        }
        if let createdBy = try await communityDoc.data()?["createdBy"] as? String {
            roles[createdBy] = .owner
        }
        return roles
    }
    
    /// A single user's role, or nil if they aren't a member.
    func getMemberRole(communityId: String, userId: String, createdBy: String) async throws -> CommunityRole? {
        if userId == createdBy { return .owner }
        let doc = try await db.collection("communities").document(communityId)
            .collection("members").document(userId).getDocument()
        guard doc.exists else { return nil }
        return CommunityRole(rawValue: doc.data()?["role"] as? String ?? "") ?? .member
    }
    
    func updateCommunityMemberRole(communityId: String, userId: String, role: String) async throws {
        try await db.collection("communities").document(communityId)
            .collection("members").document(userId)
            .updateData(["role": role])
    }
    
    // MARK: - Channel Management
    
    func createDefaultChannels(for communityId: String) async throws {
        let batch = db.batch()
        
        // Create #general channel
        let generalChannel = Channel(
            name: "general",
            type: .text,
            communityId: communityId,
            isDefault: true,
            adminOnly: false
        )
        
        let generalRef = db.collection("communities").document(communityId)
            .collection("channels").document(generalChannel.id)
        batch.setData(generalChannel.toFirestore(), forDocument: generalRef)
        
        // Create #callouts channel
        let calloutsChannel = Channel(
            name: "callouts",
            type: .callouts,
            communityId: communityId,
            isDefault: true,
            adminOnly: true
        )
        
        let calloutsRef = db.collection("communities").document(communityId)
            .collection("channels").document(calloutsChannel.id)
        batch.setData(calloutsChannel.toFirestore(), forDocument: calloutsRef)
        
        try await batch.commit()
    }
    
    func getCommunityChannels(communityId: String) async throws -> [Channel] {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("channels")
            .order(by: "createdAt", descending: false)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Channel.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func createChannel(_ channel: Channel) async throws {
        let channelRef = db.collection("communities").document(channel.communityId)
            .collection("channels").document(channel.id)
        
        try await channelRef.setData(channel.toFirestore())
    }
    
    func deleteChannel(channelId: String, communityId: String) async throws {
        // First check if it's a default channel
        let channelSnapshot = try await db.collection("communities").document(communityId)
            .collection("channels").document(channelId).getDocument()
        
        if let data = channelSnapshot.data(),
           let isDefault = data["isDefault"] as? Bool,
           isDefault {
            throw NSError(domain: "CommunityError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Cannot delete default channels"])
        }
        
        // Delete the channel
        try await db.collection("communities").document(communityId)
            .collection("channels").document(channelId).delete()
    }
    
    // MARK: - Community Message Methods
    
    func sendCommunityMessage(_ message: CommunityMessage) async throws {
        let messageRef = db.collection("communities").document(message.communityId)
            .collection("channels").document(message.channelId)
            .collection("messages").document(message.id)
        
        try await messageRef.setData(message.toFirestore())
    }
    
    func getChannelMessages(communityId: String, channelId: String, limit: Int = 50) async throws -> [CommunityMessage] {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let messages = snapshot.documents.compactMap { document in
            try? CommunityMessage.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        return messages.reversed() // Return in chronological order
    }
    
    @discardableResult
    func listenToChannelMessages(communityId: String, channelId: String, completion: @escaping ([CommunityMessage]) -> Void) -> ListenerRegistration {
        return db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching channel messages: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let messages = documents.compactMap { document -> CommunityMessage? in
                    try? CommunityMessage.fromFirestore(data: document.data(), id: document.documentID)
                }
                
                completion(messages)
            }
    }
    
    func deleteCommunityMessage(messageId: String, communityId: String, channelId: String) async throws {
        try await db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages").document(messageId)
            .delete()
    }
    
    func editCommunityMessage(messageId: String, channelId: String, communityId: String, newContent: String) async throws {
        let messageRef = db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages").document(messageId)
        
        try await messageRef.updateData([
            "content": newContent,
            "editedAt": Timestamp(date: Date()),
            "isEdited": true
        ])
    }
    
    func canUserModifyMessage(messageId: String, channelId: String, communityId: String, userId: String) async throws -> (canEdit: Bool, canDelete: Bool) {
        // Get the message
        let messageRef = db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("messages").document(messageId)
        
        let messageSnapshot = try await messageRef.getDocument()
        
        guard let messageData = messageSnapshot.data(),
              let authorId = messageData["authorId"] as? String,
              let createdAtTimestamp = messageData["createdAt"] as? Timestamp else {
            return (false, false)
        }
        
        let isOwner = authorId == userId
        let createdAt = createdAtTimestamp.dateValue()
        let timeSinceCreated = Date().timeIntervalSince(createdAt)
        let editTimeLimit: TimeInterval = 5 * 60 // 5 minutes
        
        // Check if user is admin/owner of community
        let communityRef = db.collection("communities").document(communityId)
        let communitySnapshot = try await communityRef.getDocument()
        let isAdmin = communitySnapshot.data()?["createdBy"] as? String == userId
        
        let canEdit = isOwner && timeSinceCreated <= editTimeLimit
        let canDelete = isOwner || isAdmin
        
        return (canEdit, canDelete)
    }
    
    // MARK: - Typing Indicators
    
    /// Live list of people typing in a channel: (userId, username), excluding stale entries older than 8 seconds.
    func listenToTyping(communityId: String, channelId: String, completion: @escaping ([(userId: String, username: String)]) -> Void) -> ListenerRegistration {
        db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("typing")
            .addSnapshotListener { snapshot, _ in
                let cutoff = Date().addingTimeInterval(-8)
                let typing = (snapshot?.documents ?? []).compactMap { doc -> (userId: String, username: String)? in
                    let data = doc.data()
                    guard let username = data["username"] as? String,
                          let lastSeen = (data["lastSeen"] as? Timestamp)?.dateValue(),
                          lastSeen > cutoff else { return nil }
                    return (doc.documentID, username)
                }
                completion(typing)
            }
    }
    
    func setUserTyping(userId: String, username: String, channelId: String, communityId: String, isTyping: Bool) async throws {
        let typingRef = db.collection("communities").document(communityId)
            .collection("channels").document(channelId)
            .collection("typing").document(userId)
        
        if isTyping {
            try await typingRef.setData([
                "userId": userId,
                "username": username,
                "isTyping": true,
                "lastSeen": Timestamp(date: Date())
            ])
        } else {
            try await typingRef.delete()
        }
    }
}
