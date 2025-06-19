// File: Shared/Services/DataService.swift
// Fixed version without conflicts

import Foundation

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    private let networkService = NetworkService.shared
    
    @Published var trades: [Trade] = []
    @Published var posts: [Post] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoading = false
    
    private init() {
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Initial Data Loading
    private func loadInitialData() async {
        // Load data only if user is authenticated
        guard AuthService.shared.isAuthenticated,
              let userId = AuthService.shared.currentUser?.id.uuidString else {
            return
        }
        
        isLoading = true
        
        // Load data sequentially to avoid type issues
        await loadTrades(for: userId)
        await loadLeaderboard()
        await loadPosts()
        
        isLoading = false
    }
    
    // MARK: - Trade Methods
    func loadTrades(for userId: String) async {
        do {
            self.trades = try await networkService.fetchTrades(userId: userId)
        } catch {
            print("Failed to load trades: \(error)")
            // Fallback to mock data for development
            loadMockTrades()
        }
    }
    
    func addTrade(_ trade: Trade) async throws {
        let createRequest = CreateTradeRequest(
            ticker: trade.ticker,
            tradeType: trade.tradeType,
            entryPrice: trade.entryPrice,
            quantity: trade.quantity,
            notes: trade.notes,
            strategy: trade.strategy
        )
        
        do {
            let newTrade = try await networkService.createTrade(createRequest)
            self.trades.append(newTrade)
        } catch {
            print("Failed to add trade: \(error)")
            throw error
        }
    }
    
    func updateTrade(_ trade: Trade) async throws {
        let updateRequest = UpdateTradeRequest(
            exitPrice: trade.exitPrice,
            notes: trade.notes,
            strategy: trade.strategy
        )
        
        do {
            let updatedTrade = try await networkService.updateTrade(
                id: trade.id.uuidString,
                updateRequest
            )
            
            if let index = trades.firstIndex(where: { $0.id == trade.id }) {
                trades[index] = updatedTrade
            }
        } catch {
            print("Failed to update trade: \(error)")
            throw error
        }
    }
    
    func deleteTrade(_ trade: Trade) async throws {
        do {
            try await networkService.deleteTrade(id: trade.id.uuidString)
            trades.removeAll { $0.id == trade.id }
        } catch {
            print("Failed to delete trade: \(error)")
            throw error
        }
    }
    
    // MARK: - Post Methods
    func loadPosts() async {
        do {
            self.posts = try await networkService.fetchFeed()
        } catch {
            print("Failed to load posts: \(error)")
            // Fallback to mock data for development
            loadMockPosts()
        }
    }
    
    func addPost(_ post: Post) async throws {
        let createRequest = CreatePostRequest(
            content: post.content,
            imageURL: post.imageURL,
            postType: post.postType,
            tradeId: nil // Optional parameter
        )
        
        do {
            let newPost = try await networkService.createPost(createRequest)
            self.posts.insert(newPost, at: 0)
        } catch {
            print("Failed to add post: \(error)")
            throw error
        }
    }
    
    // MARK: - Leaderboard Methods
    func loadLeaderboard(timeframe: String = "weekly") async {
        do {
            self.leaderboard = try await networkService.fetchLeaderboard(timeframe: timeframe)
        } catch {
            print("Failed to load leaderboard: \(error)")
            // Fallback to mock data for development
            loadMockLeaderboard()
        }
    }
    
    // MARK: - Mock Data (for development/testing)
    private func loadMockTrades() {
        // Keep existing mock trades for development
        trades = []
    }
    
    private func loadMockPosts() {
        // Keep existing mock posts for development
        posts = []
    }
    
    private func loadMockLeaderboard() {
        leaderboard = [
            LeaderboardEntry(rank: 1, username: "ProTrader", profitLoss: 15240.50, winRate: 78.5, isVerified: true),
            LeaderboardEntry(rank: 2, username: "BullRunner", profitLoss: 12890.25, winRate: 72.3, isVerified: true),
            LeaderboardEntry(rank: 3, username: "MarketMaster", profitLoss: 11650.00, winRate: 69.8, isVerified: false),
            LeaderboardEntry(rank: 4, username: "TradingGuru", profitLoss: 9875.75, winRate: 68.2, isVerified: true),
            LeaderboardEntry(rank: 5, username: "StockWiz", profitLoss: 8420.30, winRate: 65.7, isVerified: false)
        ]
    }
    
    // MARK: - Refresh Methods
    func refreshAllData() async {
        guard let currentUserId = AuthService.shared.currentUser?.id.uuidString else { return }
        
        isLoading = true
        await loadTrades(for: currentUserId)
        await loadLeaderboard()
        await loadPosts()
        isLoading = false
    }
}
