// MARK: - Firestore Service
// File: Shared/Services/FirestoreService.swift

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    private init() {}
    
    deinit {
        removeAllListeners()
    }
    
    // MARK: - Listener Management
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Trades Operations
    
    func addTrade(_ trade: FirebaseTrade) async throws {
        let tradeData = trade.toFirestore()
        try await db.collection("trades").document(trade.id).setData(tradeData)
    }
    
    func updateTrade(_ trade: FirebaseTrade) async throws {
        let tradeData = trade.toFirestore()
        try await db.collection("trades").document(trade.id).updateData(tradeData)
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
                if let error = error {
                    print("Error listening to trades: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let trades = documents.compactMap { document -> FirebaseTrade? in
                    try? FirebaseTrade.fromFirestore(data: document.data(), id: document.documentID)
                }
                
                completion(trades)
            }
        
        listeners.append(listener)
    }
    
    // MARK: - Community Operations
    
    func createCommunity(_ community: Community) async throws {
        let communityData = community.toFirestore()
        try await db.collection("communities").document(community.id).setData(communityData)
    }
    
    func getCommunities() async throws -> [Community] {
        let snapshot = try await db.collection("communities")
            .order(by: "memberCount", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try Community.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func joinCommunity(communityId: String, userId: String) async throws {
        let membershipId = "\(communityId)__\(userId)"
        let membershipData: [String: Any] = [
            "communityId": communityId,
            "userId": userId,
            "role": "member",
            "joinedAt": FieldValue.serverTimestamp(),
            "contributionScore": 0
        ]
        
        try await db.collection("communityMembers").document(membershipId).setData(membershipData)
        
        // Update community member count
        try await db.collection("communities").document(communityId).updateData([
            "memberCount": FieldValue.increment(Int64(1))
        ])
        
        // Add community to user's list
        try await db.collection("users").document(userId).updateData([
            "communityIds": FieldValue.arrayUnion([communityId])
        ])
    }
    
    func leaveCommunity(communityId: String, userId: String) async throws {
        let membershipId = "\(communityId)__\(userId)"
        
        try await db.collection("communityMembers").document(membershipId).delete()
        
        // Update community member count
        try await db.collection("communities").document(communityId).updateData([
            "memberCount": FieldValue.increment(Int64(-1))
        ])
        
        // Remove community from user's list
        try await db.collection("users").document(userId).updateData([
            "communityIds": FieldValue.arrayRemove([communityId])
        ])
    }
    
    // MARK: - Posts Operations
    
    func createPost(_ post: FirebasePost) async throws {
        let postData = post.toFirestore()
        try await db.collection("posts").document(post.id).setData(postData)
    }
    
    func getFeedPosts(communityId: String? = nil) async throws -> [FirebasePost] {
        var query = db.collection("posts").order(by: "createdAt", descending: true)
        
        if let communityId = communityId {
            query = query.whereField("communityId", isEqualTo: communityId)
        }
        
        let snapshot = try await query.limit(to: 50).getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try FirebasePost.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    // MARK: - Leaderboard Operations
    
    func updateLeaderboard(timeframe: String, communityId: String? = nil) async throws {
        let leaderboardId = communityId != nil ? "\(timeframe)_\(communityId!)" : timeframe
        
        // Calculate leaderboard entries
        let entries = try await calculateLeaderboardEntries(timeframe: timeframe, communityId: communityId)
        
        let leaderboardData: [String: Any] = [
            "entries": entries.map { $0.toFirestore() },
            "updatedAt": FieldValue.serverTimestamp(),
            "timeframe": timeframe,
            "communityId": communityId as Any
        ]
        
        try await db.collection("leaderboards").document(leaderboardId).setData(leaderboardData)
    }
    
    private func calculateLeaderboardEntries(timeframe: String, communityId: String?) async throws -> [LeaderboardEntry] {
        // Implementation would calculate user rankings based on trades
        // This is a simplified version
        return []
    }
    
    // MARK: - Following Operations
    
    func followUser(followerId: String, followingId: String) async throws {
        let followingId_doc = "\(followerId)_\(followingId)"
        let followingData: [String: Any] = [
            "followerId": followerId,
            "followingId": followingId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("following").document(followingId_doc).setData(followingData)
        
        // Update counts
        try await db.collection("users").document(followerId).updateData([
            "followingCount": FieldValue.increment(Int64(1))
        ])
        
        try await db.collection("users").document(followingId).updateData([
            "followersCount": FieldValue.increment(Int64(1))
        ])
    }
    
    func unfollowUser(followerId: String, followingId: String) async throws {
        let followingId_doc = "\(followerId)_\(followingId)"
        
        try await db.collection("following").document(followingId_doc).delete()
        
        // Update counts
        try await db.collection("users").document(followerId).updateData([
            "followingCount": FieldValue.increment(Int64(-1))
        ])
        
        try await db.collection("users").document(followingId).updateData([
            "followersCount": FieldValue.increment(Int64(-1))
        ])
    }
}

// MARK: - Firebase Trade Model
// File: Shared/Models/FirebaseTrade.swift

import Foundation
import FirebaseFirestore

struct FirebaseTrade: Identifiable, Codable {
    let id: String
    var userId: String
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
    var sharedCommunityIds: [String]
    
    // Computed properties
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
    
    init(ticker: String, tradeType: TradeType, entryPrice: Double, quantity: Int, userId: String) {
        self.id = UUID().uuidString
        self.userId = userId
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
        self.sharedCommunityIds = []
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "userId": userId,
            "ticker": ticker,
            "tradeType": tradeType.rawValue,
            "entryPrice": entryPrice,
            "exitPrice": exitPrice as Any,
            "quantity": quantity,
            "entryDate": Timestamp(date: entryDate),
            "exitDate": exitDate != nil ? Timestamp(date: exitDate!) : nil as Any,
            "notes": notes as Any,
            "strategy": strategy as Any,
            "isOpen": isOpen,
            "sharedCommunityIds": sharedCommunityIds
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> FirebaseTrade {
        guard let userId = data["userId"] as? String,
              let ticker = data["ticker"] as? String,
              let tradeTypeString = data["tradeType"] as? String,
              let tradeType = TradeType(rawValue: tradeTypeString),
              let entryPrice = data["entryPrice"] as? Double,
              let quantity = data["quantity"] as? Int,
              let entryDateTimestamp = data["entryDate"] as? Timestamp,
              let isOpen = data["isOpen"] as? Bool else {
            throw FirestoreError.invalidData
        }
        
        var trade = FirebaseTrade(ticker: ticker, tradeType: tradeType, entryPrice: entryPrice, quantity: quantity, userId: userId)
        trade.id = id
        trade.exitPrice = data["exitPrice"] as? Double
        trade.notes = data["notes"] as? String
        trade.strategy = data["strategy"] as? String
        trade.isOpen = isOpen
        trade.sharedCommunityIds = data["sharedCommunityIds"] as? [String] ?? []
        trade.entryDate = entryDateTimestamp.dateValue()
        
        if let exitDateTimestamp = data["exitDate"] as? Timestamp {
            trade.exitDate = exitDateTimestamp.dateValue()
        }
        
        return trade
    }
}

// MARK: - Community Model
// File: Shared/Models/Community.swift

import Foundation
import FirebaseFirestore

struct Community: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var type: CommunityType
    var createdBy: String
    var moderatorIds: [String]
    var memberCount: Int
    var rules: String
    var imageURL: String?
    var isPrivate: Bool
    var createdAt: Date
    var tags: [String]
    
    init(name: String, description: String, type: CommunityType, createdBy: String) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.type = type
        self.createdBy = createdBy
        self.moderatorIds = [createdBy]
        self.memberCount = 1
        self.rules = ""
        self.imageURL = nil
        self.isPrivate = false
        self.createdAt = Date()
        self.tags = []
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "name": name,
            "description": description,
            "type": type.rawValue,
            "createdBy": createdBy,
            "moderatorIds": moderatorIds,
            "memberCount": memberCount,
            "rules": rules,
            "imageURL": imageURL as Any,
            "isPrivate": isPrivate,
            "createdAt": Timestamp(date: createdAt),
            "tags": tags
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> Community {
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let typeString = data["type"] as? String,
              let type = CommunityType(rawValue: typeString),
              let createdBy = data["createdBy"] as? String,
              let moderatorIds = data["moderatorIds"] as? [String],
              let memberCount = data["memberCount"] as? Int,
              let rules = data["rules"] as? String,
              let isPrivate = data["isPrivate"] as? Bool,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let tags = data["tags"] as? [String] else {
            throw FirestoreError.invalidData
        }
        
        var community = Community(name: name, description: description, type: type, createdBy: createdBy)
        community.id = id
        community.moderatorIds = moderatorIds
        community.memberCount = memberCount
        community.rules = rules
        community.imageURL = data["imageURL"] as? String
        community.isPrivate = isPrivate
        community.createdAt = createdAtTimestamp.dateValue()
        community.tags = tags
        
        return community
    }
}

enum CommunityType: String, CaseIterable, Codable {
    case general = "general"
    case dayTrading = "day_trading"
    case swingTrading = "swing_trading"
    case options = "options"
    case crypto = "crypto"
    case stocks = "stocks"
    case education = "education"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .dayTrading: return "Day Trading"
        case .swingTrading: return "Swing Trading"
        case .options: return "Options"
        case .crypto: return "Crypto"
        case .stocks: return "Stocks"
        case .education: return "Education"
        }
    }
}

// MARK: - Firebase Post Model
// File: Shared/Models/FirebasePost.swift

import Foundation
import FirebaseFirestore

struct FirebasePost: Identifiable, Codable {
    let id: String
    var userId: String
    var content: String
    var imageURLs: [String]
    var communityId: String?
    var likesCount: Int
    var commentsCount: Int
    var createdAt: Date
    var visibility: PostVisibility
    
    init(userId: String, content: String, communityId: String? = nil) {
        self.id = UUID().uuidString
        self.userId = userId
        self.content = content
        self.imageURLs = []
        self.communityId = communityId
        self.likesCount = 0
        self.commentsCount = 0
        self.createdAt = Date()
        self.visibility = .public
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "userId": userId,
            "content": content,
            "imageURLs": imageURLs,
            "communityId": communityId as Any,
            "likesCount": likesCount,
            "commentsCount": commentsCount,
            "createdAt": Timestamp(date: createdAt),
            "visibility": visibility.rawValue
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> FirebasePost {
        guard let userId = data["userId"] as? String,
              let content = data["content"] as? String,
              let imageURLs = data["imageURLs"] as? [String],
              let likesCount = data["likesCount"] as? Int,
              let commentsCount = data["commentsCount"] as? Int,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let visibilityString = data["visibility"] as? String,
              let visibility = PostVisibility(rawValue: visibilityString) else {
            throw FirestoreError.invalidData
        }
        
        var post = FirebasePost(userId: userId, content: content)
        post.id = id
        post.imageURLs = imageURLs
        post.communityId = data["communityId"] as? String
        post.likesCount = likesCount
        post.commentsCount = commentsCount
        post.createdAt = createdAtTimestamp.dateValue()
        post.visibility = visibility
        
        return post
    }
}

enum PostVisibility: String, CaseIterable, Codable {
    case public = "public"
    case community = "community"
    case followers = "followers"
    case private = "private"
}

// MARK: - Firestore Errors
enum FirestoreError: Error, LocalizedError {
    case invalidData
    case userNotAuthenticated
    case permissionDenied
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .permissionDenied:
            return "Permission denied"
        case .networkError:
            return "Network error"
        }
    }
}