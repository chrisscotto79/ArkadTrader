// File: Core/Communities/Models/LeaderboardCategory.swift
// Simplified Leaderboard Category - Just One for Now

import Foundation

enum LeaderboardCategory: String, CaseIterable {
    case consistencyMasters = "consistency_masters"
    
    var displayName: String {
        return "Consistency Masters"
    }
    
    var description: String {
        return "Highest win rates"
    }
}
