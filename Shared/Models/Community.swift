// File: Shared/Models/Community.swift
// Enhanced Community Model with Profile Images, Banners & Activity Tracking

import Foundation
import FirebaseFirestore

// MARK: - Activity Level Enum
enum ActivityLevel: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "Low Activity"
        case .medium: return "Medium Activity"
        case .high: return "High Activity"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "orange"
        case .high: return "green"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "circle.fill"
        case .medium: return "circle.lefthalf.filled"
        case .high: return "circle.circle.fill"
        }
    }
}

// MARK: - Enhanced Community Model
struct Community: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var description: String
    var type: CommunityType
    var createdBy: String  // This is the creatorId
    var creatorId: String { createdBy }  // Computed property for compatibility
    var memberCount: Int
    var isPrivate: Bool
    var createdAt: Date
    
    // Enhanced Properties
    var profileImageUrl: String?
    var bannerImageUrl: String?
    var lastActivityDate: Date?
    var activityLevel: ActivityLevel?
    var tags: [String] // Additional tags beyond just type
    var memberAvatars: [String] // URLs of recent member profile images (max 4)
    
    // MARK: - Initializers
    init(name: String, description: String, type: CommunityType = .general, creatorId: String, memberCount: Int = 1, isPrivate: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.type = type
        self.createdBy = creatorId
        self.memberCount = memberCount
        self.isPrivate = isPrivate
        self.createdAt = Date()
        
        // Initialize new properties
        self.profileImageUrl = nil
        self.bannerImageUrl = nil
        self.lastActivityDate = Date() // Set to creation date initially
        self.activityLevel = .low // Default to low activity
        self.tags = []
        self.memberAvatars = []
    }
    
    // Compatibility initializer for existing code
    init(name: String, description: String, type: CommunityType, createdBy: String) {
        self.init(name: name, description: description, type: type, creatorId: createdBy, memberCount: 1, isPrivate: false)
    }
    
    // MARK: - Computed Properties
    
    /// Get display name for community initials when no profile image
    var initials: String {
        let words = name.components(separatedBy: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    /// Get time since last activity
    var lastActivityText: String {
        guard let lastActivity = lastActivityDate else {
            return "No recent activity"
        }
        
        let now = Date()
        let interval = now.timeIntervalSince(lastActivity)
        
        if interval < 60 {
            return "Active now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Active \(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Active \(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "Active \(days)d ago"
        }
    }
    
    /// Check if community was recently active (within last 24 hours)
    var isRecentlyActive: Bool {
        guard let lastActivity = lastActivityDate else { return false }
        return Date().timeIntervalSince(lastActivity) < 86400 // 24 hours
    }
    
    /// Get banner color based on community type when no banner image
    var typeColor: String {
        switch type {
        case .dayTrading: return "red"
        case .swingTrading: return "orange"
        case .options: return "purple"
        case .crypto: return "yellow"
        case .stocks: return "green"
        case .general: return "blue"
        }
    }
    
    /// Get icon for community type
    var typeIcon: String {
        switch type {
        case .general: return "person.3"
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "chart.bar"
        case .options: return "option"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        }
    }
    
    /// Get activity level with automatic calculation if not set
    var calculatedActivityLevel: ActivityLevel {
        if let level = activityLevel {
            return level
        }
        
        // Auto-calculate based on member count and recent activity
        let memberScore = min(memberCount / 10, 5) // Max 5 points for members
        let activityScore = isRecentlyActive ? 3 : 0 // 3 points for recent activity
        let totalScore = memberScore + activityScore
        
        switch totalScore {
        case 0...2: return .low
        case 3...5: return .medium
        default: return .high
        }
    }
    
    // MARK: - Firebase Conversion
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "description": description,
            "type": type.rawValue,
            "createdBy": createdBy,
            "memberCount": memberCount,
            "isPrivate": isPrivate,
            "createdAt": Timestamp(date: createdAt),
            "tags": tags,
            "memberAvatars": memberAvatars
        ]
        
        // Add optional fields only if they exist
        if let profileImageUrl = profileImageUrl {
            data["profileImageUrl"] = profileImageUrl
        }
        
        if let bannerImageUrl = bannerImageUrl {
            data["bannerImageUrl"] = bannerImageUrl
        }
        
        if let lastActivityDate = lastActivityDate {
            data["lastActivityDate"] = Timestamp(date: lastActivityDate)
        }
        
        if let activityLevel = activityLevel {
            data["activityLevel"] = activityLevel.rawValue
        }
        
        return data
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> Community {
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let typeString = data["type"] as? String,
              let type = CommunityType(rawValue: typeString),
              let createdBy = data["createdBy"] as? String,
              let memberCount = data["memberCount"] as? Int,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        let isPrivate = data["isPrivate"] as? Bool ?? false
        
        var community = Community(
            name: name,
            description: description,
            type: type,
            creatorId: createdBy,
            memberCount: memberCount,
            isPrivate: isPrivate
        )
        
        community.id = id
        community.createdAt = createdAtTimestamp.dateValue()
        
        // Handle optional new fields
        community.profileImageUrl = data["profileImageUrl"] as? String
        community.bannerImageUrl = data["bannerImageUrl"] as? String
        
        if let lastActivityTimestamp = data["lastActivityDate"] as? Timestamp {
            community.lastActivityDate = lastActivityTimestamp.dateValue()
        }
        
        if let activityLevelString = data["activityLevel"] as? String {
            community.activityLevel = ActivityLevel(rawValue: activityLevelString)
        }
        
        community.tags = data["tags"] as? [String] ?? []
        community.memberAvatars = data["memberAvatars"] as? [String] ?? []
        
        return community
    }
}

// MARK: - CommunityType Extension (keeping existing)
enum CommunityType: String, CaseIterable, Codable {
    case general = "general"
    case dayTrading = "day_trading"
    case swingTrading = "swing_trading"
    case options = "options"
    case crypto = "crypto"
    case stocks = "stocks"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .dayTrading: return "Day Trading"
        case .swingTrading: return "Swing Trading"
        case .options: return "Options"
        case .crypto: return "Cryptocurrency"
        case .stocks: return "Stocks"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .general: return "General"
        case .dayTrading: return "Day Trading"
        case .swingTrading: return "Swing"
        case .options: return "Options"
        case .crypto: return "Crypto"
        case .stocks: return "Stocks"
        }
    }
}

// MARK: - Firestore Error

