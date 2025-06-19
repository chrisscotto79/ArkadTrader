//
//  DataService.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Services/DataService.swift

// File: Shared/Services/DataService.swift

import Foundation

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    
    @Published var trades: [Trade] = []
    @Published var posts: [Post] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    
    private init() {
        loadMockData()
    }
    
    // MARK: - Trade Methods
    func addTrade(_ trade: Trade) {
        trades.append(trade)
        saveTrades()
    }
    
    func updateTrade(_ trade: Trade) {
        if let index = trades.firstIndex(where: { $0.id == trade.id }) {
            trades[index] = trade
            saveTrades()
        }
    }
    
    func deleteTrade(_ trade: Trade) {
        trades.removeAll { $0.id == trade.id }
        saveTrades()
    }
    
    // MARK: - Post Methods
    func addPost(_ post: Post) {
        posts.insert(post, at: 0)
        savePosts()
    }
    
    // MARK: - Data Persistence
    private func saveTrades() {
        if let data = try? JSONEncoder().encode(trades) {
            UserDefaults.standard.set(data, forKey: "savedTrades")
        }
    }
    
    private func loadTrades() {
        if let data = UserDefaults.standard.data(forKey: "savedTrades"),
           let savedTrades = try? JSONDecoder().decode([Trade].self, from: data) {
            self.trades = savedTrades
        }
    }
    
    private func savePosts() {
        if let data = try? JSONEncoder().encode(posts) {
            UserDefaults.standard.set(data, forKey: "savedPosts")
        }
    }
    
    private func loadPosts() {
        if let data = UserDefaults.standard.data(forKey: "savedPosts"),
           let savedPosts = try? JSONDecoder().decode([Post].self, from: data) {
            self.posts = savedPosts
        }
    }
    
    private func loadMockData() {
        loadTrades()
        loadPosts()
        
        // Add mock leaderboard data
        leaderboard = [
            LeaderboardEntry(rank: 1, username: "ProTrader", profitLoss: 15240.50, winRate: 78.5, isVerified: true),
            LeaderboardEntry(rank: 2, username: "BullRunner", profitLoss: 12890.25, winRate: 72.3, isVerified: true),
            LeaderboardEntry(rank: 3, username: "MarketMaster", profitLoss: 11650.00, winRate: 69.8, isVerified: false),
            LeaderboardEntry(rank: 4, username: "TradingGuru", profitLoss: 9875.75, winRate: 68.2, isVerified: true),
            LeaderboardEntry(rank: 5, username: "StockWiz", profitLoss: 8420.30, winRate: 65.7, isVerified: false)
        ]
    }
}
