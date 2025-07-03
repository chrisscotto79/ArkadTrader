// File: Shared/Models/Community.swift
// Community model for Firebase integration

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
    var activeMembers: Int
    var rules: String
    var imageURL: String?
    var bannerURL: String?
    var isPrivate: Bool
    var requiresApproval: Bool
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var settings: CommunitySettings
    var statistics: CommunityStatistics
    var socialLinks: [SocialLink]
    
    init(name: String, description: String, type: CommunityType, createdBy: String) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.type = type
        self.createdBy = createdBy
        self.moderatorIds = [createdBy]
        self.memberCount = 1
        self.activeMembers = 1
        self.rules = ""
        self.imageURL = nil
        self.bannerURL = nil
        self.isPrivate = false
        self.requiresApproval = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = []
        self.settings = CommunitySettings()
        self.statistics = CommunityStatistics()
        self.socialLinks = []
    }
    
    // MARK: - Computed Properties
    
    var isNew: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return createdAt > thirtyDaysAgo
    }
    
    var isActive: Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return updatedAt > sevenDaysAgo
    }
    
    var activityLevel: ActivityLevel {
        let ratio = Double(activeMembers) / Double(max(memberCount, 1))
        switch ratio {
        case 0.7...:
            return .high
        case 0.3..<0.7:
            return .medium
        default:
            return .low
        }
    }
    
    var displayMemberCount: String {
        if memberCount >= 1000 {
            let thousands = Double(memberCount) / 1000.0
            return String(format: "%.1fK", thousands)
        } else {
            return "\(memberCount)"
        }
    }
    
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }
    
    var canUserJoin: Bool {
        return !isPrivate || !requiresApproval
    }
    
    // MARK: - Firebase Integration
    
    func toFirestore() -> [String: Any] {
        return [
            "name": name,
            "description": description,
            "type": type.rawValue,
            "createdBy": createdBy,
            "moderatorIds": moderatorIds,
            "memberCount": memberCount,
            "activeMembers": activeMembers,
            "rules": rules,
            "imageURL": imageURL as Any,
            "bannerURL": bannerURL as Any,
            "isPrivate": isPrivate,
            "requiresApproval": requiresApproval,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "tags": tags,
            "settings": settings.toFirestore(),
            "statistics": statistics.toFirestore(),
            "socialLinks": socialLinks.map { $0.toFirestore() }
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
              let requiresApproval = data["requiresApproval"] as? Bool,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp,
              let tags = data["tags"] as? [String] else {
            throw FirestoreError.invalidData
        }
        
        var community = Community(name: name, description: description, type: type, createdBy: createdBy)
        community.id = id
        community.moderatorIds = moderatorIds
        community.memberCount = memberCount
        community.activeMembers = data["activeMembers"] as? Int ?? memberCount
        community.rules = rules
        community.imageURL = data["imageURL"] as? String
        community.bannerURL = data["bannerURL"] as? String
        community.isPrivate = isPrivate
        community.requiresApproval = requiresApproval
        community.createdAt = createdAtTimestamp.dateValue()
        community.updatedAt = updatedAtTimestamp.dateValue()
        community.tags = tags
        
        if let settingsData = data["settings"] as? [String: Any] {
            community.settings = CommunitySettings.fromFirestore(settingsData)
        }
        
        if let statisticsData = data["statistics"] as? [String: Any] {
            community.statistics = CommunityStatistics.fromFirestore(statisticsData)
        }
        
        if let socialLinksData = data["socialLinks"] as? [[String: Any]] {
            community.socialLinks = socialLinksData.compactMap { SocialLink.fromFirestore($0) }
        }
        
        return community
    }
    
    // MARK: - Helper Methods
    
    func isModerator(_ userId: String) -> Bool {
        return moderatorIds.contains(userId)
    }
    
    func isCreator(_ userId: String) -> Bool {
        return createdBy == userId
    }
    
    mutating func addModerator(_ userId: String) {
        if !moderatorIds.contains(userId) {
            moderatorIds.append(userId)
            updatedAt = Date()
        }
    }
    
    mutating func removeModerator(_ userId: String) {
        moderatorIds.removeAll { $0 == userId }
        updatedAt = Date()
    }
    
    mutating func updateMemberCount(_ newCount: Int) {
        memberCount = newCount
        updatedAt = Date()
    }
    
    mutating func incrementMemberCount() {
        memberCount += 1
        updatedAt = Date()
    }
    
    mutating func decrementMemberCount() {
        memberCount = max(0, memberCount - 1)
        updatedAt = Date()
    }
}

// MARK: - Community Type Enum

