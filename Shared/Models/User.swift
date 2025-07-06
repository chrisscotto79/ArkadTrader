// File: Shared/Models/User.swift
// Simplified User Model

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    let id: String
    var email: String
    var username: String
    var fullName: String
    var bio: String?
    var followersCount: Int
    var followingCount: Int
    var isVerified: Bool
    var subscriptionTier: SubscriptionTier
    var totalProfitLoss: Double
    var winRate: Double
    var createdAt: Date
    var updatedAt: Date
    var communityIds: [String]
    
    // Simplified init
    init(id: String, email: String, username: String, fullName: String) {
        self.id = id
        self.email = email
        self.username = username.lowercased()
        self.fullName = fullName
        self.bio = nil
        self.followersCount = 0
        self.followingCount = 0
        self.isVerified = false
        self.subscriptionTier = .basic
        self.totalProfitLoss = 0.0
        self.winRate = 0.0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.communityIds = []
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "email": email,
            "username": username,
            "fullName": fullName,
            "bio": bio as Any,
            "followersCount": followersCount,
            "followingCount": followingCount,
            "isVerified": isVerified,
            "subscriptionTier": subscriptionTier.rawValue,
            "totalProfitLoss": totalProfitLoss,
            "winRate": winRate,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "communityIds": communityIds
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> User {
        guard let email = data["email"] as? String,
              let username = data["username"] as? String,
              let fullName = data["fullName"] as? String else {
            throw FirestoreError.invalidData
        }
        
        var user = User(id: id, email: email, username: username, fullName: fullName)
        
        user.bio = data["bio"] as? String
        user.followersCount = data["followersCount"] as? Int ?? 0
        user.followingCount = data["followingCount"] as? Int ?? 0
        user.isVerified = data["isVerified"] as? Bool ?? false
        user.totalProfitLoss = data["totalProfitLoss"] as? Double ?? 0.0
        user.winRate = data["winRate"] as? Double ?? 0.0
        user.communityIds = data["communityIds"] as? [String] ?? []
        
        if let tierString = data["subscriptionTier"] as? String {
            user.subscriptionTier = SubscriptionTier(rawValue: tierString) ?? .basic
        }
        
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            user.createdAt = createdAtTimestamp.dateValue()
        }
        
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            user.updatedAt = updatedAtTimestamp.dateValue()
        }
        
        return user
    }
}

enum SubscriptionTier: String, CaseIterable, Codable {
    case basic = "basic"
    case pro = "pro"
    case elite = "elite"
    
    var displayName: String {
        switch self {
        case .basic: return "Basic"
        case .pro: return "Pro"
        case .elite: return "Elite"
        }
    }
}
