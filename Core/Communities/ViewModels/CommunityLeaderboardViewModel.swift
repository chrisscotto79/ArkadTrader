// File: Core/Communities/ViewModels/CommunityLeaderboardViewModel.swift
// Community Leaderboard ViewModel (different from existing LeaderboardViewModel)

import Foundation

@MainActor
class CommunityLeaderboardViewModel: ObservableObject {
    
    @Published var leaderboardEntries: [CommunityLeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let leaderboardService = CommunityLeaderboardService.shared
    
    /// Load leaderboard for a community
    func loadLeaderboard(communityId: String) {
        print("🚀 CommunityLeaderboardViewModel: Starting loadLeaderboard for: \(communityId)")
        
    
        Task {
            isLoading = true
            errorMessage = ""
            
            print("🚀 CommunityLeaderboardViewModel: About to call service.getLeaderboard")
            
            do {
                let entries = try await leaderboardService.getLeaderboard(
                    communityId: communityId,
                    category: .consistencyMasters
                )
                
                print("🚀 CommunityLeaderboardViewModel: Got \(entries.count) entries from service")
                
                // Sort by score and assign ranks
                let sortedEntries = entries.sorted { $0.score > $1.score }
                var rankedEntries: [CommunityLeaderboardEntry] = []
                
                for (index, var entry) in sortedEntries.enumerated() {
                    entry.rank = index + 1
                    rankedEntries.append(entry)
                }
                
                print("🚀 CommunityLeaderboardViewModel: Final entries count: \(rankedEntries.count)")
                
                leaderboardEntries = rankedEntries
                
            } catch {
                print("❌ CommunityLeaderboardViewModel: Error: \(error)")
                errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    /// Refresh the leaderboard
    func refresh(communityId: String) {
        loadLeaderboard(communityId: communityId)
    }
}
