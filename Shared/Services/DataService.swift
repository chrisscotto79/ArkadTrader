// File: Shared/Services/DataService.swift

import Foundation

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    
    @Published var trades: [Trade] = []
    @Published var posts: [Post] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoading = false
    
    private init() {
        loadMockData()
    }
    
    // MARK: - Mock Data Loading
    private func loadMockData() {
        loadMockTrades()
        loadMockPosts()
        loadMockLeaderboard()
    }
    
    // MARK: - Trade Methods
    func addTrade(_ trade: Trade) async throws {
        // Add to local array
        trades.append(trade)
        
        // Save to UserDefaults
        saveTrades()
    }
    
    func updateTrade(_ trade: Trade) async throws {
        if let index = trades.firstIndex(where: { $0.id == trade.id }) {
            trades[index] = trade
            saveTrades()
        }
    }
    
    func deleteTrade(_ trade: Trade) async throws {
        trades.removeAll { $0.id == trade.id }
        saveTrades()
    }
    
    // MARK: - Post Methods
    func addPost(_ post: Post) async throws {
        posts.insert(post, at: 0)
        savePosts()
    }
    
    // MARK: - Mock Data Generators
    private func loadMockTrades() {
        // Try to load from UserDefaults first
        if let data = UserDefaults.standard.data(forKey: "userTrades"),
           let savedTrades = try? JSONDecoder().decode([Trade].self, from: data) {
            self.trades = savedTrades
        }
    }
    
    private func loadMockPosts() {
        // Create some sample posts
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        posts = [
            Post(content: "Just closed my AAPL position with a +15% gain! 📈", authorId: userId, authorUsername: "currentuser"),
            Post(content: "Market looking bullish today! SPY breaking new highs 🚀", authorId: UUID(), authorUsername: "trader123"),
            Post(content: "Anyone else watching TSLA? Thinking about entering a position 🤔", authorId: UUID(), authorUsername: "stockmaster"),
            Post(content: "My portfolio is up 3.2% today! Best day this month 💪", authorId: UUID(), authorUsername: "daytrader99")
        ]
    }
    
    private func loadMockLeaderboard() {
        leaderboard = [
            LeaderboardEntry(rank: 1, username: "ProTrader", profitLoss: 15240.50, winRate: 78.5, isVerified: true),
            LeaderboardEntry(rank: 2, username: "BullRunner", profitLoss: 12890.25, winRate: 72.3, isVerified: true),
            LeaderboardEntry(rank: 3, username: "MarketMaster", profitLoss: 11650.00, winRate: 69.8, isVerified: false),
            LeaderboardEntry(rank: 4, username: "TradingGuru", profitLoss: 9875.75, winRate: 68.2, isVerified: true),
            LeaderboardEntry(rank: 5, username: "StockWiz", profitLoss: 8420.30, winRate: 65.7, isVerified: false),
            LeaderboardEntry(rank: 6, username: "DayTrader", profitLoss: 7850.00, winRate: 64.3, isVerified: false),
            LeaderboardEntry(rank: 7, username: "SwingKing", profitLoss: 6920.75, winRate: 62.8, isVerified: true),
            LeaderboardEntry(rank: 8, username: "OptionsPro", profitLoss: 5780.50, winRate: 61.2, isVerified: false),
            LeaderboardEntry(rank: 9, username: "CryptoQueen", profitLoss: 4650.25, winRate: 59.7, isVerified: true),
            LeaderboardEntry(rank: 10, username: "NewTrader", profitLoss: 3420.00, winRate: 58.1, isVerified: false)
        ]
    }
    
    // MARK: - Persistence
    private func saveTrades() {
        if let data = try? JSONEncoder().encode(trades) {
            UserDefaults.standard.set(data, forKey: "userTrades")
        }
    }
    
    private func savePosts() {
        // For now, posts are not persisted
        // Could implement persistence if needed
    }
    
    // MARK: - Refresh Methods
    func refreshAllData() async {
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Reload mock data
        loadMockData()
        
        isLoading = false
    }
}