enum CommunityType: String, CaseIterable, Codable {
    case general = "general"
    case dayTrading = "day_trading"
    case swingTrading = "swing_trading"
    case longTerm = "long_term"
    case options = "options"
    case crypto = "crypto"
    case stocks = "stocks"
    case forex = "forex"
    case education = "education"
    case news = "news"
    case analysis = "analysis"
    case beginners = "beginners"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .dayTrading: return "Day Trading"
        case .swingTrading: return "Swing Trading"
        case .longTerm: return "Long Term Investing"
        case .options: return "Options Trading"
        case .crypto: return "Cryptocurrency"
        case .stocks: return "Stock Trading"
        case .forex: return "Forex Trading"
        case .education: return "Education"
        case .news: return "Market News"
        case .analysis: return "Technical Analysis"
        case .beginners: return "Beginners"
        case .advanced: return "Advanced Trading"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "person.3"
        case .dayTrading: return "chart.line.uptrend.xyaxis"
        case .swingTrading: return "chart.bar"
        case .longTerm: return "calendar"
        case .options: return "chart.pie"
        case .crypto: return "bitcoinsign.circle"
        case .stocks: return "building.columns"
        case .forex: return "dollarsign.circle"
        case .education: return "graduationcap"
        case .news: return "newspaper"
        case .analysis: return "chart.bar.doc.horizontal"
        case .beginners: return "hand.raised"
        case .advanced: return "trophy"
        }
    }
    
    var color: String {
        switch self {
        case .general: return "blue"
        case .dayTrading: return "green"
        case .swingTrading: return "orange"
        case .longTerm: return "purple"
        case .options: return "red"
        case .crypto: return "yellow"
        case .stocks: return "blue"
        case .forex: return "teal"
        case .education: return "indigo"
        case .news: return "red"
        case .analysis: return "orange"
        case .beginners: return "green"
        case .advanced: return "purple"
        }
    }
    
    var description: String {
        switch self {
        case .general: return "General trading discussions and community chat"
        case .dayTrading: return "Fast-paced intraday trading strategies and tips"
        case .swingTrading: return "Medium-term position trading over days to weeks"
        case .longTerm: return "Long-term investment strategies and wealth building"
        case .options: return "Options trading strategies, Greeks, and analysis"
        case .crypto: return "Cryptocurrency trading and blockchain discussions"
        case .stocks: return "Stock market analysis and equity trading"
        case .forex: return "Foreign exchange trading and currency analysis"
        case .education: return "Learning resources and educational content"
        case .news: return "Market news, earnings, and economic updates"
        case .analysis: return "Technical and fundamental analysis discussions"
        case .beginners: return "New trader support and basic education"
        case .advanced: return "Advanced strategies for experienced traders"
        }
    }
}

// MARK: - Community Settings

struct CommunitySettings: Codable {
    var allowPosts: Bool
    var allowPolls: Bool
    var allowTradeSharing: Bool
    var allowImages: Bool
    var allowLinks: Bool
    var requireApproval: Bool
    var allowGuestViewing: Bool
    var enableChatRoom: Bool
    var allowDirectMessages: Bool
    var moderationLevel: ModerationLevel
    var autoModeration: Bool
    var welcomeMessage: String?
    
    init() {
        self.allowPosts = true
        self.allowPolls = true
        self.allowTradeSharing = true
        self.allowImages = true
        self.allowLinks = true
        self.requireApproval = false
        self.allowGuestViewing = true
        self.enableChatRoom = false
        self.allowDirectMessages = true
        self.moderationLevel = .medium
        self.autoModeration = true
        self.welcomeMessage = nil
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "allowPosts": allowPosts,
            "allowPolls": allowPolls,
            "allowTradeSharing": allowTradeSharing,
            "allowImages": allowImages,
            "allowLinks": allowLinks,
            "requireApproval": requireApproval,
            "allowGuestViewing": allowGuestViewing,
            "enableChatRoom": enableChatRoom,
            "allowDirectMessages": allowDirectMessages,
            "moderationLevel": moderationLevel.rawValue,
            "autoModeration": autoModeration,
            "welcomeMessage": welcomeMessage as Any
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> CommunitySettings {
        var settings = CommunitySettings()
        settings.allowPosts = data["allowPosts"] as? Bool ?? true
        settings.allowPolls = data["allowPolls"] as? Bool ?? true
        settings.allowTradeSharing = data["allowTradeSharing"] as? Bool ?? true
        settings.allowImages = data["allowImages"] as? Bool ?? true
        settings.allowLinks = data["allowLinks"] as? Bool ?? true
        settings.requireApproval = data["requireApproval"] as? Bool ?? false
        settings.allowGuestViewing = data["allowGuestViewing"] as? Bool ?? true
        settings.enableChatRoom = data["enableChatRoom"] as? Bool ?? false
        settings.allowDirectMessages = data["allowDirectMessages"] as? Bool ?? true
        settings.autoModeration = data["autoModeration"] as? Bool ?? true
        settings.welcomeMessage = data["welcomeMessage"] as? String
        
        if let moderationString = data["moderationLevel"] as? String {
            settings.moderationLevel = ModerationLevel(rawValue: moderationString) ?? .medium
        }
        
        return settings
    }
}

enum ModerationLevel: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case strict = "strict"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .strict: return "Strict"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Minimal moderation, community self-regulates"
        case .medium: return "Balanced moderation with basic rules enforcement"
        case .high: return "Active moderation with strict rule enforcement"
        case .strict: return "Maximum moderation, all content pre-approved"
        }
    }
}

