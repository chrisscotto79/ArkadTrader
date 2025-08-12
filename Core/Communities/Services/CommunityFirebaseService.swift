// File: Core/Communities/Services/CommunityFirebaseService.swift
// Clean Community Firebase Service - NO DUPLICATE DECLARATIONS

import Foundation
import FirebaseFirestore
import Firebase
import FirebaseCore

@MainActor
class CommunityFirebaseService: ObservableObject {
    // MARK: - Singleton
    static let shared = CommunityFirebaseService()
    
    // MARK: - Dependencies
    let firebaseService = FirebaseServices.shared
    let authService = FirebaseAuthService.shared
    
    // MARK: - Init (PUBLIC - not private)
    init() {}
    
    // MARK: - Community CRUD Operations
    
    /// Create a new community
    func createCommunity(_ community: Community) async throws {
        try await firebaseService.createCommunity(community)
    }
    
    /// Update an existing community
    func updateCommunity(_ community: Community) async throws {
        try await firebaseService.updateCommunity(community)
    }
    
    /// Delete a community
    func deleteCommunity(communityId: String) async throws {
        try await firebaseService.deleteCommunity(communityId: communityId)
    }
    
    // MARK: - Community Data Loading
    
    // MARK: - Community Data Loading
    
    /// Load all communities for discovery
    func loadDiscoveryCommunities(limit: Int = 50) async throws -> [Community] {
        return try await firebaseService.getCommunities(limit: limit)
    }
    
    // ADD THE NEW METHOD HERE:
    /// Get communities owned by a specific user (alias for loadUserCreatedCommunities)
    
    
    /// Load featured communities (top by member count)
    func loadFeaturedCommunities(limit: Int = 5) async throws -> [Community] {
        let allCommunities = try await firebaseService.getCommunities(limit: 20)
        let featured = allCommunities
            .sorted { $0.memberCount > $1.memberCount }
            .prefix(limit)
        return Array(featured)
    }
    
    /// Load communities by category
    func loadCommunitiesByCategory(_ category: CommunityType, limit: Int = 20) async throws -> [Community] {
        let allCommunities = try await firebaseService.getCommunities(limit: 100)
        let filtered = allCommunities
            .filter { $0.type == category }
            .prefix(limit)
        return Array(filtered)
    }
    
    /// Load user's communities
    func loadUserCommunities(userId: String) async throws -> [Community] {
        return try await firebaseService.getUserCommunities(userId: userId)
    }
    
    /// Load communities created by user
    func loadUserCreatedCommunities(userId: String) async throws -> [Community] {
        let userCommunities = try await firebaseService.getUserCommunities(userId: userId)
        return userCommunities.filter { $0.createdBy == userId }
    }
    
    /// Load communities user is a member of (but didn't create)
    func loadUserMemberCommunities(userId: String) async throws -> [Community] {
        let userCommunities = try await firebaseService.getUserCommunities(userId: userId)
        return userCommunities.filter { $0.createdBy != userId }
    }
    
    // MARK: - Community Membership
    
    /// Join a community
    func joinCommunity(communityId: String, userId: String) async throws {
        try await firebaseService.joinCommunity(communityId: communityId, userId: userId)
    }
    
    /// Leave a community
    func leaveCommunity(communityId: String, userId: String) async throws {
        try await firebaseService.leaveCommunity(communityId: communityId, userId: userId)
    }
    
    /// Check if user is member of community
    func isUserMember(communityId: String, userId: String) async throws -> Bool {
        let userCommunities = try await firebaseService.getUserCommunities(userId: userId)
        return userCommunities.contains { $0.id == communityId }
    }
    
