//
//  ChannelChatView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/24/25.
//


// File: Core/Communities/Views/Detail/ChannelChatView.swift
// Discord-style Channel Chat View for Community Channels

import SwiftUI

struct ChannelChatView: View {
    let community: Community
    let channel: Channel
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ChannelChatViewModel()
    @State private var messageText = ""
    @FocusState private var isMessageFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Channel Header
            channelHeader
            
            // Messages List
            messagesScrollView
            
            // Message Input
            messageInputSection
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .onAppear {
            print("🗨️ ChannelChatView appeared for #\(channel.name)")
            viewModel.loadChannelData(community: community, channel: channel)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

// MARK: - Channel Header
extension ChannelChatView {
    private var channelHeader: some View {
        VStack(spacing: 0) {
            HStack {
                // Back Button
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(community.name)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                
                Spacer()
                
                // Channel Info
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: getChannelIcon())
                            .font(.subheadline)
                            .foregroundColor(getChannelColor())
                        
                        Text("#\(channel.name)")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    
                    if channel.adminOnly {
                        Text("Admin Only")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Channel Settings Button (if admin)
                if viewModel.canUserManageChannel {
                    Button(action: {
                        print("⚙️ Channel settings tapped")
                        // TODO: Show channel settings
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                } else {
                    // Placeholder for alignment
                    Color.clear
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Messages Scroll View
extension ChannelChatView {
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        emptyChannelState
                    } else {
                        ForEach(viewModel.messages) { message in
                            ChannelMessageRow(
                                message: message,
                                showUsername: shouldShowUsername(message),
                                isUserMessage: message.authorId == viewModel.currentUserId
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .onChange(of: viewModel.messages.count) { _ in
                // Auto-scroll to bottom when new message arrives
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var emptyChannelState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(getChannelColor().opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: getChannelIcon())
                    .font(.system(size: 32))
                    .foregroundColor(getChannelColor())
            }
            
            VStack(spacing: 8) {
                Text("Welcome to #\(channel.name)!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(getChannelDescription())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            if channel.adminOnly && !viewModel.canUserPost {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Only admins can post in this channel")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Message Input Section
extension ChannelChatView {
    private var messageInputSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Message TextField
                TextField(getPlaceholderText(), text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
                    .focused($isMessageFieldFocused)
                    .disabled(!viewModel.canUserPost)
                    .onSubmit {
                        sendMessage()
                    }
                
                // Send Button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.canUserPost)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        viewModel.sendMessage(content: trimmedMessage)
        messageText = ""
    }
}

// MARK: - Helper Methods
extension ChannelChatView {
    private func getChannelIcon() -> String {
        switch channel.type {
        case .text: return "number"
        case .callouts: return "megaphone"
        case .voice: return "speaker.wave.2"
        }
    }
    
    private func getChannelColor() -> Color {
        switch channel.type {
        case .text: return .blue
        case .callouts: return .orange
        case .voice: return .green
        }
    }
    
    private func getChannelDescription() -> String {
        switch channel.type {
        case .text: return "This is the start of the #\(channel.name) channel."
        case .callouts: return "Trading callouts and signals will be posted here by admins."
        case .voice: return "Join the voice channel to chat with other members."
        }
    }
    
    private func getPlaceholderText() -> String {
        if !viewModel.canUserPost {
            return "You don't have permission to send messages"
        }
        return "Message #\(channel.name)"
    }
    
    private func shouldShowUsername(_ message: CommunityMessage) -> Bool {
        guard let messageIndex = viewModel.messages.firstIndex(where: { $0.id == message.id }) else {
            return true
        }
        
        // Show username if it's the first message or if the previous message is from a different user
        if messageIndex == 0 {
            return true
        }
        
        let previousMessage = viewModel.messages[messageIndex - 1]
        return previousMessage.authorId != message.authorId
    }
}

// MARK: - Channel Message Row Component
struct ChannelMessageRow: View {
    let message: CommunityMessage
    let showUsername: Bool
    let isUserMessage: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User Avatar
            if showUsername {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(getUserInitials())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    )
            } else {
                Color.clear
                    .frame(width: 40, height: 40)
            }
            
            // Message Content
            VStack(alignment: .leading, spacing: 4) {
                if showUsername {
                    HStack(spacing: 8) {
                        Text(message.authorUsername)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(formatTimestamp(message.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, showUsername ? 8 : 2)
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: Add message actions (reply, react, etc.)
        }
    }
    
    private func getUserInitials() -> String {
        let words = message.authorUsername.components(separatedBy: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else {
            return String(message.authorUsername.prefix(2)).uppercased()
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday at \(DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short))"
        } else {
            formatter.dateFormat = "M/d/yy h:mm a"
        }
        
        return formatter.string(from: date)
    }
}

#Preview {
    let testCommunity = Community(
        name: "Elite Traders",
        description: "Premium trading community",
        type: .dayTrading,
        creatorId: "test-user",
        memberCount: 50,
        isPrivate: false
    )
    
    let testChannel = Channel(
        name: "general",
        type: .text,
        communityId: testCommunity.id,
        isDefault: true,
        adminOnly: false
    )
    
    return NavigationView {
        ChannelChatView(community: testCommunity, channel: testChannel)
    }
    .environmentObject(FirebaseAuthService.shared)
}