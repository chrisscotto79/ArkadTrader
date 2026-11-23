// File: Shared/Models/User.swift
// The signed-in user's profile, stored at users/{uid}.

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    let id: String
    var email: String
    var username: String
    var fullName: String
    var bio: String?
    var profileImageUrl: String?  // NEW: Profile image URL field
    var followersCount: Int
    var followingCount: Int
    var isVerified: Bool
    var subscriptionTier: SubscriptionTier
    var totalProfitLoss: Double
    var winRate: Double
    var startingCapital: Double
    var createdAt: Date
    var updatedAt: Date
    var communityIds: [String]

    // Onboarding (see docs/backend-contracts.md, section 7)
    /// "new", "intermediate" or "experienced"; nil until the user answers
    var experienceLevel: String?
    /// `CommunityType` raw values the user picked during onboarding
    var interests: [String]
    /// False only for accounts that still need onboarding. A missing field reads as true.
    var onboardingCompleted: Bool

    /// Push preferences keyed by `NotificationPreference` raw values. Missing keys mean on.
    /// Written separately (FirebaseServices.setNotificationPreference), never by `toFirestore()`.
    var notificationPrefs: [String: Bool]
    
    // Simplified init
    init(id: String, email: String, username: String, fullName: String) {
        self.id = id
        self.email = email
        self.username = username.lowercased()
        self.fullName = fullName
        self.bio = nil
        self.profileImageUrl = nil  // NEW: Default to nil
        self.followersCount = 0
        self.followingCount = 0
        self.isVerified = false
        self.subscriptionTier = .basic
        self.totalProfitLoss = 0.0
        self.winRate = 0.0
        self.startingCapital = 0.0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.communityIds = []
        self.experienceLevel = nil
        self.interests = []
        self.onboardingCompleted = true
        self.notificationPrefs = [:]
    }

    /// True while the user still needs to go through onboarding
    var needsOnboarding: Bool { !onboardingCompleted }

    /// Whether a push preference is on. Every preference defaults to on.
    func isNotificationEnabled(_ key: String) -> Bool {
        notificationPrefs[key] ?? true
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "email": email,
            "username": username,
            "fullName": fullName,
            "bio": bio as Any,
            "profileImageUrl": profileImageUrl as Any,  // NEW: Include in Firestore
            "followersCount": followersCount,
            "followingCount": followingCount,
            "isVerified": isVerified,
            "subscriptionTier": subscriptionTier.rawValue,
            "totalProfitLoss": totalProfitLoss,
            "winRate": winRate,
            "startingCapital": startingCapital,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "communityIds": communityIds,
            "onboardingCompleted": onboardingCompleted
        ]
        if let experienceLevel {
            data["experienceLevel"] = experienceLevel
        }
        if !interests.isEmpty {
            data["interests"] = interests
        }
        return data
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> User {
        guard let email = data["email"] as? String,
              let username = data["username"] as? String,
              let fullName = data["fullName"] as? String else {
            throw FirestoreError.invalidData
        }
        
        var user = User(id: id, email: email, username: username, fullName: fullName)
        
        user.bio = data["bio"] as? String
        user.profileImageUrl = data["profileImageUrl"] as? String  // NEW: Load from Firestore
        user.followersCount = data["followersCount"] as? Int ?? 0
        user.followingCount = data["followingCount"] as? Int ?? 0
        user.isVerified = data["isVerified"] as? Bool ?? false
        user.totalProfitLoss = data["totalProfitLoss"] as? Double ?? 0.0
        user.winRate = data["winRate"] as? Double ?? 0.0
        user.startingCapital = data["startingCapital"] as? Double ?? 0.0
        user.communityIds = data["communityIds"] as? [String] ?? []
        user.experienceLevel = data["experienceLevel"] as? String
        user.interests = data["interests"] as? [String] ?? []
        // Accounts created before onboarding existed have no field and count as completed
        user.onboardingCompleted = data["onboardingCompleted"] as? Bool ?? true
        user.notificationPrefs = data["notificationPrefs"] as? [String: Bool] ?? [:]
        
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