    /// Get community members
    func getCommunityMembersWithRoles(communityId: String) async throws -> [CommunityMemberWithRole] {
        let db = Firestore.firestore()
        
        print("🏁 Starting member lookup for community: \(communityId)")
        
        // First, try to get the community document directly
        let communityDoc = try await db.collection("communities").document(communityId).getDocument()
        
        guard communityDoc.exists, let communityData = communityDoc.data() else {
            print("❌ Community document not found: \(communityId)")
            throw FirestoreError.invalidData
        }
        
        let createdBy = communityData["createdBy"] as? String ?? ""
        print("👑 Community owner: \(createdBy)")
        
        // Get members from the subcollection
        let snapshot = try await db.collection("communities")
            .document(communityId)
            .collection("members")
            .getDocuments()
        
        var members: [CommunityMemberWithRole] = []
        
        print("🔍 Found \(snapshot.documents.count) members in subcollection")
        
        for document in snapshot.documents {
            let userId = document.documentID
            let memberData = document.data()
            
            print("👤 Processing member: \(userId)")
            print("📄 Member data keys: \(memberData.keys)")
            
            // Get actual user data using the existing getUserById method
            do {
                if let user = try await authService.getUserById(userId: userId) {
                    // Determine role - creator is owner, others are members
                    let role: CommunityRole = userId == createdBy ? .owner : .member
                    
                    let member = CommunityMemberWithRole(
                        userId: userId,
                        username: user.username,
                        fullName: user.fullName,
                        role: role,
                        joinedAt: Date()
                    )
                    members.append(member)
                    print("✅ Added member: \(user.fullName) (\(user.username)) as \(role.displayName)")
                } else {
                    print("⚠️ Could not find user details for \(userId)")
                    // Fallback to basic info
                    let member = CommunityMemberWithRole(
                        userId: userId,
                        username: "user\(userId.suffix(4))",
                        fullName: "User \(userId.suffix(4))",
                        role: userId == createdBy ? .owner : .member,
                        joinedAt: Date()
                    )
                    members.append(member)
                }
            } catch {
                print("❌ Error getting user details for member \(userId): \(error)")
                // Fallback to basic info
                let member = CommunityMemberWithRole(
                    userId: userId,
                    username: "user\(userId.suffix(4))",
                    fullName: "User \(userId.suffix(4))",
                    role: userId == createdBy ? .owner : .member,
                    joinedAt: Date()
                )
                members.append(member)
            }
        }
        
        print("🎯 Final member count: \(members.count)")
        
        // Sort by role hierarchy, then by name
        return members.sorted { lhs, rhs in
            if lhs.role.hierarchyLevel != rhs.role.hierarchyLevel {
                return lhs.role.hierarchyLevel > rhs.role.hierarchyLevel
            }
            return lhs.fullName < rhs.fullName
        }
    }
    // MARK: - Community Guidelines
    
    /// Check if community name is available
    func isNameAvailable(_ name: String) async throws -> Bool {
        let existingCommunities = try await firebaseService.searchCommunities(query: name)
        return !existingCommunities.contains {
            $0.name.lowercased() == name.lowercased()
        }
    }
    func deleteCommunityRule(communityId: String, ruleId: String) async throws {
        guard let currentUser = authService.currentUser else {
            throw FirestoreError.invalidData
        }
        
        // Check if user can manage this community
        let canManage = try await canUserManageCommunity(communityId: communityId, userId: currentUser.id)
        guard canManage else {
            throw FirestoreError.invalidData
        }
        
        let db = Firestore.firestore()
        let ruleRef = db.collection("communities")
            .document(communityId)
            .collection("rules")
            .document(ruleId)
        
        // Check if it's a default rule
        let ruleDoc = try await ruleRef.getDocument()
        if let data = ruleDoc.data(),
           let isDefault = data["isDefault"] as? Bool,
           isDefault {
            throw FirestoreError.invalidData // Cannot delete default financial disclaimer rules
        }
        
        try await ruleRef.delete()
        print("✅ Deleted custom rule from community")
    }
    func getCommunityRules(communityId: String) async throws -> [CommunityRule] {
        let db = Firestore.firestore()
        
        let snapshot = try await db.collection("communities")
            .document(communityId)
            .collection("rules")
            .order(by: "order")
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? CommunityRule.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    func addCommunityRule(communityId: String, rule: CommunityRule) async throws {
        guard let currentUser = authService.currentUser else {
            throw FirestoreError.invalidData
        }
        
        // Check if user can manage this community
        let canManage = try await canUserManageCommunity(communityId: communityId, userId: currentUser.id)
        guard canManage else {
            throw FirestoreError.invalidData
        }
        
        let db = Firestore.firestore()
        let ruleRef = db.collection("communities")
            .document(communityId)
            .collection("rules")
            .document(rule.id)
        
        try await ruleRef.setData(rule.toFirestore())
        print("✅ Added custom rule to community")
    }
    func createDefaultRules(communityId: String, rules: [CommunityRule]) async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for rule in rules {
            let ruleRef = db.collection("communities")
                .document(communityId)
                .collection("rules")
                .document(rule.id)
            
            batch.setData(rule.toFirestore(), forDocument: ruleRef)
        }
        
        try await batch.commit()
        print("✅ Created default financial disclaimer rules for community")
    }
    
