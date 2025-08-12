// File: Core/Communities/ViewModels/CommunitySettingsViewModel.swift
// Simple Community Settings ViewModel

import Foundation
import Firebase
import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import Combine

@MainActor
class CommunitySettingsViewModel: ObservableObject {
    @Published var settings: CommunitySettings
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showingDeleteConfirmation = false
    
    // Member management
    @Published var members: [CommunityMemberWithRole] = []
    @Published var isLoadingMembers = false
    @Published var selectedMemberForRemoval: CommunityMemberWithRole?
    
    // Community rules and moderation
    @Published var communityRules: [CommunityRule] = []
    @Published var moderationSettings = CommunityModerationSettings()
    @Published var isLoadingRules = false
    @Published var showingAddRule = false
    
    private let community: Community
    private let communityService = CommunityFirebaseService.shared
    private let authService = FirebaseAuthService.shared
    
    init(community: Community) {
        self.community = community
        self.settings = CommunitySettings(from: community)
    }
    
    // MARK: - Validation
    var canSave: Bool {
        !settings.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !settings.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        settings.name.count >= 3 &&
        settings.description.count >= 10
    }
    
    var isOwner: Bool {
        guard let currentUser = authService.currentUser else { return false }
        return community.createdBy == currentUser.id
    }
    
    // MARK: - Update Community
    func updateCommunity() async {
        guard canSave else {
            errorMessage = "Please fill in all required fields correctly"
            return
        }
        
        guard isOwner else {
            errorMessage = "Only the community owner can edit settings"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            // Validate name
            let nameValidation = communityService.validateCommunityName(settings.name)
            if !nameValidation.isValid {
                errorMessage = nameValidation.message
                isLoading = false
                return
            }
            
            // Validate description
            let descValidation = communityService.validateCommunityDescription(settings.description)
            if !descValidation.isValid {
                errorMessage = descValidation.message
                isLoading = false
                return
            }
            
            // Update the community
            let updatedCommunity = settings.updateCommunity(community)
            try await communityService.updateCommunity(updatedCommunity)
            
            // Success - the UI will dismiss automatically
            
        } catch {
            errorMessage = "Failed to update community: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Community Rules Management
    func loadCommunityRules() async {
        isLoadingRules = true
        
        do {
            communityRules = try await communityService.getCommunityRules(communityId: community.id)
            
            // If no rules exist, create default financial disclaimer rules
            if communityRules.isEmpty && isOwner {
                let defaultRules = CommunityRule.getDefaultTradingRules()
                try await communityService.createDefaultRules(communityId: community.id, rules: defaultRules)
                communityRules = defaultRules
            }
            
            // Sort by order
            communityRules.sort { $0.order < $1.order }
            
        } catch {
            errorMessage = "Failed to load community rules: \(error.localizedDescription)"
        }
        
        isLoadingRules = false
    }
    
    func addCustomRule(title: String, description: String, isRequired: Bool) async {
        guard isOwner else {
            errorMessage = "Only the community owner can add rules"
            return
        }
        
        let newOrder = (communityRules.map { $0.order }.max() ?? 0) + 1
        let customRule = CommunityRule(
            title: title,
            description: description,
            isRequired: isRequired,
            order: newOrder,
            isDefault: false
        )
        
        do {
            try await communityService.addCommunityRule(communityId: community.id, rule: customRule)
            communityRules.append(customRule)
            communityRules.sort { $0.order < $1.order }
        } catch {
            errorMessage = "Failed to add rule: \(error.localizedDescription)"
        }
    }
    
    func deleteRule(_ rule: CommunityRule) async {
        guard isOwner else {
            errorMessage = "Only the community owner can delete rules"
            return
        }
        
        guard !rule.isDefault else {
            errorMessage = "Cannot delete default financial disclaimer rules"
            return
        }
        
        do {
            try await communityService.deleteCommunityRule(communityId: community.id, ruleId: rule.id)
            communityRules.removeAll { $0.id == rule.id }
        } catch {
            errorMessage = "Failed to delete rule: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Delete Community
    func deleteCommunity() async {
        guard isOwner else {
            errorMessage = "Only the community owner can delete the community"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            try await communityService.deleteCommunity(communityId: community.id)
            // Success - the UI will handle navigation
        } catch {
            errorMessage = "Failed to delete community: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Helper Methods
    func resetSettings() {
        settings = CommunitySettings(from: community)
        errorMessage = ""
    }
    
    var hasChanges: Bool {
        settings.name != community.name ||
        settings.description != community.description ||
        settings.isPrivate != community.isPrivate
    }
    
    // MARK: - Member Management
    func loadMembers() async {
        print("🏁 Starting to load members for community: \(community.id)")
        isLoadingMembers = true
        errorMessage = ""
        
        do {
            members = try await communityService.getCommunityMembersWithRoles(communityId: community.id)
            print("✅ Successfully loaded \(members.count) members")
        } catch {
            print("❌ Failed to load members: \(error)")
            errorMessage = "Failed to load members: \(error.localizedDescription)"
        }
        
        isLoadingMembers = false
    }
    
    func removeMember(_ member: CommunityMemberWithRole) async {
        guard isOwner else {
            errorMessage = "Only the community owner can remove members"
            return
        }
        
        guard member.role != .owner else {
            errorMessage = "Cannot remove the community owner"
            return
        }
        
        isLoading = true
        
        do {
            try await communityService.removeMemberFromCommunity(
                communityId: community.id,
                userId: member.userId
            )
            
            // Remove from local list
            members.removeAll { $0.id == member.id }
            
        } catch {
            errorMessage = "Failed to remove member: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateMemberRole(_ member: CommunityMemberWithRole, to newRole: CommunityRole) async {
        guard isOwner else {
            errorMessage = "Only the community owner can change member roles"
            return
        }
        
        guard member.role != .owner else {
            errorMessage = "Cannot change the owner's role"
            return
        }
        
        isLoading = true
        
        do {
            try await communityService.updateMemberRole(
                communityId: community.id,
                userId: member.userId,
                newRole: newRole
            )
            
            // Update local list
            if let index = members.firstIndex(where: { $0.id == member.id }) {
                members[index] = CommunityMemberWithRole(
                    userId: member.userId,
                    username: member.username,
                    fullName: member.fullName,
                    role: newRole,
                    joinedAt: member.joinedAt
                )
            }
            
        } catch {
            errorMessage = "Failed to update member role: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
