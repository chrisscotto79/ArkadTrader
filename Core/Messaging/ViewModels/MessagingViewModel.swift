//
//  MessagingViewModel.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/19/25.
//



// File: Core/Messaging/ViewModels/MessagingViewModel.swift
// Minimal version to prevent errors

import Foundation

@MainActor
class MessagingViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isLoading = false
    @Published var isLoadingMessages = false
    
    init() {
        // Initialize empty for now
    }
    
    func loadConversations() {
        // TODO: Implement
    }
    
    func selectConversation(_ conversation: Conversation) {
        // TODO: Implement
    }
    
    func loadMessages(for conversationId: String) {
        // TODO: Implement
    }
    
    func sendMessage() {
        // TODO: Implement
    }
    
    func startConversation(with user: User) {
        // TODO: Implement
    }
    
    var unreadCount: Int {
        return 0
    }
    
    func getOtherParticipant(in conversation: Conversation) -> User? {
        return nil
    }
}