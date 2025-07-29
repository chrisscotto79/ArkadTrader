// File: Core/Communities/Services/CommunityLeaderboardService.swift
// Simplified Community Leaderboard Service

import Foundation

@MainActor
class CommunityLeaderboardService: ObservableObject {
    
    static let shared = CommunityLeaderboardService()
    
    private let calculationService = LeaderboardCalculationService.shared
    
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private init() {}
    
    /// Get leaderboard for a community
    func getLeaderboard(communityId: String, category: LeaderboardCategory) async throws -> [CommunityLeaderboardEntry] {
        print("📊 Getting leaderboard for community: \(communityId)")
        
        isLoading = true
        defer { isLoading = false }
        
        let entries = await calculationService.calculateLeaderboard(for: communityId)
        return entries
    }
    
    /// Refresh leaderboard calculations
    func refreshLeaderboards(communityId: String) async throws {
        print("🔄 Refreshing leaderboard for community: \(communityId)")
        // Will implement when we add real data
    }
}
