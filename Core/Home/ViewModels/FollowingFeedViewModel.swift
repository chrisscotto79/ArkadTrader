import Foundation
import SwiftUI

@MainActor
class FollowingFeedViewModel: ObservableObject {
    @Published var followingPosts: [Post] = []
    @Published var followingTrades: [Trade] = []
    @Published var followingActivity: [ActivityItem] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = FirebaseAuthService.shared
    
    func loadFollowingContent() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        do {
            async let posts = authService.getFollowingPosts(userId: currentUserId)
            async let trades = authService.getFollowingTrades(userId: currentUserId)
            async let activity = authService.getFollowingActivity(userId: currentUserId)
            
            followingPosts = try await posts
            followingTrades = try await trades
            followingActivity = try await activity
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    func refreshContent() async {
        await loadFollowingContent()
    }
}
