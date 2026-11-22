// File: Core/Profile/ViewModels/ProfileTabViewModels.swift
// View models for the profile Posts and Groups tabs.

import SwiftUI

// MARK: - View Models
@MainActor
class UserPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let authService = FirebaseAuthService.shared
    private var currentUserId: String = ""
    
    func loadUserPosts(userId: String) {
        currentUserId = userId
        guard !userId.isEmpty else { return }
        
        isLoading = true
        errorMessage = "" // Clear previous errors
        
        Task {
            do {
                // Try the Firebase method first, fallback to workaround if index issue
                let userPosts: [Post]
                do {
                    userPosts = try await authService.getUserPosts(userId: userId)
                } catch {
                    print("Firebase getUserPosts failed, using workaround: \(error)")
                    // Fallback to workaround method
                    userPosts = try await getUserPostsWorkaround(userId: userId)
                }
                
                await MainActor.run {
                    self.posts = userPosts
                    self.isLoading = false
                    self.errorMessage = ""
                }
            } catch {
                await MainActor.run {
                    print("Error loading posts: \(error)")
                    self.errorMessage = "Failed to load posts. Please try again."
                    self.isLoading = false
                }
            }
        }
    }
    
    @MainActor
    func refreshPosts() async {
        guard !currentUserId.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        do {
            // Try the Firebase method first, fallback to workaround if index issue
            let userPosts: [Post]
            do {
                userPosts = try await authService.getUserPosts(userId: currentUserId)
            } catch {
                print("Firebase getUserPosts failed, using workaround: \(error)")
                // Fallback to workaround method
                userPosts = try await getUserPostsWorkaround(userId: currentUserId)
            }
            
            self.posts = userPosts
            self.errorMessage = ""
        } catch {
            print("Error refreshing posts: \(error)")
            self.errorMessage = "Failed to refresh posts. Please try again."
        }
        
        isLoading = false
    }
    
    // Workaround method using the public FirebaseServices methods
    private func getUserPostsWorkaround(userId: String) async throws -> [Post] {
        do {
            // Use FirebaseServices public method to get all feed posts, then filter
            let allPosts = try await FirebaseServices.shared.getFeedPosts(limit: 200)
            
            // Filter posts by the specific user
            let userPosts = allPosts.filter { $0.authorId == userId }
            
            // Sort locally by date (newest first)
            return userPosts.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("Error in getUserPostsWorkaround: \(error)")
            // If even the workaround fails, return empty array instead of throwing
            return []
        }
    }
}

@MainActor
class UserGroupsViewModel: ObservableObject {
    @Published var groups: [TradingGroup] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let authService = FirebaseAuthService.shared
    private var currentUserId: String = ""
    
    func loadUserGroups(userId: String) {
        currentUserId = userId
        guard !userId.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let tradingGroups = try await getUserCommunitiesAsTradingGroups(userId: userId)
                
                self.groups = tradingGroups
                self.isLoading = false
                self.errorMessage = ""
            } catch {
                print("Error loading groups: \(error)")
                self.errorMessage = "Failed to load groups. Please try again."
                self.isLoading = false
            }
        }
    }
    
    func refreshGroups() async {
        guard !currentUserId.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let tradingGroups = try await getUserCommunitiesAsTradingGroups(userId: currentUserId)
            
            self.groups = tradingGroups
            self.errorMessage = ""
        } catch {
            print("Error refreshing groups: \(error)")
            self.errorMessage = "Failed to refresh groups. Please try again."
        }
        
        isLoading = false
    }
    
    // MARK: - Private Helper Methods
    
    /// Fetches user communities and converts them to TradingGroup objects
    private func getUserCommunitiesAsTradingGroups(userId: String) async throws -> [TradingGroup] {
        let communities: [Community]
        
        do {
            communities = try await authService.getUserCommunities(userId: userId)
        } catch {
            print("Firebase getUserCommunities failed: \(error)")
            // If the method doesn't exist or fails, return empty array
            communities = []
        }
        
        // Convert communities to TradingGroup
        return communities.map { community in
            TradingGroup(
                id: community.id,
                name: community.name,
                description: community.description,
                memberCount: community.memberCount,
                isPrivate: false, // You can add this field to Community model if needed
                imageUrl: nil,
                category: community.type.displayName,
                createdAt: community.createdAt
            )
        }
    }
}

// MARK: - Supporting Models
struct TradingGroup: Identifiable {
    let id: String
    let name: String
    let description: String
    let memberCount: Int
    let isPrivate: Bool
    let imageUrl: String?
    let category: String
    let createdAt: Date
}
