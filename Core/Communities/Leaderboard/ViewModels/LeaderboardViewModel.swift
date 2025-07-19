// File: Core/Leaderboard/ViewModels/LeaderboardViewModel.swift
// Simplified Leaderboard ViewModel

import Foundation

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var selectedTimeframe: TimeFrame = .weekly
    @Published var isLoading = false
    
    init() {
        loadLeaderboard()
    }
    
    func loadLeaderboard() {
        isLoading = true
        
        // For now, use mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.leaderboard = DataService.shared.createMockLeaderboard()
            self.isLoading = false
        }
    }
    
    func changeTimeframe(_ timeframe: TimeFrame) {
        selectedTimeframe = timeframe
        loadLeaderboard()
    }
}
