// File: Shared/Models/Community.swift
// Simplified Community Model

import Foundation
import FirebaseFirestore

struct Community: Identifiable, Codable {
    var id: String
    var name: String
    var description: String
    var type: CommunityType
    var createdBy: String
    var memberCount: Int
    var createdAt: Date
    
    // Initializer
    init(name: String, description: String, type: CommunityType, createdBy: String) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.type = type
        self.createdBy = createdBy
        self.memberCount = 1
        self.createdAt = Date()
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "name": name,
            "description": description,
            "type": type.rawValue,
            "createdBy": createdBy,
            "memberCount": memberCount,
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
        
        var community = Community(name: name, description: description, type: type, createdBy: createdBy)
        community.id = id
        community.memberCount = memberCount
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
