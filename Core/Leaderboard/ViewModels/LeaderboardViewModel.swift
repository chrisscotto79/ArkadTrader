//
//  LeaderboardViewModel.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Core/Leaderboard/ViewModels/LeaderboardViewModel.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var selectedTimeframe: TimeFrame = .weekly
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var marketSentiment: MarketSentiment = .bullish
    @Published var bullishPercentage: Double = 68.0
    
    private let authService = FirebaseAuthService.shared
    private let firestoreService = FirestoreService.shared
    
    init() {
        loadLeaderboard()
    }
    
    func loadLeaderboard() {
        isLoading = true
        
        // TODO: Load leaderboard from Firestore
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.leaderboard = []
            self.isLoading = false
        }
    }
    
    func changeTimeframe(_ timeframe: TimeFrame) {
        selectedTimeframe = timeframe
        loadLeaderboard()
    }
    
    func refreshLeaderboard() {
        loadLeaderboard()
    }
    
    func followTrader(_ entry: LeaderboardEntry) {
        // TODO: Implement follow functionality
        print("Following trader: \(entry.username)")
    }
}
