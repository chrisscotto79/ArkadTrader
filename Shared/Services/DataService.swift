// File: Shared/Services/DataService.swift

import Foundation

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    
    @Published var posts: [Post] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var marketNews: [NewsItem] = []
    
    private init() {
        loadMockData()
    }
    
    private func loadMockData() {
        posts = createMockPosts()
        leaderboard = createMockLeaderboard()
        marketNews = createMockNews()
    }
    
    // MARK: - Mock Posts
    
    private func createMockPosts() -> [Post] {
        let mockUserIds = [UUID(), UUID(), UUID(), UUID(), UUID()]
        let mockUsernames = ["ProTrader", "BullRunner", "MarketMaster", "TradingGuru", "StockWiz"]
        
        var posts: [Post] = []
        
        for i in 0..<10 {
            let userId = mockUserIds[i % mockUserIds.count]
            let username = mockUsernames[i % mockUsernames.count]
            
            var post = Post(
                content: getMockPostContent(index: i),
                authorId: userId,
                authorUsername: username
            )
            
            post.likesCount = Int.random(in: 5...50)
            post.commentsCount = Int.random(in: 1...15)
            post.createdAt = Date().addingTimeInterval(-Double(i * 3600)) // Spread over hours
            
            if i % 3 == 0 {
                post.postType = .tradeResult
            }
            
            posts.append(post)
        }
        
        return posts
    }
    
    private func getMockPostContent(index: Int) -> String {
        let contents = [
            "Just closed my AAPL position with a +15% gain! 📈 Market sentiment looking bullish.",
            "Anyone else watching TSLA today? Thinking about entering a position 🤔",
            "Great day in the markets! My portfolio is up 3.2% today 🚀",
            "NVDA earnings coming up next week. What's everyone's thoughts?",
            "Loving this bull run! SPY hitting new highs 📊",
            "Just started my trading journey. Any tips for a beginner?",
            "Bitcoin looking strong today. Crypto winter might be over! ₿",
            "Closed my short position on QQQ. This rally is stronger than expected.",
            "Anyone trading options on AMZN? Volume looks interesting today.",
            "Market volatility is wild today. Perfect for day trading! ⚡"
        ]
        return contents[index % contents.count]
    }
    
    // MARK: - Mock Leaderboard
    
    private func createMockLeaderboard() -> [LeaderboardEntry] {
        return [
            LeaderboardEntry(rank: 1, username: "ProTrader", profitLoss: 15240.50, winRate: 78.5, isVerified: true),
            LeaderboardEntry(rank: 2, username: "BullRunner", profitLoss: 12890.25, winRate: 72.3, isVerified: true),
            LeaderboardEntry(rank: 3, username: "MarketMaster", profitLoss: 11650.00, winRate: 69.8, isVerified: false),
            LeaderboardEntry(rank: 4, username: "TradingGuru", profitLoss: 9875.75, winRate: 68.2, isVerified: true),
            LeaderboardEntry(rank: 5, username: "StockWiz", profitLoss: 8420.30, winRate: 65.7, isVerified: false),
            LeaderboardEntry(rank: 6, username: "CryptoKing", profitLoss: 7850.00, winRate: 64.2, isVerified: false),
            LeaderboardEntry(rank: 7, username: "OptionsPro", profitLoss: 7200.75, winRate: 62.1, isVerified: true),
            LeaderboardEntry(rank: 8, username: "DayTraderX", profitLoss: 6950.25, winRate: 61.8, isVerified: false),
            LeaderboardEntry(rank: 9, username: "SwingMaster", profitLoss: 6400.00, winRate: 59.5, isVerified: false),
            LeaderboardEntry(rank: 10, username: "ValueInvestor", profitLoss: 5880.50, winRate: 58.2, isVerified: true)
        ]
    }
    
    // MARK: - Mock News
    
    private func createMockNews() -> [NewsItem] {
        let currentDate = Date()
        
        return [
            NewsItem(
                id: UUID().uuidString,
                headline: "Tech Stocks Rally as AI Investments Surge",
                summary: "Major technology companies see significant gains following increased AI infrastructure spending announcements",
                source: "Market Update",
                createdAt: currentDate.addingTimeInterval(-1800), // 30 min ago
                url: nil,
                symbols: ["AAPL", "MSFT", "NVDA", "GOOGL"]
            ),
            NewsItem(
                id: UUID().uuidString,
                headline: "Federal Reserve Signals Potential Rate Adjustments",
                summary: "Central bank officials discuss monetary policy outlook in latest economic assessment",
                source: "Economic News",
                createdAt: currentDate.addingTimeInterval(-3600), // 1 hour ago
                url: nil,
                symbols: ["SPY", "TLT", "DXY"]
            ),
            NewsItem(
                id: UUID().uuidString,
                headline: "Energy Sector Sees Mixed Results Amid Oil Price Volatility",
                summary: "Energy companies report varied quarterly results as crude oil prices remain volatile",
                source: "Sector News",
                createdAt: currentDate.addingTimeInterval(-5400), // 1.5 hours ago
                url: nil,
                symbols: ["XOM", "CVX", "USO"]
            ),
            NewsItem(
                id: UUID().uuidString,
                headline: "Banking Sector Update: Regional Banks Show Resilience",
                summary: "Regional banking institutions demonstrate strong fundamentals despite market concerns",
                source: "Financial News",
                createdAt: currentDate.addingTimeInterval(-7200), // 2 hours ago
                url: nil,
                symbols: ["JPM", "BAC", "WFC", "KRE"]
            ),
            NewsItem(
                id: UUID().uuidString,
                headline: "Cryptocurrency Market Experiences Renewed Interest",
                summary: "Digital assets gain momentum as institutional adoption continues to grow",
                source: "Crypto News",
                createdAt: currentDate.addingTimeInterval(-9000), // 2.5 hours ago
                url: nil,
                symbols: ["BTC", "ETH", "COIN"]
            )
        ]
    }
    
    // MARK: - Public Methods
    
    func refreshPosts() {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.posts = self.createMockPosts()
        }
    }
    
    func refreshLeaderboard() {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.leaderboard = self.createMockLeaderboard()
        }
    }
    
    func refreshNews() {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.marketNews = self.createMockNews()
        }
    }
}

// MARK: - Timeframe Enum for Leaderboard

enum LeaderboardTimeFrame: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case allTime = "All Time"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Market Sentiment for Leaderboard

enum LeaderboardMarketSentiment: String, CaseIterable {
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