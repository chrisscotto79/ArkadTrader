// File: Shared/Models/User.swift
// A user's profile. The public part lives at users/{uid}; the owner-only part (email,
// starting balance, onboarding answers, notification preferences) at
// users/{uid}/private/profile. Other people's profiles only ever carry the public part.

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    let id: String
    /// The sign-in email. Only filled in for the signed-in user (read from Firebase Auth).
    var email: String
    var username: String
    var fullName: String
    var bio: String?
    var profileImageUrl: String?
    var followersCount: Int
    var followingCount: Int
    var isVerified: Bool
    var subscriptionTier: SubscriptionTier
    var totalProfitLoss: Double
    var winRate: Double
    /// Owner-only (private doc). 0 for other people's profiles.
    var startingCapital: Double
    var createdAt: Date
    var updatedAt: Date
    var communityIds: [String]

    // Onboarding (see docs/backend-contracts.md, section 7). Owner-only (private doc).
    /// "new", "intermediate" or "experienced"; nil until the user answers
    var experienceLevel: String?
    /// `CommunityType` raw values the user picked during onboarding
    var interests: [String]
    /// False only for accounts that still need onboarding. A missing field reads as true.
    var onboardingCompleted: Bool

    /// Push preferences keyed by `NotificationPreference` raw values. Missing keys mean on.
    /// Owner-only (private doc).
    var notificationPrefs: [String: Bool]

    /// Fields that used to be on the public doc and now live in the private doc
    static let privateFieldNames = ["email", "startingCapital", "experienceLevel", "interests", "notificationPrefs"]

    init(id: String, email: String, username: String, fullName: String) {
        self.id = id
        self.email = email
        self.username = username.lowercased()
        self.fullName = fullName
        self.bio = nil
        self.profileImageUrl = nil
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

    // MARK: - Firestore

    /// The public users/{uid} doc, used when the account is created. Later changes write
    /// only the edited fields (FirebaseServices.updateProfileFields).
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "username": username,
            "fullName": fullName,
            "followersCount": followersCount,
            "followingCount": followingCount,
            "isVerified": isVerified,
            "subscriptionTier": subscriptionTier.rawValue,
            "totalProfitLoss": totalProfitLoss,
            "winRate": winRate,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "communityIds": communityIds,
            "onboardingCompleted": onboardingCompleted
        ]
        if let bio, !bio.isEmpty {
            data["bio"] = bio
        }
        if let profileImageUrl {
            data["profileImageUrl"] = profileImageUrl
        }
        return data
    }

    /// The owner-only users/{uid}/private/profile doc
    func privateFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "email": email,
            "startingCapital": startingCapital,
            "interests": interests,
            "notificationPrefs": notificationPrefs
        ]
        if let experienceLevel {
            data["experienceLevel"] = experienceLevel
        }
        return data
    }

    /// Reads a public users/{uid} doc. Owner-only fields are left empty even if an older doc
    /// still carries them; the signed-in user's come from FirebaseServices.getSignedInProfile.
    static func fromFirestore(data: [String: Any], id: String) throws -> User {
        guard let username = data["username"] as? String,
              let fullName = data["fullName"] as? String else {
            throw FirestoreError.invalidData
        }

        var user = User(id: id, email: "", username: username, fullName: fullName)
        // Keep the stored spelling (older accounts may have capitals)
        user.username = username

        user.bio = data["bio"] as? String
        user.profileImageUrl = data["profileImageUrl"] as? String
        user.followersCount = data["followersCount"] as? Int ?? 0
        user.followingCount = data["followingCount"] as? Int ?? 0
        user.isVerified = data["isVerified"] as? Bool ?? false
        user.totalProfitLoss = data["totalProfitLoss"] as? Double ?? 0.0
        user.winRate = data["winRate"] as? Double ?? 0.0
        user.communityIds = data["communityIds"] as? [String] ?? []
        // Accounts created before onboarding existed have no field and count as completed
        user.onboardingCompleted = data["onboardingCompleted"] as? Bool ?? true

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

    /// Copies the owner-only fields present in `data` (the private doc, or a legacy public doc).
    mutating func applyPrivate(_ data: [String: Any]) {
        if let email = data["email"] as? String, !email.isEmpty {
            self.email = email
        }
        if let capital = data["startingCapital"] as? Double {
            startingCapital = capital
        } else if let capital = data["startingCapital"] as? Int {
            startingCapital = Double(capital)
        }
        if let level = data["experienceLevel"] as? String {
            experienceLevel = level
        }
        if let interests = data["interests"] as? [String] {
            self.interests = interests
        }
        if let prefs = data["notificationPrefs"] as? [String: Bool] {
            notificationPrefs = prefs
        }
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
