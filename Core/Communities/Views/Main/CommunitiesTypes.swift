// File: Core/Communities/Views/Main/CommunitiesTypes.swift
// Tab enums and the haptics helper for the Communities screen.

import SwiftUI

// MARK: - Haptic Manager Extension
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - Supporting Types
enum CommunityMainTab: CaseIterable {
    case discover
    case myCommunities
    case leaderboard
    
    var displayName: String {
        switch self {
        case .discover: return "Discover"
        case .myCommunities: return "My Communities"
        case .leaderboard: return "Leaderboard"
        }
    }
}

enum LeaderboardMode: CaseIterable {
    case communities
    case globalTraders
    
    var displayName: String {
        switch self {
        case .communities: return "Communities"
        case .globalTraders: return "Global Traders"
        }
    }
}