    // MARK: - Community Search & Filtering
    
    /// Search communities by query (matches existing FirebaseServices method)
    func searchCommunities(query: String) async throws -> [Community] {
        return try await firebaseService.searchCommunities(query: query)
    }
    
    /// Advanced search with client-side filtering
    func searchCommunitiesAdvanced(query: String, category: CommunityType? = nil, includePrivate: Bool = false) async throws -> [Community] {
        // Get all search results from basic search
        var communities = try await firebaseService.searchCommunities(query: query)
        
        // Apply category filter if specified
        if let category = category {
            communities = communities.filter { $0.type == category }
        }
        
        // Apply privacy filter
        if !includePrivate {
            communities = communities.filter { !$0.isPrivate }
        }
        
        return communities
    }
    
    /// Filter communities by privacy setting
    func filterCommunitiesByPrivacy(_ communities: [Community], showPrivate: Bool) -> [Community] {
        if showPrivate {
            return communities
        } else {
            return communities.filter { !$0.isPrivate }
        }
    }
    
    /// Sort communities by different criteria
    func sortCommunities(_ communities: [Community], by sortType: CommunitySortType) -> [Community] {
        switch sortType {
        case .memberCount:
            return communities.sorted { $0.memberCount > $1.memberCount }
        case .newest:
            return communities.sorted { $0.createdAt > $1.createdAt }
        case .alphabetical:
            return communities.sorted { $0.name < $1.name }
        case .mostActive:
            // TODO: Implement when we have activity data
            return communities.sorted { $0.memberCount > $1.memberCount }
        }
    }
    
    // MARK: - Community Statistics
    /// Get community leaderboard data
    func getCommunityLeaderboards() async throws -> CommunityLeaderboards {
        let communities = try await firebaseService.getCommunities(limit: 100)
        
        let mostPopular = communities
            .sorted { $0.memberCount > $1.memberCount }
            .prefix(5)
        
        let newest = communities
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
        
        let mostActive = communities
            .sorted { $0.memberCount > $1.memberCount } // TODO: Use actual activity metric
            .prefix(5)
        
        return CommunityLeaderboards(
            mostPopular: Array(mostPopular),
            newest: Array(newest),
            mostActive: Array(mostActive)
        )
    }
    /// Get community count by type
    func getCommunityCount(for type: CommunityType) async throws -> Int {
        let communities = try await firebaseService.getCommunities(limit: 100)
        return communities.filter { $0.type == type }.count
    }
    
    /// Get total communities count
    func getTotalCommunitiesCount() async throws -> Int {
        let communities = try await firebaseService.getCommunities(limit: 1000)
        return communities.count
    }
    
    /// Get user community stats
    ///
    func getUserCommunityStats(userId: String) async throws -> UserCommunityStats {
        let userCommunities = try await firebaseService.getUserCommunities(userId: userId)
        let ownedCommunities = userCommunities.filter { $0.createdBy == userId }
        
        return UserCommunityStats(
            activeCommunities: userCommunities.count,
            globalRank: 0, // TODO: Implement ranking system
            totalMembers: userCommunities.reduce(0) { $0 + $1.memberCount },
            communitiesOwned: ownedCommunities.count,
            communitiesModerated: 0 // TODO: Implement moderation system
        )
    }
    
    // MARK: - Community Management
    
    /// Update community member role
    func updateMemberRole(communityId: String, userId: String, newRole: CommunityRole) async throws {
        // For now, we'll just validate the action
        // Later we can store roles in Firestore subcollection
        
        guard let currentUser = authService.currentUser else {
            throw FirestoreError.invalidData
        }
        
        // Check if current user can manage this community
        let canManage = try await canUserManageCommunity(communityId: communityId, userId: currentUser.id)
        guard canManage else {
            throw FirestoreError.invalidData
        }
        
        // TODO: Implement role storage in Firestore
        // For now, we'll just simulate success
        print("Would update user \(userId) to role \(newRole.rawValue) in community \(communityId)")
    }
    
    /// Check if user can manage community
    func canUserManageCommunity(communityId: String, userId: String) async throws -> Bool {
        // User can manage if they created the community
        let communities = try await firebaseService.getUserCommunities(userId: userId)
        return communities.contains { $0.id == communityId && $0.createdBy == userId }
    }
    /// Get communities owned by a specific user (alias for loadUserCreatedCommunities)
    func getUserOwnedCommunities(userId: String) async throws -> [Community] {
        return try await loadUserCreatedCommunities(userId: userId)
    }
    // MARK: - Validation Helpers
    
