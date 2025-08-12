//
//  CommunityUIModels.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/19/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI

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
        return [
            "content": content,
            "authorId": authorId,
            "authorUsername": authorUsername,
            "channelId": channelId,
            "communityId": communityId,
            "createdAt": Timestamp(date: createdAt)
        ]
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
        return message
    }
}

struct CommunitySettings {
    var name: String
    var description: String
    var isPrivate: Bool
    
    init(from community: Community) {
        self.name = community.name
        self.description = community.description
        self.isPrivate = community.isPrivate
    }
    
    // Convert back to community for updates
    func updateCommunity(_ community: Community) -> Community {
        var updatedCommunity = community
        updatedCommunity.name = self.name
        updatedCommunity.description = self.description
        updatedCommunity.isPrivate = self.isPrivate
        return updatedCommunity
    }
}
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
    
    // Can this role manage the target role?
    func canManage(_ targetRole: CommunityRole) -> Bool {
        return self.hierarchyLevel > targetRole.hierarchyLevel
    }
}

struct CommunityMemberWithRole: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let fullName: String
    let role: CommunityRole
    let joinedAt: Date
    let isOnline: Bool // We can add this later
    
    init(userId: String, username: String, fullName: String, role: CommunityRole = .member, joinedAt: Date = Date()) {
        self.id = userId
        self.userId = userId
        self.username = username
        self.fullName = fullName
        self.role = role
        self.joinedAt = joinedAt
        self.isOnline = false // Default for now
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "userId": userId,
            "username": username,
            "fullName": fullName,
            "role": role.rawValue,
            "joinedAt": Timestamp(date: joinedAt)
        ]
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
        
        return CommunityMemberWithRole(
            userId: userId,
            username: username,
            fullName: fullName,
            role: role,
            joinedAt: joinedAtTimestamp.dateValue()
        )
    }
}
struct CommunityRule: Identifiable, Codable {
    var id: String
    var title: String
    var description: String
    var isRequired: Bool // Must acknowledge to join
    var order: Int // Display order
    var isDefault: Bool // Default rule (can't be deleted)
    var createdAt: Date
    
    init(title: String, description: String, isRequired: Bool = true, order: Int = 0, isDefault: Bool = false) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.isRequired = isRequired
        self.order = order
        self.isDefault = isDefault
        self.createdAt = Date()
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "title": title,
            "description": description,
            "isRequired": isRequired,
            "order": order,
            "isDefault": isDefault,
            "createdAt": Timestamp(date: createdAt)
        ]
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
            isDefault: isDefault
        )
        rule.id = id
        rule.createdAt = createdAtTimestamp.dateValue()
        
        return rule
    }
    
    // MARK: - Default Financial Disclaimer Rules
    static func getDefaultTradingRules() -> [CommunityRule] {
        return [
            CommunityRule(
                title: "⚠️ Not Financial Advice",
                description: "All content shared in this community is for educational and informational purposes only. Nothing shared here constitutes financial, investment, or trading advice. All trading involves substantial risk of loss. You are solely responsible for your own trading decisions.",
                isRequired: true,
                order: 1,
                isDefault: true
            ),
            
            CommunityRule(
                title: "🚨 Risk Disclaimer",
                description: "Trading stocks, options, crypto, and other financial instruments involves significant risk of loss. Past performance does not guarantee future results. Never trade with money you cannot afford to lose. All members trade at their own risk.",
                isRequired: true,
                order: 2,
                isDefault: true
            ),
            
            CommunityRule(
                title: "📊 Trade Documentation",
                description: "When sharing trades or callouts, please provide clear entry/exit points, position size, and risk management details. This helps maintain educational value and transparency for the community.",
                isRequired: false,
                order: 3,
                isDefault: true
            ),
            
            CommunityRule(
                title: "🚫 No Pump & Dump",
                description: "Promoting securities with intent to artificially inflate prices is strictly prohibited. Share genuine analysis and educational content only. Misleading or manipulative content will result in immediate removal.",
                isRequired: true,
                order: 4,
                isDefault: true
            ),
            
            CommunityRule(
                title: "🤝 Respectful Communication",
                description: "Maintain respectful dialogue even during disagreements. No harassment, personal attacks, or offensive language. We're here to learn from each other and improve our trading skills together.",
                isRequired: true,
                order: 5,
                isDefault: true
            )
        ]
    }
}

struct CommunityModerationSettings: Codable {
    var autoModEnabled: Bool
    var requireApproval: Bool // For new members
    var bannedWords: [String]
    var maxMessagesPerMinute: Int
    var linkPostingAllowed: Bool
    var imagePostingAllowed: Bool
    
    init() {
        self.autoModEnabled = true
        self.requireApproval = false
        self.bannedWords = []
        self.maxMessagesPerMinute = 10
        self.linkPostingAllowed = true
        self.imagePostingAllowed = true
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "autoModEnabled": autoModEnabled,
            "requireApproval": requireApproval,
            "bannedWords": bannedWords,
            "maxMessagesPerMinute": maxMessagesPerMinute,
            "linkPostingAllowed": linkPostingAllowed,
            "imagePostingAllowed": imagePostingAllowed
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
        
        return settings
    }
}
