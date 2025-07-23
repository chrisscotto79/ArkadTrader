// File: Core/Communities/ViewModels/CommunityDetailViewModel.swift
// CommunityDetailViewModel - Handles Community Detail Data Loading

import Foundation
import Combine

@MainActor
class CommunityDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var channels: [Channel] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // Community info
    @Published var community: Community?
    @Published var memberCount = 0
    @Published var userRole: String = "member"
    
    // MARK: - Private Properties
    private let firebaseService = FirebaseServices.shared
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Public Methods
    
    /// Load community data and channels
    func loadCommunityData(community: Community) {
        self.community = community
        
        Task {
            isLoading = true
            errorMessage = ""
            
            // Load channels and user role concurrently
            async let channelsTask = loadChannels(for: community.id)
            async let userRoleTask = loadUserRole(communityId: community.id)
            
            await channelsTask
            await userRoleTask
            
            isLoading = false
        }
    }
    
    /// Refresh community data
    func refreshData() {
        guard let community = community else { return }
        loadCommunityData(community: community)
    }
    
    // MARK: - Private Methods
    
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
                } else {
                    // Within the same category, sort alphabetically
                    return channel1.name < channel2.name
                }
            }
            
            channels = sortedChannels
            
        } catch {
            await handleError(error, context: "loading channels")
        }
    }
    
    /// Load user's role in the community
    private func loadUserRole(communityId: String) async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            // For now, we'll check if user is the creator (owner)
            if let community = community, community.createdBy == userId {
                userRole = "admin"
            } else {
                userRole = "member"
            }
            
            // TODO: Load actual role from Firebase when we implement role system
            
        } catch {
            await handleError(error, context: "loading user role")
        }
    }
    
    /// Handle errors and update UI
    private func handleError(_ error: Error, context: String) async {
        await MainActor.run {
            self.errorMessage = "Failed to load \(context): \(error.localizedDescription)"
            print("❌ CommunityDetailViewModel Error [\(context)]: \(error)")
        }
    }
    
    // MARK: - Helper Properties
    
    /// Check if current user is admin/owner
    var isUserAdmin: Bool {
        return userRole == "admin" || userRole == "owner"
    }
    
    /// Check if user can create channels
    var canCreateChannels: Bool {
        return isUserAdmin
    }
    
    /// Get default channels (general, callouts)
    var defaultChannels: [Channel] {
        return channels.filter { $0.isDefault }
    }
    
    /// Get custom channels
    var customChannels: [Channel] {
        return channels.filter { !$0.isDefault }
    }
}
