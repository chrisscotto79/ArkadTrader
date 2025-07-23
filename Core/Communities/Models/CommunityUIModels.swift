//
//  CommunityUIModels.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/19/25.
//

import Foundation
import FirebaseFirestore

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
