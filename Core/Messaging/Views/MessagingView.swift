// File: Core/Messaging/Views/MessagingView.swift

import SwiftUI

struct MessagingView: View {
    @State private var searchText = ""
    
    // Mock conversations
    @State private var mockConversations: [MockConversation] = [
        MockConversation(
            id: UUID(),
            userName: "John Doe",
            userHandle: "@johndoe",
            lastMessage: "Hey, what do you think about AAPL?",
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            unreadCount: 2
        ),
        MockConversation(
            id: UUID(),
            userName: "Jane Smith",
            userHandle: "@janetrader",
            lastMessage: "Just closed my TSLA position!",
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            unreadCount: 0
        ),
        MockConversation(
            id: UUID(),
            userName: "Mike Johnson",
            userHandle: "@mikeinvests",
            lastMessage: "Thanks for the tip!",
            timestamp: Date().addingTimeInterval(-86400), // 1 day ago
            unreadCount: 0
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search conversations...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)
                
                // Conversations List
                if mockConversations.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "message")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No Messages Yet")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        Text("Start a conversation with other traders")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {}) {
                            Text("Start New Message")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.arkadBlack)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.arkadGold)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 100)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(mockConversations) { conversation in
                                NavigationLink(destination: ChatView(conversation: conversation)) {
                                    ConversationRow(conversation: conversation)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading, 70)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.arkadGold)
                    }
                }
            }
        }
    }
}

// MARK: - Mock Conversation Model
struct MockConversation: Identifiable {
    let id: UUID
    let userName: String
    let userHandle: String
    let lastMessage: String
    let timestamp: Date
    let unreadCount: Int
}

// MARK: - Conversation Row
struct ConversationRow: View {
    let conversation: MockConversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            Circle()
                .fill(Color.arkadGold.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(initials)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.userName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(timeAgo)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text(conversation.lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.arkadGold)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
    }
    
    private var initials: String {
        let names = conversation.userName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return String(firstInitial) + String(lastInitial)
    }
    
    private var timeAgo: String {
        let interval = Date().timeIntervalSince(conversation.timestamp)
        
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }
}

// MARK: - Chat View
struct ChatView: View {
    let conversation: MockConversation
    @State private var messageText = ""
    @State private var messages: [MockMessage] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            
            // Message Input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.arkadGold)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color.white)
        }
        .navigationTitle(conversation.userName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMockMessages()
        }
    }
    
    private func sendMessage() {
        let newMessage = MockMessage(
            id: UUID(),
            text: messageText,
            isFromCurrentUser: true,
            timestamp: Date()
        )
        messages.append(newMessage)
        messageText = ""
    }
    
    private func loadMockMessages() {
        messages = [
            MockMessage(id: UUID(), text: "Hey there!", isFromCurrentUser: false, timestamp: Date().addingTimeInterval(-300)),
            MockMessage(id: UUID(), text: "Hi! How's your trading going?", isFromCurrentUser: true, timestamp: Date().addingTimeInterval(-240)),
            MockMessage(id: UUID(), text: conversation.lastMessage, isFromCurrentUser: false, timestamp: Date().addingTimeInterval(-180))
        ]
    }
}

// MARK: - Mock Message Model
struct MockMessage: Identifiable {
    let id: UUID
    let text: String
    let isFromCurrentUser: Bool
    let timestamp: Date
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: MockMessage
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            Text(message.text)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(message.isFromCurrentUser ? Color.arkadGold : Color.gray.opacity(0.2))
                .foregroundColor(message.isFromCurrentUser ? .arkadBlack : .primary)
                .cornerRadius(18)
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
    }
}

#Preview {
    MessagingView()
}