    /// Validate community name
    func validateCommunityName(_ name: String) -> (isValid: Bool, message: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return (false, "Community name is required")
        }
        
        if trimmedName.count < 3 {
            return (false, "Community name must be at least 3 characters")
        }
        
        if trimmedName.count > 30 {
            return (false, "Community name must be less than 30 characters")
        }
        
        // Check for inappropriate characters
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        if trimmedName.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return (false, "Community name can only contain letters, numbers, spaces, hyphens, and underscores")
        }
        
        return (true, "")
    }
    
    /// Validate community description
    func validateCommunityDescription(_ description: String) -> (isValid: Bool, message: String) {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedDescription.isEmpty {
            return (false, "Community description is required")
        }
        
        if trimmedDescription.count < 10 {
            return (false, "Description must be at least 10 characters")
        }
        
        if trimmedDescription.count > 280 {
            return (false, "Description must be less than 280 characters")
        }
        
        return (true, "")
    }
    
    /// Check if user can create more communities
    func canUserCreateCommunity(userId: String) async throws -> (canCreate: Bool, message: String) {
        let ownedCommunities = try await loadUserCreatedCommunities(userId: userId)
        let maxCommunities = 2 // As per your specification
        
        if ownedCommunities.count >= maxCommunities {
            return (false, "You've reached the maximum of \(maxCommunities) communities. Delete or transfer ownership of an existing community to create a new one.")
        }
        
        return (true, "")
    }
    
    // MARK: - Error Handling Helpers
    
    /// Handle common community errors - uses existing FirestoreError from FirebaseServices
    func handleCommunityError(_ error: Error) -> String {
        // Don't redeclare FirestoreError - use the existing one from FirebaseServices
        return "An error occurred: \(error.localizedDescription)"
        
    }
    func removeMemberFromCommunity(communityId: String, userId: String) async throws {
        guard let currentUser = authService.currentUser else {
            throw FirestoreError.invalidData
        }
        
        // Check if current user can manage this community
        let canManage = try await canUserManageCommunity(communityId: communityId, userId: currentUser.id)
        guard canManage else {
            throw FirestoreError.invalidData
        }
        
        // Don't allow removing the owner
        let community = try await getSingleCommunity(communityId: communityId)
        guard userId != community.createdBy else {
            throw FirestoreError.invalidData
        }
        
        // Remove from the members subcollection
        let db = Firestore.firestore()
        try await db.collection("communities")
            .document(communityId)
            .collection("members")
            .document(userId)
            .delete()
        
        // Also remove community from user's communityIds array
        try await leaveCommunity(communityId: communityId, userId: userId)
    }
    /// Get single community (helper method)
    private func getSingleCommunity(communityId: String) async throws -> Community {
        let communities = try await firebaseService.getCommunities(limit: 1000)
        guard let community = communities.first(where: { $0.id == communityId }) else {
            throw FirestoreError.invalidData
        }
        return community
    }
    
    
    /// Get user's role in community
    func getUserRole(communityId: String, userId: String) async throws -> CommunityRole {
        let community = try await getSingleCommunity(communityId: communityId)
        
        // For now, simple logic: creator is owner, everyone else is member
        // Later we'll check stored roles
        return userId == community.createdBy ? .owner : .member
    }
    
    
    // MARK: - Supporting Types
    
        
    
    
    /// Community leaderboard data
    
}

/// User community statistics
struct UserCommunityStats {
    let activeCommunities: Int
    let globalRank: Int
    let totalMembers: Int
    let communitiesOwned: Int
    let communitiesModerated: Int
}
/// Community activity item
struct CommunityActivity: Identifiable {
    let id: String
    let communityId: String
    let communityName: String
    let activityType: CommunityActivityType
    let description: String
    let timestamp: Date
    let userId: String?
    let username: String?
}

/// Types of community activities
enum CommunityActivityType {
    case created
    case memberJoined
    case memberLeft
    case messagePosted
    case calloutMade
    case settingsChanged
}
enum CommunitySortType: CaseIterable {
    case memberCount
    case newest
    case alphabetical
    case mostActive
    
    var displayName: String {
        switch self {
        case .memberCount: return "Most Members"
        case .newest: return "Newest"
        case .alphabetical: return "A-Z"
        case .mostActive: return "Most Active"
        }
    }
}

struct CommunityLeaderboards {
    let mostPopular: [Community]
    let newest: [Community]
    let mostActive: [Community]
}
