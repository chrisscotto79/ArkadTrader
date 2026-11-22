//
//  CommunityUIModels.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/19/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI

// FirestoreError is already defined elsewhere in the project

// MARK: - Channel Model
struct Channel: Identifiable, Codable {
    var id: String
    var name: String
    var type: ChannelType
    var communityId: String
    var isDefault: Bool // #general and #callouts are default channels
    var adminOnly: Bool // For #callouts channel
    var createdAt: Date
    
    init(name: String, type: ChannelType, communityId: String, isDefault: Bool = false, adminOnly: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.type = type
        self.communityId = communityId
        self.isDefault = isDefault
        self.adminOnly = adminOnly
        self.createdAt = Date()
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "name": name,
            "type": type.rawValue,
            "communityId": communityId,
            "isDefault": isDefault,
            "adminOnly": adminOnly,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> Channel {
        guard let name = data["name"] as? String,
              let typeString = data["type"] as? String,
              let type = ChannelType(rawValue: typeString),
              let communityId = data["communityId"] as? String,
              let isDefault = data["isDefault"] as? Bool,
              let adminOnly = data["adminOnly"] as? Bool,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        var channel = Channel(name: name, type: type, communityId: communityId, isDefault: isDefault, adminOnly: adminOnly)
        channel.id = id
        channel.createdAt = createdAtTimestamp.dateValue()
        return channel
    }
}

// MARK: - Channel Type Enum
enum ChannelType: String, CaseIterable, Codable {
    case text = "text"
    case callouts = "callouts"
    case voice = "voice"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .callouts: return "Callouts"
        case .voice: return "Voice"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "number"
        case .callouts: return "megaphone"
        case .voice: return "speaker.wave.2"
        }
    }
}

// MARK: - CommunityMessage Model
struct CommunityMessage: Identifiable, Codable {
    var id: String
    var content: String
    var authorId: String
    var authorUsername: String
    var channelId: String
    var communityId: String
    var createdAt: Date
    /// Structured trade callout, when this message is one
    var callout: TradeCallout?
    
    init(content: String, authorId: String, authorUsername: String, channelId: String, communityId: String) {
        self.id = UUID().uuidString
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.channelId = channelId
        self.communityId = communityId
        self.createdAt = Date()
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "content": content,
            "authorId": authorId,
            "authorUsername": authorUsername,
            "channelId": channelId,
            "communityId": communityId,
            "createdAt": Timestamp(date: createdAt)
        ]
        if let callout { data["callout"] = callout.toFirestore() }
        return data
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> CommunityMessage {
        guard let content = data["content"] as? String,
              let authorId = data["authorId"] as? String,
              let authorUsername = data["authorUsername"] as? String,
              let channelId = data["channelId"] as? String,
              let communityId = data["communityId"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        var message = CommunityMessage(
            content: content,
            authorId: authorId,
            authorUsername: authorUsername,
            channelId: channelId,
            communityId: communityId
        )
        message.id = id
        message.createdAt = createdAtTimestamp.dateValue()
        if let calloutData = data["callout"] as? [String: Any] {
            message.callout = TradeCallout.fromFirestore(calloutData)
        }
        return message
    }
}

// MARK: - Enhanced Community Settings with Image Support
struct CommunitySettings {
    var name: String
    var description: String
    var isPrivate: Bool
    
    // ✅ ENHANCED: Support both property naming conventions
    // Store internally as the Community model expects
    private var _avatarURL: String?
    private var _bannerURL: String?
    
    // ✅ ENHANCED: Computed properties for compatibility with UI code
    var profileImageUrl: String? {
        get { return _avatarURL }
        set { _avatarURL = newValue }
    }
    
    var bannerImageUrl: String? {
        get { return _bannerURL }
        set { _bannerURL = newValue }
    }
    
    // ✅ ENHANCED: Direct access properties for Community model mapping
    var avatarURL: String? {
        get { return _avatarURL }
        set { _avatarURL = newValue }
    }
    
