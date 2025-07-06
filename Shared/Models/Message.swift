// File: Shared/Models/Message.swift
// Simplified Message Model (for future use)

import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let senderId: String
    let recipientId: String
    let content: String
    let timestamp: Date
    
    init(senderId: String, recipientId: String, content: String) {
        self.id = UUID()
        self.senderId = senderId
        self.recipientId = recipientId
        self.content = content
        self.timestamp = Date()
    }
}
