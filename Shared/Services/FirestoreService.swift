// File: Shared/Services/FirestoreService.swift

import Foundation
import Firebase
import FirebaseFirestore

@MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    private init() {}
    
    deinit {
        removeAllListeners()
    }
    
    // MARK: - Trades
    
    func addTrade(_ trade: FirebaseTrade) async throws {
        try await db.collection("trades").document(trade.id).setData(trade.toFirestore())
    }
    
    func updateTrade(_ trade: FirebaseTrade) async throws {
        try await db.collection("trades").document(trade.id).updateData(trade.toFirestore())
    }
    
    func deleteTrade(tradeId: String) async throws {
        try await db.collection("trades").document(tradeId).delete()
    }
    
    func getUserTrades(userId: String) async throws -> [FirebaseTrade] {
        let snapshot = try await db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .order(by: "entryDate", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try FirebaseTrade.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func listenToUserTrades(userId: String, completion: @escaping ([FirebaseTrade]) -> Void) {
        let listener = db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .order(by: "entryDate", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching trades: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let trades = documents.compactMap { document -> FirebaseTrade? in
                    try? FirebaseTrade.fromFirestore(data: document.data(), id: document.documentID)
                }
                
                completion(trades)
            }
        
        listeners.append(listener)
    }
    
    // MARK: - Posts
    
    func addPost(_ post: FirebasePost) async throws {
        try await db.collection("posts").document(post.id).setData(post.toFirestore())
    }
    
    func updatePost(_ post: FirebasePost) async throws {
        try await db.collection("posts").document(post.id).updateData(post.toFirestore())
    }
    
    func deletePost(postId: String) async throws {
        try await db.collection("posts").document(postId).delete()
    }
    
    func getPosts(limit: Int = 20, lastDocument: DocumentSnapshot? = nil) async throws -> (posts: [FirebasePost], lastDoc: DocumentSnapshot?) {
        var query = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        let snapshot = try await query.getDocuments()
        
        let posts = try snapshot.documents.compactMap { document in
            try FirebasePost.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        return (posts: posts, lastDoc: snapshot.documents.last)
    }
    
    func getUserPosts(userId: String) async throws -> [FirebasePost] {
        let snapshot = try await db.collection("posts")
            .whereField("authorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try FirebasePost.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    // MARK: - Leaderboard
    
    func getLeaderboard(timeframe: String = "weekly", limit: Int = 50) async throws -> [LeaderboardEntry] {
        // For now, return mock data since we need to implement proper leaderboard logic
        return createMockLeaderboard()
    }
    
    private func createMockLeaderboard() -> [LeaderboardEntry] {
        return [
            LeaderboardEntry(rank: 1, username: "ProTrader", profitLoss: 15240.50, winRate: 78.5, isVerified: true),
            LeaderboardEntry(rank: 2, username: "BullRunner", profitLoss: 12890.25, winRate: 72.3, isVerified: true),
            LeaderboardEntry(rank: 3, username: "MarketMaster", profitLoss: 11650.00, winRate: 69.8, isVerified: false),
            LeaderboardEntry(rank: 4, username: "TradingGuru", profitLoss: 9875.75, winRate: 68.2, isVerified: true),
            LeaderboardEntry(rank: 5, username: "StockWiz", profitLoss: 8420.30, winRate: 65.7, isVerified: false)
        ]
    }
    
    // MARK: - Search
    
    func searchUsers(query: String, limit: Int = 20) async throws -> [AppUser] {
        // Firebase doesn't support full-text search well, so this is a simple implementation
        let snapshot = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query.lowercased())
            .whereField("username", isLessThan: query.lowercased() + "\u{f8ff}")
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try AppUser.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    // MARK: - Listener Management
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}

// MARK: - Firebase Trade Model

struct FirebaseTrade: Identifiable, Codable {
    let id: String
    var ticker: String
    var tradeType: TradeType
    var entryPrice: Double
    var exitPrice: Double?
    var quantity: Int
    var entryDate: Date
    var exitDate: Date?
    var notes: String?
    var strategy: String?
    var isOpen: Bool
    var userId: String
    
    init(ticker: String, tradeType: TradeType, entryPrice: Double, quantity: Int, userId: String) {
        self.id = UUID().uuidString
        self.ticker = ticker.uppercased()
        self.tradeType = tradeType
        self.entryPrice = entryPrice
        self.exitPrice = nil
        self.quantity = quantity
        self.entryDate = Date()
        self.exitDate = nil
        self.notes = nil
        self.strategy = nil
        self.isOpen = true
        self.userId = userId
    }
    
    // MARK: - Computed Properties
    
    var profitLoss: Double {
        guard let exitPrice = exitPrice else { return 0 }
        return (exitPrice - entryPrice) * Double(quantity)
    }
    
    var profitLossPercentage: Double {
        guard let exitPrice = exitPrice else { return 0 }
        return ((exitPrice - entryPrice) / entryPrice) * 100
    }
    
    var currentValue: Double {
        if let exitPrice = exitPrice {
            return exitPrice * Double(quantity)
        }
        return entryPrice * Double(quantity)
    }
    
    var daysHeld: Int {
        let endDate = exitDate ?? Date()
        return Calendar.current.dateComponents([.day], from: entryDate, to: endDate).day ?? 0
    }
    
    var formattedEntryDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: entryDate)
    }
    
    var statusText: String {
        if isOpen {
            return "OPEN"
        } else {
            return profitLoss >= 0 ? "PROFIT" : "LOSS"
        }
    }
    
    // MARK: - Firebase Methods
    
    func toFirestore() -> [String: Any] {
        return [
            "ticker": ticker,
            "tradeType": tradeType.rawValue,
            "entryPrice": entryPrice,
            "exitPrice": exitPrice as Any,
            "quantity": quantity,
            "entryDate": Timestamp(date: entryDate),
            "exitDate": exitDate.map { Timestamp(date: $0) } as Any,
            "notes": notes as Any,
            "strategy": strategy as Any,
            "isOpen": isOpen,
            "userId": userId
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> FirebaseTrade {
        guard let ticker = data["ticker"] as? String,
              let tradeTypeString = data["tradeType"] as? String,
              let tradeType = TradeType(rawValue: tradeTypeString),
              let entryPrice = data["entryPrice"] as? Double,
              let quantity = data["quantity"] as? Int,
              let entryDateTimestamp = data["entryDate"] as? Timestamp,
              let isOpen = data["isOpen"] as? Bool,
              let userId = data["userId"] as? String else {
            throw FirestoreError.invalidData
        }
        
        var trade = FirebaseTrade(ticker: ticker, tradeType: tradeType, entryPrice: entryPrice, quantity: quantity, userId: userId)
        trade.id = id
        trade.exitPrice = data["exitPrice"] as? Double
        trade.entryDate = entryDateTimestamp.dateValue()
        trade.exitDate = (data["exitDate"] as? Timestamp)?.dateValue()
        trade.notes = data["notes"] as? String
        trade.strategy = data["strategy"] as? String
        trade.isOpen = isOpen
        
        return trade
    }
}

// MARK: - Firebase Post Model

struct FirebasePost: Identifiable, Codable {
    let id: String
    var content: String
    var imageURL: String?
    var authorId: String
    var authorUsername: String
    var authorProfileImageURL: String?
    var likesCount: Int
    var commentsCount: Int
    var createdAt: Date
    var updatedAt: Date
    var isPremiumContent: Bool
    var postType: PostType
    var tradeId: String? // Link to associated trade if it's a trade post
    
    init(content: String, authorId: String, authorUsername: String) {
        self.id = UUID().uuidString
        self.content = content
        self.imageURL = nil
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.authorProfileImageURL = nil
        self.likesCount = 0
        self.commentsCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPremiumContent = false
        self.postType = .text
        self.tradeId = nil
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "content": content,
            "imageURL": imageURL as Any,
            "authorId": authorId,
            "authorUsername": authorUsername,
            "authorProfileImageURL": authorProfileImageURL as Any,
            "likesCount": likesCount,
            "commentsCount": commentsCount,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "isPremiumContent": isPremiumContent,
            "postType": postType.rawValue,
            "tradeId": tradeId as Any
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> FirebasePost {
        guard let content = data["content"] as? String,
              let authorId = data["authorId"] as? String,
              let authorUsername = data["authorUsername"] as? String,
              let likesCount = data["likesCount"] as? Int,
              let commentsCount = data["commentsCount"] as? Int,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp,
              let isPremiumContent = data["isPremiumContent"] as? Bool,
              let postTypeString = data["postType"] as? String,
              let postType = PostType(rawValue: postTypeString) else {
            throw FirestoreError.invalidData
        }
        
        var post = FirebasePost(content: content, authorId: authorId, authorUsername: authorUsername)
        post.id = id
        post.imageURL = data["imageURL"] as? String
        post.authorProfileImageURL = data["authorProfileImageURL"] as? String
        post.likesCount = likesCount
        post.commentsCount = commentsCount
        post.createdAt = createdAtTimestamp.dateValue()
        post.updatedAt = updatedAtTimestamp.dateValue()
        post.isPremiumContent = isPremiumContent
        post.postType = postType
        post.tradeId = data["tradeId"] as? String
        
        return post
    }
}