    var bannerURL: String? {
        get { return _bannerURL }
        set { _bannerURL = newValue }
    }
    
    // ✅ ENHANCED: Helper computed properties
    var hasAvatarImage: Bool {
        return _avatarURL != nil && !_avatarURL!.isEmpty
    }
    
    var hasBannerImage: Bool {
        return _bannerURL != nil && !_bannerURL!.isEmpty
    }
    
    init(from community: Community) {
        self.name = community.name
        self.description = community.description
        self.isPrivate = community.isPrivate
        
        // ✅ ENHANCED: Map from Community model properties
        self._avatarURL = community.avatarURL
        self._bannerURL = community.bannerURL
    }
    
    // ✅ ENHANCED: Initialize with empty values for new communities
    init() {
        self.name = ""
        self.description = ""
        self.isPrivate = false
        self._avatarURL = nil
        self._bannerURL = nil
    }
    
    // ✅ ENHANCED: Convert back to community for updates with proper mapping
    func updateCommunity(_ community: Community) -> Community {
        var updatedCommunity = community
        updatedCommunity.name = self.name
        updatedCommunity.description = self.description
        updatedCommunity.isPrivate = self.isPrivate
        
        // ✅ ENHANCED: Map back to Community model properties
        updatedCommunity.avatarURL = self._avatarURL
        updatedCommunity.bannerURL = self._bannerURL
        
        return updatedCommunity
    }
    
    // ✅ ENHANCED: Validation methods
    func isValidForSave() -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               name.count >= 3 &&
               description.count >= 10
    }
    
    func validationMessage() -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Community name is required"
        }
        if name.count < 3 {
            return "Community name must be at least 3 characters"
        }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Community description is required"
        }
        if description.count < 10 {
            return "Community description must be at least 10 characters"
        }
        return nil
    }
    
    // ✅ ENHANCED: Clear image methods
    mutating func clearAvatar() {
        self._avatarURL = nil
    }
    
    mutating func clearBanner() {
        self._bannerURL = nil
    }
    
    // ✅ ENHANCED: Set image URLs
    mutating func setAvatarURL(_ url: String?) {
        self._avatarURL = url
    }
    
    mutating func setBannerURL(_ url: String?) {
        self._bannerURL = url
    }
}

// MARK: - Community Role Enum (Enhanced)
enum CommunityRole: String, CaseIterable, Codable {
    case owner = "owner"
    case admin = "admin"
    case moderator = "moderator"
    case member = "member"
    
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .moderator: return "Moderator"
        case .member: return "Member"
        }
    }
    
    var color: Color {
        switch self {
        case .owner: return .purple
        case .admin: return .orange
        case .moderator: return .blue
        case .member: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "star.fill"
        case .moderator: return "shield.fill"
        case .member: return "person.fill"
        }
    }
    
    // Role hierarchy for permissions
    var hierarchyLevel: Int {
        switch self {
        case .owner: return 4
        case .admin: return 3
        case .moderator: return 2
        case .member: return 1
        }
    }
    
    // ✅ ENHANCED: Additional role methods
    var canManageImages: Bool {
        return hierarchyLevel >= 4 // Only owners can manage community images
    }
    
    var canManageSettings: Bool {
        return hierarchyLevel >= 4 // Only owners can manage settings
    }
    
    var canManageMembers: Bool {
        return hierarchyLevel >= 3 // Admins and above can manage members
    }
    
    var canManageChannels: Bool {
        return hierarchyLevel >= 3 // Admins and above can manage channels
    }
    
    // Can this role manage the target role?
    func canManage(_ targetRole: CommunityRole) -> Bool {
        return self.hierarchyLevel > targetRole.hierarchyLevel
    }
}

