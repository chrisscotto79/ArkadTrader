// File: Core/Profile/ViewModels/ProfileViewModel.swift
// Fixed Profile ViewModel - Removed duplicate Achievement struct

import Foundation
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    // Profile editing states
    @Published var isEditingProfile = false
    @Published var editedFullName = ""
    @Published var editedBio = ""
    @Published var editedUsername = ""
    
    // Profile stats
    @Published var totalTrades = 0
    @Published var activeTrades = 0
    @Published var totalProfitLoss: Double = 0.0
    @Published var winRate: Double = 0.0
    
    // Social features
    @Published var isFollowing = false
    @Published var followersCount = 0
    @Published var followingCount = 0
    
    // Profile posts/content - removed achievements array to avoid conflicts
    @Published var userPosts: [Post] = []
    @Published var userTrades: [Trade] = []
    
    private let authService = FirebaseAuthService.shared
    
    // MARK: - Initialization
    init() {
        loadUserProfile()
        setupInitialData()
    }
    
    // MARK: - Profile Data Loading
    func loadUserProfile() {
        isLoading = true
        
        Task {
            do {
                self.user = authService.currentUser
                await loadProfileStats()
                await loadUserContent()
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    private func setupInitialData() {
        guard let currentUser = authService.currentUser else { return }
        
        self.user = currentUser
        self.editedFullName = currentUser.fullName
        self.editedBio = currentUser.bio ?? ""
        self.editedUsername = currentUser.username
        self.followersCount = currentUser.followersCount
        self.followingCount = currentUser.followingCount
        self.totalProfitLoss = currentUser.totalProfitLoss
        self.winRate = currentUser.winRate
    }
    
    private func loadProfileStats() async {
        guard let userId = authService.currentUser?.id else { return }
        
        do {
            let trades = try await authService.getUserTrades(userId: userId)
            
            self.totalTrades = trades.count
            self.activeTrades = trades.filter { $0.isOpen }.count
            
            let closedTrades = trades.filter { !$0.isOpen }
            self.totalProfitLoss = closedTrades.reduce(0) { $0 + $1.profitLoss }
            
            if !closedTrades.isEmpty {
                let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
                self.winRate = Double(winningTrades) / Double(closedTrades.count) * 100
            }
            
            self.userTrades = trades
            
            // Update user stats in Firebase
            try await authService.updateUserStats(
                userId: userId,
                totalProfitLoss: totalProfitLoss,
                winRate: winRate
            )
            
        } catch {
            print("Error loading profile stats: \(error)")
        }
    }
    
    private func loadUserContent() async {
        // Load user's posts (this would be implemented when you have posts)
        // For now, using empty array
        self.userPosts = []
    }
    
    // MARK: - Profile Updates
    func updateProfile() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        do {
            try await authService.updateProfile(
                fullName: editedFullName.isEmpty ? nil : editedFullName,
                bio: editedBio.isEmpty ? nil : editedBio
            )
            
            // Update local user object
            if var updatedUser = self.user {
                updatedUser.fullName = editedFullName
                updatedUser.bio = editedBio.isEmpty ? nil : editedBio
                self.user = updatedUser
            }
            
            isEditingProfile = false
            isLoading = false
            
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    func startEditingProfile() {
        guard let currentUser = user else { return }
        
        editedFullName = currentUser.fullName
        editedBio = currentUser.bio ?? ""
        editedUsername = currentUser.username
        isEditingProfile = true
    }
    
    func cancelEditingProfile() {
        guard let currentUser = user else { return }
        
        editedFullName = currentUser.fullName
        editedBio = currentUser.bio ?? ""
        editedUsername = currentUser.username
        isEditingProfile = false
    }
    
    // MARK: - Social Features
    func followUser(userId: String) async {
        // Implement follow functionality when you add social features
        print("Following user: \(userId)")
        isFollowing = true
        followersCount += 1
    }
    
    func unfollowUser(userId: String) async {
        // Implement unfollow functionality when you add social features
        print("Unfollowing user: \(userId)")
        isFollowing = false
        followersCount -= 1
    }
    
    func shareProfile() {
        guard let user = user else { return }
        
        let shareText = """
        Check out @\(user.username) on ArkadTrader!
        
        📈 Win Rate: \(String(format: "%.1f", winRate))%
        💰 Total P&L: \(String(format: "%.2f", totalProfitLoss))
        🎯 Total Trades: \(totalTrades)
        
        Join the trading community: ArkadTrader
        """
        
        // Store in pasteboard for now - can implement proper sharing later
        UIPasteboard.general.string = shareText
    }
    
    // MARK: - Content Management
    func createPost(content: String) async {
        guard let userId = authService.currentUser?.id,
              let username = authService.currentUser?.username else { return }
        
        let newPost = Post(content: content, authorId: userId, authorUsername: username)
        
        do {
            try await authService.createPost(newPost)
            userPosts.insert(newPost, at: 0) // Add to beginning of array
        } catch {
            errorMessage = "Failed to create post: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func deletePost(postId: String) async {
        // Implement post deletion when you add this functionality
        userPosts.removeAll { $0.id == postId }
    }
    
    // MARK: - Logout
    func logout() {
        Task {
            await authService.logout()
            // Clear all local data
            self.user = nil
            self.userPosts = []
            self.userTrades = []
            self.totalTrades = 0
            self.activeTrades = 0
            self.totalProfitLoss = 0.0
            self.winRate = 0.0
            self.followersCount = 0
            self.followingCount = 0
        }
    }
    
    // MARK: - Helper Methods
    var profileCompletionPercentage: Double {
        guard let user = user else { return 0 }
        
        var completed = 0
        let total = 5
        
        if !user.fullName.isEmpty { completed += 1 }
        if !user.username.isEmpty { completed += 1 }
        if user.bio != nil && !user.bio!.isEmpty { completed += 1 }
        if totalTrades > 0 { completed += 1 }
        if followersCount > 0 || followingCount > 0 { completed += 1 }
        
        return Double(completed) / Double(total) * 100
    }
    
    var isProfileComplete: Bool {
        return profileCompletionPercentage >= 80
    }
    
    func refresh() async {
        await loadProfileStats()
        await loadUserContent()
    }
}

// MARK: - Profile Validation
extension ProfileViewModel {
    var isValidFullName: Bool {
        return editedFullName.count >= 2 && editedFullName.count <= 50
    }
    
    var isValidBio: Bool {
        return editedBio.count <= 150
    }
    
    var isValidUsername: Bool {
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        return NSPredicate(format: "SELF MATCHES %@", usernameRegex).evaluate(with: editedUsername)
    }
    
    var canSaveProfile: Bool {
        return isValidFullName && isValidBio && isValidUsername
    }
    
    func getValidationMessage() -> String? {
        if !isValidFullName {
            return "Name must be between 2 and 50 characters"
        }
        if !isValidBio {
            return "Bio must be 150 characters or less"
        }
        if !isValidUsername {
            return "Username must be 3-20 characters, letters, numbers, and underscores only"
        }
        return nil
    }
}