// MARK: - Community Statistics

struct CommunityStatistics: Codable {
    var totalPosts: Int
    var totalComments: Int
    var dailyActiveUsers: Int
    var weeklyActiveUsers: Int
    var monthlyActiveUsers: Int
    var averageEngagement: Double
    var topContributors: [String]
    var growthRate: Double
    var retentionRate: Double
    
    init() {
        self.totalPosts = 0
        self.totalComments = 0
        self.dailyActiveUsers = 0
        self.weeklyActiveUsers = 0
        self.monthlyActiveUsers = 0
        self.averageEngagement = 0.0
        self.topContributors = []
        self.growthRate = 0.0
        self.retentionRate = 0.0
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "totalPosts": totalPosts,
            "totalComments": totalComments,
            "dailyActiveUsers": dailyActiveUsers,
            "weeklyActiveUsers": weeklyActiveUsers,
            "monthlyActiveUsers": monthlyActiveUsers,
            "averageEngagement": averageEngagement,
            "topContributors": topContributors,
            "growthRate": growthRate,
            "retentionRate": retentionRate
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> CommunityStatistics {
        var stats = CommunityStatistics()
        stats.totalPosts = data["totalPosts"] as? Int ?? 0
        stats.totalComments = data["totalComments"] as? Int ?? 0
        stats.dailyActiveUsers = data["dailyActiveUsers"] as? Int ?? 0
        stats.weeklyActiveUsers = data["weeklyActiveUsers"] as? Int ?? 0
        stats.monthlyActiveUsers = data["monthlyActiveUsers"] as? Int ?? 0
        stats.averageEngagement = data["averageEngagement"] as? Double ?? 0.0
        stats.topContributors = data["topContributors"] as? [String] ?? []
        stats.growthRate = data["growthRate"] as? Double ?? 0.0
        stats.retentionRate = data["retentionRate"] as? Double ?? 0.0
        return stats
    }
}

// MARK: - Activity Level

enum ActivityLevel: String, CaseIterable {
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
        case .low: return "red"
        case .medium: return "orange"
        case .high: return "green"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "circle.fill"
        case .medium: return "circle.lefthalf.filled"
        case .high: return "circle.fill"
        }
    }
}

// MARK: - Social Links

struct SocialLink: Codable {
    let platform: SocialPlatform
    let url: String
    let isVerified: Bool
    
    init(platform: SocialPlatform, url: String, isVerified: Bool = false) {
        self.platform = platform
        self.url = url
        self.isVerified = isVerified
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "platform": platform.rawValue,
            "url": url,
            "isVerified": isVerified
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> SocialLink? {
        guard let platformString = data["platform"] as? String,
              let platform = SocialPlatform(rawValue: platformString),
              let url = data["url"] as? String else {
            return nil
        }
        
        let isVerified = data["isVerified"] as? Bool ?? false
        return SocialLink(platform: platform, url: url, isVerified: isVerified)
    }
}

enum SocialPlatform: String, CaseIterable, Codable {
    case twitter = "twitter"
    case discord = "discord"
    case telegram = "telegram"
    case reddit = "reddit"
    case youtube = "youtube"
    case website = "website"
    
    var displayName: String {
        switch self {
        case .twitter: return "Twitter"
        case .discord: return "Discord"
        case .telegram: return "Telegram"
        case .reddit: return "Reddit"
        case .youtube: return "YouTube"
        case .website: return "Website"
        }
    }
    
    var icon: String {
        switch self {
        case .twitter: return "bird"
        case .discord: return "gamecontroller"
        case .telegram: return "paperplane"
        case .reddit: return "r.circle"
        case .youtube: return "play.rectangle"
        case .website: return "globe"
        }
    }
}

// MARK: - Community Extensions

extension Array where Element == Community {
    func sortedByMemberCount() -> [Community] {
        return self.sorted { $0.memberCount > $1.memberCount }
    }
    
    func sortedByActivity() -> [Community] {
        return self.sorted { $0.activeMembers > $1.activeMembers }
    }
    
    func sortedByNewest() -> [Community] {
        return self.sorted { $0.createdAt > $1.createdAt }
    }
    
    func filteredByType(_ type: CommunityType) -> [Community] {
        return self.filter { $0.type == type }
    }
    
    func filteredByPrivacy(showPrivate: Bool) -> [Community] {
        return self.filter { $0.isPrivate == showPrivate }
    }
    
    func searchByName(_ query: String) -> [Community] {
        guard !query.isEmpty else { return self }
        return self.filter { 
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}