// MARK: - Enhanced Community Member With Role
struct CommunityMemberWithRole: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let username: String
    let fullName: String
    let role: CommunityRole
    let joinedAt: Date
    let isOnline: Bool // We can add this later
    
    // ✅ ENHANCED: Additional properties
    var profileImageUrl: String?
    var isVerified: Bool
    var lastActiveAt: Date?
    
    init(userId: String, username: String, fullName: String, role: CommunityRole = .member, joinedAt: Date = Date(), profileImageUrl: String? = nil, isVerified: Bool = false) {
        self.id = userId
        self.userId = userId
        self.username = username
        self.fullName = fullName
        self.role = role
        self.joinedAt = joinedAt
        self.isOnline = false // Default for now
        self.profileImageUrl = profileImageUrl
        self.isVerified = isVerified
        self.lastActiveAt = nil
    }
    
    // ✅ ENHANCED: Computed properties
    var initials: String {
        let components = fullName.components(separatedBy: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[1].prefix(1))
            return (first + last).uppercased()
        } else {
            return String(fullName.prefix(2)).uppercased()
        }
    }
    
    var displayName: String {
        return fullName.isEmpty ? username : fullName
    }
    
    var timeInCommunity: String {
        let now = Date()
        let interval = now.timeIntervalSince(joinedAt)
        let days = Int(interval / 86400)
        
        if days < 1 {
            return "Joined today"
        } else if days < 30 {
            return "Joined \(days) day\(days == 1 ? "" : "s") ago"
        } else if days < 365 {
            let months = Int(days / 30)
            return "Joined \(months) month\(months == 1 ? "" : "s") ago"
        } else {
            let years = Int(days / 365)
            return "Joined \(years) year\(years == 1 ? "" : "s") ago"
        }
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "username": username,
            "fullName": fullName,
            "role": role.rawValue,
            "joinedAt": Timestamp(date: joinedAt),
            "isVerified": isVerified
        ]
        
        if let profileImageUrl = profileImageUrl {
            data["profileImageUrl"] = profileImageUrl
        }
        
        if let lastActiveAt = lastActiveAt {
            data["lastActiveAt"] = Timestamp(date: lastActiveAt)
        }
        
        return data
    }
    
    static func fromFirestore(data: [String: Any]) throws -> CommunityMemberWithRole {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let fullName = data["fullName"] as? String,
              let roleString = data["role"] as? String,
              let role = CommunityRole(rawValue: roleString),
              let joinedAtTimestamp = data["joinedAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        var member = CommunityMemberWithRole(
            userId: userId,
            username: username,
            fullName: fullName,
            role: role,
            joinedAt: joinedAtTimestamp.dateValue(),
            profileImageUrl: data["profileImageUrl"] as? String,
            isVerified: data["isVerified"] as? Bool ?? false
        )
        
        if let lastActiveTimestamp = data["lastActiveAt"] as? Timestamp {
            member.lastActiveAt = lastActiveTimestamp.dateValue()
        }
        
        return member
    }
    
    // ✅ ENHANCED: Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CommunityMemberWithRole, rhs: CommunityMemberWithRole) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Enhanced Community Rule
