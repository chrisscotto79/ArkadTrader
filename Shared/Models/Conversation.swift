//
//  Conversation.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/13/25.
//



// File: Shared/Models/Conversation.swift
import Foundation
import FirebaseFirestore

struct Conversation: Identifiable, Codable {
    let id: String
    let participants: [String]
    let lastMessage: String
    let lastMessageTimestamp: Date
    let lastMessageSenderId: String
    let updatedAt: Date
    
    static func fromFirestore(data: [String: Any], id: String) throws -> Conversation {
        guard let participants = data["participants"] as? [String],
              let lastMessage = data["lastMessage"] as? String,
              let lastMessageTimestamp = data["lastMessageTimestamp"] as? Timestamp,
              let lastMessageSenderId = data["lastMessageSenderId"] as? String,
              let updatedAt = data["updatedAt"] as? Timestamp else {
            throw NSError(domain: "ConversationDecoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid conversation data"])
        }
        
        return Conversation(
            id: id,
            participants: participants,
            lastMessage: lastMessage,
            lastMessageTimestamp: lastMessageTimestamp.dateValue(),
            lastMessageSenderId: lastMessageSenderId,
            updatedAt: updatedAt.dateValue()
        )
    }
}