// File: Shared/Services/DataService.swift
// Simplified Data Service (for mock data)

import Foundation

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    
    @Published var posts: [Post] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    
    private init() {}
    
    // Helper method to create mock data if needed
    func createMockPosts() -> [Post] {
        return [
            Post(content: "Just closed my AAPL position with a +15% gain! 📈", authorId: "mock1", authorUsername: "trader1"),
            Post(content: "Market looking bullish today! SPY hitting new highs", authorId: "mock2", authorUsername: "trader2"),
            Post(content: "Anyone else watching TSLA today? 🚀", authorId: "mock3", authorUsername: "trader3")
        ]
    }
    
    func createMockLeaderboard() -> [LeaderboardEntry] {
        return [
            LeaderboardEntry(rank: 1, username: "ProTrader", profitLoss: 15240.50, winRate: 78.5, isVerified: true),
            LeaderboardEntry(rank: 2, username: "BullRunner", profitLoss: 12890.25, winRate: 72.3, isVerified: true),
            LeaderboardEntry(rank: 3, username: "MarketMaster", profitLoss: 11650.00, winRate: 69.8, isVerified: false)
        ]
    }
}