struct CommunityRule: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var description: String
    var isRequired: Bool // Must acknowledge to join
    var order: Int // Display order
    var isDefault: Bool // Default rule (can't be deleted)
    var createdAt: Date
    var category: String? // Rule category (e.g., "Trading", "Behavior", "Content")
    var iconName: String? // Optional icon for the rule
    
    // ✅ ENHANCED: Additional properties
    var isActive: Bool
    var violationCount: Int
    var lastUpdated: Date?
    
    init(title: String, description: String, isRequired: Bool = true, order: Int = 0, isDefault: Bool = false, category: String? = nil, iconName: String? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.isRequired = isRequired
        self.order = order
        self.isDefault = isDefault
        self.createdAt = Date()
        self.category = category
        self.iconName = iconName
        self.isActive = true
        self.violationCount = 0
        self.lastUpdated = nil
    }
    
    // ✅ ENHANCED: Computed properties
    var categoryIcon: String {
        guard let category = category else { return "doc.text" }
        
        switch category.lowercased() {
        case "legal": return "scale.3d"
        case "risk management": return "shield.fill"
        case "trading content": return "chart.bar.fill"
        case "content policy": return "doc.plaintext"
        case "behavior": return "person.2.fill"
        default: return iconName ?? "doc.text"
        }
    }
    
    var categoryColor: Color {
        guard let category = category else { return .blue }
        
        switch category.lowercased() {
        case "legal": return .red
        case "risk management": return .orange
        case "trading content": return .green
        case "content policy": return .purple
        case "behavior": return .blue
        default: return .gray
        }
    }
    
    var priorityLevel: Int {
        if isRequired && isDefault {
            return 3 // Highest priority
        } else if isRequired {
            return 2 // High priority
        } else {
            return 1 // Normal priority
        }
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "title": title,
            "description": description,
            "isRequired": isRequired,
            "order": order,
            "isDefault": isDefault,
            "createdAt": Timestamp(date: createdAt),
            "isActive": isActive,
            "violationCount": violationCount
        ]
        
        if let category = category {
            data["category"] = category
        }
        if let iconName = iconName {
            data["iconName"] = iconName
        }
        if let lastUpdated = lastUpdated {
            data["lastUpdated"] = Timestamp(date: lastUpdated)
        }
        
        return data
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> CommunityRule {
        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let isRequired = data["isRequired"] as? Bool,
              let order = data["order"] as? Int,
              let isDefault = data["isDefault"] as? Bool,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        var rule = CommunityRule(
            title: title,
            description: description,
            isRequired: isRequired,
            order: order,
            isDefault: isDefault,
            category: data["category"] as? String,
            iconName: data["iconName"] as? String
        )
        rule.id = id
        rule.createdAt = createdAtTimestamp.dateValue()
        rule.isActive = data["isActive"] as? Bool ?? true
        rule.violationCount = data["violationCount"] as? Int ?? 0
        
        if let lastUpdatedTimestamp = data["lastUpdated"] as? Timestamp {
            rule.lastUpdated = lastUpdatedTimestamp.dateValue()
        }
        
        return rule
    }
    
    // ✅ ENHANCED: Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CommunityRule, rhs: CommunityRule) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Enhanced Default Financial Disclaimer Rules
    static func getDefaultTradingRules() -> [CommunityRule] {
        return [
            CommunityRule(
                title: "⚠️ Not Financial Advice",
                description: "All content shared in this community is for educational and informational purposes only. Nothing shared here constitutes financial, investment, or trading advice. All trading involves substantial risk of loss. You are solely responsible for your own trading decisions.",
                isRequired: true,
                order: 1,
                isDefault: true,
                category: "Legal",
                iconName: "exclamationmark.triangle.fill"
            ),
            
            CommunityRule(
                title: "🚨 Risk Disclaimer",
                description: "Trading stocks, options, crypto, and other financial instruments involves significant risk of loss. Past performance does not guarantee future results. Never trade with money you cannot afford to lose. All members trade at their own risk.",
                isRequired: true,
                order: 2,
                isDefault: true,
                category: "Risk Management",
                iconName: "shield.slash.fill"
            ),
            
            CommunityRule(
                title: "📊 Trade Documentation",
                description: "When sharing trades or callouts, please provide clear entry/exit points, position size, and risk management details. This helps maintain educational value and transparency for the community.",
                isRequired: false,
                order: 3,
                isDefault: true,
                category: "Trading Content",
                iconName: "chart.bar.doc.horizontal"
            ),
            
            CommunityRule(
                title: "🚫 No Pump & Dump",
                description: "Promoting securities with intent to artificially inflate prices is strictly prohibited. Share genuine analysis and educational content only. Misleading or manipulative content will result in immediate removal.",
                isRequired: true,
                order: 4,
                isDefault: true,
                category: "Content Policy",
                iconName: "hand.raised.slash.fill"
            ),
            
            CommunityRule(
                title: "🤝 Respectful Communication",
                description: "Maintain respectful dialogue even during disagreements. No harassment, personal attacks, or offensive language. We're here to learn from each other and improve our trading skills together.",
                isRequired: true,
                order: 5,
                isDefault: true,
                category: "Behavior",
                iconName: "person.2.fill"
            )
        ]
    }
}

