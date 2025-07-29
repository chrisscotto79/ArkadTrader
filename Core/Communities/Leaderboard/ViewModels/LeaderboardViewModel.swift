// File: Core/Leaderboard/ViewModels/LeaderboardViewModel.swift
// Minimal LeaderboardViewModel - No mock data, uses existing LeaderboardEntry

import Foundation

@MainActor
class LeaderboardViewModel: ObservableObject {
    // Note: This uses the LeaderboardEntry from Shared/Models/LeaderboardEntry.swift
    @Published var leaderboard: [CommunityLeaderboardEntry] = []
    @Published var selectedTimeframe: TimeFrame = .weekly
    @Published var isLoading = false
    
    init() {
        // Don't load anything automatically
    }
    
    func loadLeaderboard() {
        isLoading = true
        
        // TODO: Connect to real data source
        // For now, just set empty array and stop loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.leaderboard = []
            self.isLoading = false
        }
    }
    
    func changeTimeframe(_ timeframe: TimeFrame) {
        selectedTimeframe = timeframe
        loadLeaderboard()
    }
}
