// File: Shared/Services/FirebaseServices+Messaging.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

extension FirebaseServices {
    // MARK: - Messaging Methods
    
    func sendMessage(to recipientId: String, content: String, senderId: String) async throws {
        // Create or get conversation
        let conversationId = createConversationId(between: senderId, and: recipientId)
        
        let message = Message(senderId: senderId, recipientId: recipientId, content: content)
        
        let batch = db.batch()
        
        // Add message
        let messageRef = db.collection("messages").document(message.id.uuidString)
        batch.setData([
            "senderId": message.senderId,
            "recipientId": message.recipientId,
            "content": message.content,
            "timestamp": Timestamp(date: message.timestamp),
            "conversationId": conversationId,
            "isRead": false
        ], forDocument: messageRef)
        
        // Update or create conversation
        let conversationRef = db.collection("conversations").document(conversationId)
        batch.setData([
            "participants": [senderId, recipientId].sorted(),
            "lastMessage": content,
            "lastMessageTimestamp": Timestamp(date: Date()),
            "lastMessageSenderId": senderId,
            "updatedAt": Timestamp(date: Date())
        ], forDocument: conversationRef, merge: true)
        
        try await batch.commit()
    }
    
    func getConversations(userId: String) async throws -> [Conversation] {
        let snapshot = try await db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .order(by: "updatedAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Conversation.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func getMessages(conversationId: String, limit: Int = 50) async throws -> [Message] {
        let snapshot = try await db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let messages = snapshot.documents.compactMap { document -> Message? in
            let data = document.data()
            guard let senderId = data["senderId"] as? String,
                  let recipientId = data["recipientId"] as? String,
                  let content = data["content"] as? String else {
                return nil
            }
            
            return Message(senderId: senderId, recipientId: recipientId, content: content)
        }
        
        return messages.reversed()
    }
    
    func markMessagesAsRead(conversationId: String, userId: String) async throws {
        let snapshot = try await db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()
        
        let batch = db.batch()
        
        for document in snapshot.documents {
            batch.updateData(["isRead": true], forDocument: document.reference)
        }
        
        try await batch.commit()
    }
    
    func listenToConversation(conversationId: String, completion: @escaping ([Message]) -> Void) {
        let listener = db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                let messages = documents.compactMap { document -> Message? in
                    let data = document.data()
                    guard let senderId = data["senderId"] as? String,
                          let recipientId = data["recipientId"] as? String,
                          let content = data["content"] as? String else {
                        return nil
                    }
                    
                    return Message(senderId: senderId, recipientId: recipientId, content: content)
                }
                
                completion(messages)
            }
        
        listeners.append(listener)
    }
    
    func deleteMessage(messageId: String) async throws {
        try await db.collection("messages").document(messageId).delete()
    }
    
    func getUnreadMessageCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("messages")
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()
        
        return snapshot.documents.count
    }
}
