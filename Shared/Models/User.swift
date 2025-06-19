//
//  User.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Shared/Models/User.swift

import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var email: String
    var username: String
    var fullName: String
    var bio: String?
    var profileImageURL: String?
    var followersCount: Int
    var followingCount: Int
    var isVerified: Bool
    var subscriptionTier: SubscriptionTier
    var totalProfitLoss: Double
    var winRate: Double
    var createdAt: Date
    
    init(email: String, username: String, fullName: String) {
        self.id = UUID()
        self.email = email
        self.username = username
        self.fullName = fullName
        self.bio = nil
        self.profileImageURL = nil
        self.followersCount = 0
        self.followingCount = 0
        self.isVerified = false
        self.subscriptionTier = .basic
        self.totalProfitLoss = 0.0
        self.winRate = 0.0
        self.createdAt = Date()
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
