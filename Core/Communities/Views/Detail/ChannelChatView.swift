// File: Core/Communities/Views/Detail/ChannelChatView.swift
// FIREBASE INTEGRATED VERSION - Real-time Persistent Reactions

import SwiftUI

struct ChannelChatView: View {
    let community: Community
    let channel: Channel
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ChannelChatViewModel()
    @State private var messageText = ""
    @State private var showingChannelInfo = false
    @State private var selectedMessage: CommunityMessage?
    @State private var replyingTo: CommunityMessage?
    @State private var editingMessage: CommunityMessage?
    @State private var editedContent = ""
    @State private var showDeleteConfirmation = false
    @State private var messageToDelete: CommunityMessage?
    @State private var showEmojiPicker = false
    @FocusState private var isMessageFieldFocused: Bool
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Enhanced Channel Header
                channelHeader
                
                // Messages List
                messagesScrollView
                
                // Reply Banner (if replying)
                if let replyingTo = replyingTo {
                    replyBanner(to: replyingTo)
                }
                
                // Edit Banner (if editing)
                if editingMessage != nil {
                    editBanner
                }
                
                // Message Input
                messageInputSection
            }
            
            // Firebase-powered Emoji Picker
            if showEmojiPicker {
                firebaseEmojiPicker
            }
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
        .sheet(isPresented: $showingChannelInfo) {
            ChannelInfoSheet(community: community, channel: channel)
        }
        .alert("Delete Message", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                confirmDeleteMessage()
            }
            Button("Cancel", role: .cancel) {
                cancelDeleteMessage()
            }
        } message: {
            Text("Are you sure you want to delete this message? This action cannot be undone.")
        }
    }
}

