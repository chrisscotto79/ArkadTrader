// File: Core/Home/ViewModels/HomeViewModel.swift
// Updated HomeViewModel for Firebase

import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class HomeViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = FirebaseAuthService.shared
    private let firestoreService = FirestoreService.shared
    
    init() {
        loadPosts()
    }
    
    func loadPosts() {
        isLoading = true
        
        Task {
            do {
                let posts = try await firestoreService.getFeedPosts()
                await MainActor.run {
                    self.posts = posts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.posts = createMockPosts() // Fallback to mock data
                    self.isLoading = false
                }
            }
        }
    }
    
    func refreshPosts() {
        loadPosts()
    }
    
    func likePost(_ post: Post) {
        // TODO: Implement like functionality with Firestore
        print("Liked post: \(post.id)")
    }
    
    func addComment(to post: Post, comment: String) {
        // TODO: Implement comment functionality with Firestore
        print("Added comment to post: \(post.id)")
    }
    
    func createPost(content: String, type: PostType = .text) {
        guard let userId = authService.currentUser?.id,
              let username = authService.currentUser?.username else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }
        
        let newPost = Post(content: content, authorId: userId, authorUsername: username)
        
        Task {
            do {
                try await firestoreService.createPost(newPost)
                await MainActor.run {
                    self.posts.insert(newPost, at: 0)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to create post: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    private func createMockPosts() -> [Post] {
        guard let userId = authService.currentUser?.id else { return [] }
        
        return [
            Post(content: "Market looking bullish today! 📈 SPY hitting new highs", authorId: UUID().uuidString, authorUsername: "trader123"),
            Post(content: "Just closed my AAPL position with a +15% gain! 🚀", authorId: userId, authorUsername: authService.currentUser?.username ?? "user"),
            Post(content: "Anyone else watching TSLA today? Thinking about entering a position 🤔", authorId: UUID().uuidString, authorUsername: "marketwatcher"),
            Post(content: "NVDA earnings coming up next week. What's everyone's thoughts?", authorId: UUID().uuidString, authorUsername: "techanalyst")
        ]
    }
}

// File: Core/Leaderboard/ViewModels/LeaderboardViewModel.swift
// Updated LeaderboardViewModel for Firebase

import Foundation
import SwiftUI
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
    
    private let firestoreService = FirestoreService.shared
    
    init() {
        loadLeaderboard()
    }
    
    func loadLeaderboard() {
        isLoading = true
        
        // For now, use mock data until Cloud Functions are implemented
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.leaderboard = self.createMockLeaderboard()
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
        guard let currentUserId = FirebaseAuthService.shared.currentUser?.id,
              let traderId = entry.userId else {
            errorMessage = "Unable to follow trader"
            showError = true
            return
        }
        
        Task {
            do {
                try await firestoreService.followUser(followerId: currentUserId, followingId: traderId)
                print("Following trader: \(entry.username)")
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to follow trader: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    private func createMockLeaderboard() -> [LeaderboardEntry] {
        return [
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
}

enum MarketSentiment: String, CaseIterable {
    case bullish = "bullish"
    case bearish = "bearish"
    case neutral = "neutral"
    
    var displayName: String {
        switch self {
        case .bullish: return "Bullish"
        case .bearish: return "Bearish"
        case .neutral: return "Neutral"
        }
    }
    
    var emoji: String {
        switch self {
        case .bullish: return "🐂"
        case .bearish: return "🐻"
        case .neutral: return "⚖️"
        }
    }
    
    var color: String {
        switch self {
        case .bullish: return "green"
        case .bearish: return "red"
        case .neutral: return "gray"
        }
    }
}

enum TimeFrame: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case allTime = "All Time"
}