// MARK: - Enhanced Community Moderation Settings
struct CommunityModerationSettings: Codable {
    var autoModEnabled: Bool
    var requireApproval: Bool // For new members
    var bannedWords: [String]
    var maxMessagesPerMinute: Int
    var linkPostingAllowed: Bool
    var imagePostingAllowed: Bool
    
    // ✅ ENHANCED: Additional moderation settings
    var slowModeEnabled: Bool
    var slowModeInterval: TimeInterval // in seconds
    var autoDeleteSpam: Bool
    var requireEmailVerification: Bool
    var minimumAccountAge: TimeInterval // in seconds
    var allowedFileTypes: [String]
    var maxFileSize: Int // in bytes
    
    init() {
        self.autoModEnabled = true
        self.requireApproval = false
        self.bannedWords = []
        self.maxMessagesPerMinute = 10
        self.linkPostingAllowed = true
        self.imagePostingAllowed = true
        self.slowModeEnabled = false
        self.slowModeInterval = 30
        self.autoDeleteSpam = true
        self.requireEmailVerification = false
        self.minimumAccountAge = 0
        self.allowedFileTypes = ["jpg", "jpeg", "png", "gif", "webp"]
        self.maxFileSize = 10 * 1024 * 1024 // 10MB
    }
    
    // ✅ ENHANCED: Computed properties
    var isStrictMode: Bool {
        return autoModEnabled && requireApproval && slowModeEnabled && requireEmailVerification
    }
    
    var moderationLevel: String {
        if isStrictMode {
            return "Strict"
        } else if autoModEnabled && (requireApproval || slowModeEnabled) {
            return "Moderate"
        } else if autoModEnabled {
            return "Basic"
        } else {
            return "Disabled"
        }
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "autoModEnabled": autoModEnabled,
            "requireApproval": requireApproval,
            "bannedWords": bannedWords,
            "maxMessagesPerMinute": maxMessagesPerMinute,
            "linkPostingAllowed": linkPostingAllowed,
            "imagePostingAllowed": imagePostingAllowed,
            "slowModeEnabled": slowModeEnabled,
            "slowModeInterval": slowModeInterval,
            "autoDeleteSpam": autoDeleteSpam,
            "requireEmailVerification": requireEmailVerification,
            "minimumAccountAge": minimumAccountAge,
            "allowedFileTypes": allowedFileTypes,
            "maxFileSize": maxFileSize
        ]
    }
    
    static func fromFirestore(data: [String: Any]) throws -> CommunityModerationSettings {
        var settings = CommunityModerationSettings()
        
        settings.autoModEnabled = data["autoModEnabled"] as? Bool ?? true
        settings.requireApproval = data["requireApproval"] as? Bool ?? false
        settings.bannedWords = data["bannedWords"] as? [String] ?? []
        settings.maxMessagesPerMinute = data["maxMessagesPerMinute"] as? Int ?? 10
        settings.linkPostingAllowed = data["linkPostingAllowed"] as? Bool ?? true
        settings.imagePostingAllowed = data["imagePostingAllowed"] as? Bool ?? true
        settings.slowModeEnabled = data["slowModeEnabled"] as? Bool ?? false
        settings.slowModeInterval = data["slowModeInterval"] as? TimeInterval ?? 30
        settings.autoDeleteSpam = data["autoDeleteSpam"] as? Bool ?? true
        settings.requireEmailVerification = data["requireEmailVerification"] as? Bool ?? false
        settings.minimumAccountAge = data["minimumAccountAge"] as? TimeInterval ?? 0
        settings.allowedFileTypes = data["allowedFileTypes"] as? [String] ?? ["jpg", "jpeg", "png", "gif", "webp"]
        settings.maxFileSize = data["maxFileSize"] as? Int ?? 10 * 1024 * 1024
        
        return settings
    }
}