// MARK: - Channel Header
extension ChannelChatView {
    private var channelHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Back Button
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text(community.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Channel Info
                Button(action: { showingChannelInfo = true }) {
                    HStack(spacing: 8) {
                        // Channel Icon
                        ZStack {
                            Circle()
                                .fill(channelColor.opacity(0.15))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: channelIcon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(channelColor)
                        }
                        
                        // Channel Name & Details
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("#\(channel.name)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                if channel.adminOnly {
                                    Text("ADMIN")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.orange)
                                        .cornerRadius(4)
                                }
                            }
                            
                            if viewModel.messages.count > 0 {
                                Text("\(viewModel.messages.count) messages")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var channelColor: Color {
        switch channel.type {
        case .text: return .blue
        case .callouts: return .orange
        case .voice: return .green
        }
    }
    
    private var channelIcon: String {
        switch channel.type {
        case .text: return "number"
        case .callouts: return "megaphone.fill"
        case .voice: return "speaker.wave.2.fill"
        }
    }
}

// MARK: - Messages Scroll View with Firebase Reactions
extension ChannelChatView {
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        emptyChannelState
                    } else {
                        ForEach(viewModel.messages) { message in
                            FirebaseMessageRowWithReactions(
                                message: message,
                                showUsername: shouldShowUsername(message),
                                isUserMessage: message.authorId == viewModel.currentUserId,
                                canEdit: canEditMessage(message),
                                canDelete: canDeleteMessage(message),
                                reactionGroups: viewModel.getGroupedReactions(for: message.id),
                                onReply: { replyingTo = message },
                                onEdit: { startEditingMessage(message) },
                                onDelete: { requestDeleteMessage(message) },
                                onReact: { emoji in
                                    viewModel.addReaction(to: message.id, emoji: emoji)
                                },
                                onShowEmojiPicker: {
                                    selectedMessage = message
                                    showEmojiPicker = true
                                }
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
            .onTapGesture {
                // Dismiss emoji picker when tapping outside
                if showEmojiPicker {
                    showEmojiPicker = false
                    selectedMessage = nil
                }
                isMessageFieldFocused = false
            }
        }
    }
    
    private var emptyChannelState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(channelColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: channelIcon)
                    .font(.system(size: 32))
                    .foregroundColor(channelColor)
            }
            
            VStack(spacing: 8) {
                Text("Welcome to #\(channel.name)!")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(channelDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .padding(.top, 80)
    }
    
    private var channelDescription: String {
        switch channel.type {
        case .text:
            return "This is the start of the #\(channel.name) channel."
        case .callouts:
            return "Trading callouts and signals will be posted here by admins."
        case .voice:
            return "Join the voice channel to chat with other members."
        }
    }
}

// MARK: - Firebase-Powered Emoji Picker
extension ChannelChatView {
    private var firebaseEmojiPicker: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showEmojiPicker = false
                    selectedMessage = nil
                }
            
            VStack {
                Spacer()
                
                // Enhanced Emoji Picker Card
                VStack(spacing: 0) {
                    // Handle bar
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    // Header
                    HStack {
                        Text(selectedMessage != nil ? "React to message" : "Add emoji")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Done") {
                            showEmojiPicker = false
                            selectedMessage = nil
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Trading Emojis Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("📈 Trading")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                                    ForEach(tradingEmojis, id: \.self) { emoji in
                                        emojiButton(emoji)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            // Popular Reactions Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("😊 Popular")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                                    ForEach(popularEmojis, id: \.self) { emoji in
                                        emojiButton(emoji)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            // All Emojis Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("🎉 All Reactions")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                                    ForEach(allEmojis, id: \.self) { emoji in
                                        emojiButton(emoji, size: 36)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                    .frame(height: 400)
                }
                .background(Color(.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showEmojiPicker)
    }
    
    private func emojiButton(_ emoji: String, size: CGFloat = 44) -> some View {
        Button(action: {
            handleEmojiSelection(emoji)
        }) {
            Text(emoji)
                .font(.title2)
                .frame(width: size, height: size)
                .background(Color(.systemGray6))
                .cornerRadius(size/2)
                .scaleEffect(1.0)
        }
        .buttonStyle(EmojiButtonStyle())
    }
    
    // Emoji categories
    private var tradingEmojis: [String] {
        return ["📈", "📉", "🚀", "💎", "🐂", "🐻", "💰", "🤑", "💯", "🔥", "⭐", "🎯"]
    }
    
    private var popularEmojis: [String] {
        return ["👍", "❤️", "😂", "😮", "😢", "😡", "👎", "🎉", "👏", "🙌", "💪", "🤔"]
    }
    
    private var allEmojis: [String] {
        return ["😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊",
                "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "😋", "😛", "😜", "🤪",
                "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶", "😏",
                "😒", "🙄", "😬", "🤥", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢"]
    }
    
    private func handleEmojiSelection(_ emoji: String) {
        if let message = selectedMessage {
            // Add reaction to specific message using Firebase
            viewModel.addReaction(to: message.id, emoji: emoji)
        } else {
            // Add emoji to message input
            if editingMessage != nil {
                editedContent += emoji
            } else {
                messageText += emoji
            }
        }
        
        // Close emoji picker
        showEmojiPicker = false
        selectedMessage = nil
    }
}

// MARK: - Message Input
extension ChannelChatView {
    private var messageInputSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Attachment Button
                Button(action: {
                    // TODO: Implement file attachment
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.canUserPost ? .blue : .gray)
                }
                .disabled(!viewModel.canUserPost)
                
                // Message Input Field
                HStack {
                    TextField(inputPlaceholder, text: inputBinding, axis: .vertical)
                        .focused($isMessageFieldFocused)
                        .lineLimit(1...5)
                        .disabled(!viewModel.canUserPost)
                        .onSubmit {
                            if editingMessage != nil {
                                saveEditedMessage()
                            } else if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                sendMessage()
                            }
                        }
                    
                    // Emoji Button for Input
                    Button(action: {
                        selectedMessage = nil
                        showEmojiPicker.toggle()
                        isMessageFieldFocused = false
                    }) {
                        Image(systemName: "face.smiling.fill")
                            .font(.title3)
                            .foregroundColor(showEmojiPicker ? .blue : .gray)
                    }
                    .disabled(!viewModel.canUserPost)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                
                // Send/Save Button
                Button(action: {
                    if editingMessage != nil {
                        saveEditedMessage()
                    } else {
                        sendMessage()
                    }
                }) {
                    Image(systemName: editingMessage != nil ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSendMessage ? .blue : .gray)
                }
                .disabled(!canSendMessage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    private var inputBinding: Binding<String> {
        if editingMessage != nil {
            return $editedContent
        } else {
            return $messageText
        }
    }
    
    private var inputPlaceholder: String {
        if editingMessage != nil {
            return "Edit your message..."
        } else if !viewModel.canUserPost {
            return "You don't have permission to send messages"
        } else {
            return "Message #\(channel.name)..."
        }
    }
    
    private var canSendMessage: Bool {
        if editingMessage != nil {
            return !editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return viewModel.canUserPost && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        let finalMessage = replyingTo != nil ? "@\(replyingTo!.authorUsername) \(trimmedMessage)" : trimmedMessage
        
        viewModel.sendMessage(content: finalMessage)
        messageText = ""
        replyingTo = nil
    }
}

// MARK: - Firebase Message Row with Real-time Reactions
struct FirebaseMessageRowWithReactions: View {
    let message: CommunityMessage
    let showUsername: Bool
    let isUserMessage: Bool
    let canEdit: Bool
    let canDelete: Bool
    let reactionGroups: [EmojiReactionGroup]
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onReact: (String) -> Void
    let onShowEmojiPicker: () -> Void
    
    @State private var showingActions = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User Avatar
            if showUsername {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [userColor, userColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(userInitials)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .shadow(color: userColor.opacity(0.3), radius: 4, x: 0, y: 2)
            } else {
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(showingActions ? 1.0 : 0.0)
                    .frame(width: 40, alignment: .center)
                    .animation(.easeInOut(duration: 0.2), value: showingActions)
            }
            
            // Message Content
            VStack(alignment: .leading, spacing: 8) {
                // Username and timestamp
                if showUsername {
                    HStack(spacing: 8) {
                        Text(message.authorUsername)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(userColor)
                        
                        Text(formatTimestamp(message.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Message bubble
                HStack {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isUserMessage ? Color.blue.opacity(0.1) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isUserMessage ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    
                    Spacer()
                }
                
                // Firebase Real-time Reactions Display
                if !reactionGroups.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(reactionGroups) { reactionGroup in
                            Button(action: {
                                onReact(reactionGroup.emoji)
                            }) {
                                HStack(spacing: 4) {
                                    Text(reactionGroup.emoji)
                                        .font(.subheadline)
                                    
                                    if reactionGroup.count > 1 {
                                        Text("\(reactionGroup.count)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(reactionGroup.hasUserReacted ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(reactionGroup.hasUserReacted ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                                .scaleEffect(reactionGroup.hasUserReacted ? 1.05 : 1.0)
                                .animation(.spring(response: 0.3), value: reactionGroup.hasUserReacted)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Text(reactionGroup.displayText)
                            }
                        }
                        
                        // Add reaction button
                        Button(action: onShowEmojiPicker) {
                            Image(systemName: "plus.circle")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.leading, 12)
                }
                
                // Message actions
                if showingActions {
                    HStack(spacing: 16) {
                        Button("Reply", action: onReply)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        if canEdit {
                            Button("Edit", action: onEdit)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        if canDelete {
                            Button("Delete", action: onDelete)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: onShowEmojiPicker) {
                            HStack(spacing: 4) {
                                Image(systemName: "face.smiling")
                                    .font(.caption)
                                Text("React")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                    .padding(.leading, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            Spacer()
        }
        .padding(.vertical, showUsername ? 12 : 2)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingActions.toggle()
            }
        }
    }
    
    private var userColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red]
        let index = abs(message.authorUsername.hashValue) % colors.count
        return colors[index]
    }
    
    private var userInitials: String {
        let name = message.authorUsername
        if name.count >= 2 {
            return String(name.prefix(2)).uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Reply and Edit Banners
extension ChannelChatView {
    private func replyBanner(to message: CommunityMessage) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("Replying to \(message.authorUsername)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Text(message.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: { replyingTo = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
        .overlay(
            Rectangle()
                .fill(Color.blue)
                .frame(width: 3)
                .frame(maxHeight: .infinity),
            alignment: .leading
        )
    }
    
    private var editBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Editing message")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                
                if let editingMessage = editingMessage {
                    Text(editingMessage.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Save") {
                    saveEditedMessage()
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .disabled(editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button("Cancel") {
                    cancelEditing()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.05))
        .overlay(
            Rectangle()
                .fill(Color.orange)
                .frame(width: 3)
                .frame(maxHeight: .infinity),
            alignment: .leading
        )
    }
}

// MARK: - Message Management
extension ChannelChatView {
    private func canEditMessage(_ message: CommunityMessage) -> Bool {
        guard let currentUserId = viewModel.currentUserId else { return false }
        guard message.authorId == currentUserId else { return false }
        
        let editTimeLimit: TimeInterval = 5 * 60 // 5 minutes
        let timeSinceCreated = Date().timeIntervalSince(message.createdAt)
        return timeSinceCreated <= editTimeLimit
    }
    
    private func canDeleteMessage(_ message: CommunityMessage) -> Bool {
        guard let currentUserId = viewModel.currentUserId else { return false }
        return (message.authorId == currentUserId) || viewModel.canUserManageChannel
    }
    
    private func startEditingMessage(_ message: CommunityMessage) {
        guard canEditMessage(message) else { return }
        editingMessage = message
        editedContent = message.content
    }
    
    private func saveEditedMessage() {
        guard let editingMessage = editingMessage else { return }
        
        let trimmedContent = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
