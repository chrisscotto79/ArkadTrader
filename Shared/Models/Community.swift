// File: Shared/Models/Community.swift
// Fixed Community Model with isPrivate support

import Foundation
import FirebaseFirestore

struct Community: Identifiable, Codable {
    var id: String
    var name: String
    var description: String
    var type: CommunityType
    var createdBy: String  // This is the creatorId
    var creatorId: String { createdBy }  // Computed property for compatibility
    var memberCount: Int
    var isPrivate: Bool
    var createdAt: Date
    
    // Initializer
    init(name: String, description: String, type: CommunityType = .general, creatorId: String, memberCount: Int = 1, isPrivate: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.type = type
        self.createdBy = creatorId
        self.memberCount = memberCount
        self.isPrivate = isPrivate
        self.createdAt = Date()
    }
    
    // Compatibility initializer for existing code
    init(name: String, description: String, type: CommunityType, createdBy: String) {
        self.init(name: name, description: description, type: type, creatorId: createdBy, memberCount: 1, isPrivate: false)
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "name": name,
            "description": description,
            "type": type.rawValue,
            "createdBy": createdBy,
            "memberCount": memberCount,
            "isPrivate": isPrivate,
            "createdAt": Timestamp(date: createdAt)
        ]
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
}

// Firestore error enum if not already defined

