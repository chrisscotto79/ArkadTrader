// File: Core/Communities/Views/Detail/ChannelChatView+Composer.swift
// Channel chat composer: text input, @mentions, reply/edit banners and message actions.

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FirebaseStorage
import Photos
import MobileCoreServices

// MARK: - Enhanced Message Input Extension
extension ChannelChatView {
    var enhancedMessageInput: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // New trade callout (callout channels, admins only)
                if channel.type == .callouts && viewModel.canUserPost {
                    Button(action: { showCreateCallout = true }) {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.arkadGold))
                    }
                    .accessibilityLabel("New trade callout")
                }
                
                // Attachment Button with Media Options
                Button(action: {
                    showingMediaOptions = true
                }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.canUserPost ? Color.arkadGold : Color.gray)
                            .frame(width: 32, height: 32)
                        
                        if isUploadingMedia {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                }
                .disabled(!viewModel.canUserPost || isUploadingMedia)
                
                // Message Input Field with Upload Status
                HStack {
                    if isUploadingMedia {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                            
                            Text("Uploading...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    } else {
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
                    }
                    
                    // Emoji Button for Input (hidden during upload)
                    if !isUploadingMedia {
                        Button(action: {
                            emojiPickerForMessage = nil
                            showEmojiPicker.toggle()
                            isMessageFieldFocused = false
                        }) {
                            Image(systemName: "face.smiling.fill")
                                .font(.title3)
                                .foregroundColor(showEmojiPicker ? .accentColor : .gray)
                        }
                        .disabled(!viewModel.canUserPost)
                    }
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
                        .foregroundColor(canSendMessage ? .accentColor : .gray)
                }
                .disabled(!canSendMessage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    var inputBinding: Binding<String> {
        if editingMessage != nil {
            return $editedContent
        } else {
            return $messageText
        }
    }
    
    var inputPlaceholder: String {
        if editingMessage != nil {
            return "Edit your message..."
        } else if !viewModel.canUserPost {
            return "You don't have permission to send messages"
        } else {
            return "Message #\(channel.name)..."
        }
    }
    
    var canSendMessage: Bool {
        if editingMessage != nil {
            return !editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return viewModel.canUserPost && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        let finalMessage = replyingTo != nil ? "@\(replyingTo!.authorUsername) \(trimmedMessage)" : trimmedMessage
        
        // Stop typing indicator
        stopTyping()
        
        viewModel.sendMessage(content: finalMessage)
        messageText = ""
        replyingTo = nil
    }
    
    // MARK: - @Mentions Detection
    func detectMentions() {
        // Find @ symbol and check for mention
        if let atIndex = messageText.lastIndex(of: "@") {
            let startIndex = messageText.index(after: atIndex)
            let query = String(messageText[startIndex...])
            
            // Only show suggestions if we have a partial username (no spaces)
            if !query.contains(" ") && query.count <= 20 {
                currentMentionQuery = query
                searchForMentionUsers(query: query)
                showingMentionSuggestions = true
            } else {
                hideMentionSuggestions()
            }
        } else {
            hideMentionSuggestions()
        }
    }
    
    func searchForMentionUsers(query: String) {
        // Filter cached users based on query
        let lowercaseQuery = query.lowercased()
        mentionSuggestions = Array(userCache.values).filter { user in
            user.username.lowercased().hasPrefix(lowercaseQuery) ||
            user.fullName.lowercased().contains(lowercaseQuery)
        }.sorted { $0.username < $1.username }
        
        // Add special mentions
        if query.isEmpty || "everyone".hasPrefix(lowercaseQuery) {
            // Create a special "everyone" user for @everyone mentions
            let everyoneUser = createSpecialMentionUser(username: "everyone", fullName: "Everyone")
            mentionSuggestions.insert(everyoneUser, at: 0)
        }
        
        if query.isEmpty || "admin".hasPrefix(lowercaseQuery) {
            let adminUser = createSpecialMentionUser(username: "admin", fullName: "All Admins")
            mentionSuggestions.insert(adminUser, at: 0)
        }
    }
    
    func createSpecialMentionUser(username: String, fullName: String) -> User {
        return User(id: username, email: "", username: username, fullName: fullName)
    }
    
    func hideMentionSuggestions() {
        showingMentionSuggestions = false
        mentionSuggestions = []
        currentMentionQuery = ""
    }
    
    func insertMention(_ user: User) {
        // Replace the current @query with @username
        if let atIndex = messageText.lastIndex(of: "@") {
            let beforeAt = String(messageText[..<atIndex])
            messageText = beforeAt + "@\(user.username) "
        }
        hideMentionSuggestions()
    }
}

// MARK: - Reply and Edit Banners Extension
extension ChannelChatView {
    func replyBanner(to message: CommunityMessage) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    
                    Text("Replying to \(message.authorUsername)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
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
        .background(Color.accentColor.opacity(0.05))
        .overlay(
            Rectangle()
                .fill(Color.arkadGold)
                .frame(width: 3)
                .frame(maxHeight: .infinity),
            alignment: .leading
        )
    }
    
    var editBanner: some View {
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
                .foregroundColor(.accentColor)
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

// MARK: - Message Management Extension
extension ChannelChatView {
    func startEditingMessage(_ message: CommunityMessage) {
        guard viewModel.canEditMessage(message) else { return }
        editingMessage = message
        editedContent = message.content
    }
    
    func saveEditedMessage() {
        guard let editingMessage = editingMessage else { return }
        
        let trimmedContent = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        // Update locally (you can add Firebase integration later)
        if let index = viewModel.messages.firstIndex(where: { $0.id == editingMessage.id }) {
            viewModel.messages[index].content = trimmedContent + " (edited)"
        }
        
        cancelEditing()
    }
    
    func cancelEditing() {
        editingMessage = nil
        editedContent = ""
    }
    
    func requestDeleteMessage(_ message: CommunityMessage) {
        guard viewModel.canDeleteMessage(message) else { return }
        messageToDelete = message
        showDeleteConfirmation = true
    }
    
    func confirmDeleteMessage() {
        guard let messageToDelete = messageToDelete else { return }
        
        // Remove from local array (you can add Firebase integration later)
        viewModel.messages.removeAll { $0.id == messageToDelete.id }
        
        self.messageToDelete = nil
        showDeleteConfirmation = false
    }
    
    func cancelDeleteMessage() {
        messageToDelete = nil
        showDeleteConfirmation = false
    }
}
