// File: Core/Communities/Views/Detail/ChannelChatView+Composer.swift
// Channel chat composer: capsule text field with attachment, callout and send buttons,
// @mentions, reply/edit banners and message actions.

import SwiftUI
import UIKit

// MARK: - Composer
extension ChannelChatView {
    var enhancedMessageInput: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.hairline).frame(height: 1)

            Group {
                if viewModel.canUserPost || editingMessage != nil {
                    composerRow
                } else {
                    readOnlyNotice
                }
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.s)
        }
        .background(Color.surface.ignoresSafeArea(edges: .bottom))
    }

    private var composerRow: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.s) {
            if editingMessage == nil {
                attachmentMenu

                // New trade callout (callout channels, people who can post there)
                if channel.type == .callouts && viewModel.canUserPost {
                    Button(action: { showCreateCallout = true }) {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.onGold)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.arkadGold))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("New trade callout")
                }
            }

            inputField

            sendButton
        }
    }

    private var attachmentMenu: some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                }
            }
            Button {
                showingImagePicker = true
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }
            Button {
                showingDocumentPicker = true
            } label: {
                Label("Document", systemImage: "doc")
            }
        } label: {
            ZStack {
                Circle().fill(Color.surfaceRaised)
                if isUploadingMedia {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
            }
            .frame(width: 36, height: 36)
        }
        .disabled(isUploadingMedia)
        .accessibilityLabel("Attach a photo or file")
    }

    private var inputField: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.s) {
            if isUploadingMedia {
                HStack(spacing: DS.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Uploading…")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(inputPlaceholder, text: inputBinding, axis: .vertical)
                    .focused($isMessageFieldFocused)
                    .lineLimit(1...5)
                    .font(.body)
                    .onSubmit {
                        if editingMessage != nil {
                            saveEditedMessage()
                        } else if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            sendMessage()
                        }
                    }

                Button(action: {
                    emojiPickerForMessage = nil
                    showEmojiPicker.toggle()
                    isMessageFieldFocused = false
                }) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 19))
                        .foregroundStyle(showEmojiPicker ? Color.goldText : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Emoji")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 36)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.surfaceRaised)
        )
    }

    private var sendButton: some View {
        Button(action: {
            if editingMessage != nil {
                saveEditedMessage()
            } else {
                sendMessage()
            }
        }) {
            Image(systemName: editingMessage != nil ? "checkmark" : "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(canSendMessage ? Color.onGold : Color.secondary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(canSendMessage ? Color.arkadGold : Color.surfaceRaised))
        }
        .buttonStyle(PressableStyle())
        .disabled(!canSendMessage)
        .animation(.snappy(duration: 0.18), value: canSendMessage)
        .accessibilityLabel(editingMessage != nil ? "Save edit" : "Send")
    }

    private var readOnlyNotice: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: "lock.fill")
                .font(.footnote)
            Text("Only owners and admins can post in #\(channel.name)")
                .font(.footnote)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 36)
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
            return "Edit your message"
        } else if !viewModel.canUserPost {
            return "You don't have permission to send messages"
        } else {
            return "Message #\(channel.name)"
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

        let finalMessage = replyingTo.map { "@\($0.authorUsername) \(trimmedMessage)" } ?? trimmedMessage

        stopTyping()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        viewModel.sendMessage(content: finalMessage)
        messageText = ""
        replyingTo = nil
    }

    // MARK: - @Mentions Detection
    func detectMentions() {
        if let atIndex = messageText.lastIndex(of: "@") {
            let startIndex = messageText.index(after: atIndex)
            let query = String(messageText[startIndex...])

            // Only show suggestions while typing a partial username (no spaces)
            if !query.contains(" ") && query.count <= 20 {
                currentMentionQuery = query
                searchForMentionUsers(query: query)
                showingMentionSuggestions = !mentionSuggestions.isEmpty
            } else {
                hideMentionSuggestions()
            }
        } else {
            hideMentionSuggestions()
        }
    }

    func searchForMentionUsers(query: String) {
        let lowercaseQuery = query.lowercased()
        mentionSuggestions = Array(userCache.values).filter { user in
            user.username.lowercased().hasPrefix(lowercaseQuery) ||
            user.fullName.lowercased().contains(lowercaseQuery)
        }.sorted { $0.username < $1.username }
    }

    func hideMentionSuggestions() {
        showingMentionSuggestions = false
        mentionSuggestions = []
        currentMentionQuery = ""
    }

    func insertMention(_ user: User) {
        if let atIndex = messageText.lastIndex(of: "@") {
            let beforeAt = String(messageText[..<atIndex])
            messageText = beforeAt + "@\(user.username) "
        }
        hideMentionSuggestions()
    }
}

// MARK: - Reply and Edit Banners
extension ChannelChatView {
    func replyBanner(to message: CommunityMessage) -> some View {
        composerBanner(
            icon: "arrowshape.turn.up.left.fill",
            title: "Replying to \(message.authorUsername)",
            preview: previewText(for: message),
            onClose: { replyingTo = nil }
        )
    }

    var editBanner: some View {
        composerBanner(
            icon: "pencil",
            title: "Editing message",
            preview: editingMessage.map { previewText(for: $0) } ?? "",
            onClose: cancelEditing
        )
    }

    private func composerBanner(icon: String, title: String, preview: String, onClose: @escaping () -> Void) -> some View {
        HStack(spacing: DS.Spacing.m) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.arkadGold)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.goldText)
                    .lineLimit(1)
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.s)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.s)
        .background(Color.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
    }
}

// MARK: - Message Management
extension ChannelChatView {
    func startEditingMessage(_ message: CommunityMessage) {
        guard viewModel.canEditMessage(message) else { return }
        replyingTo = nil
        editingMessage = message
        editedContent = message.content
        isMessageFieldFocused = true
    }

    func saveEditedMessage() {
        guard let editingMessage = editingMessage else { return }

        let trimmedContent = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        // Updated locally only for now (no Firestore write yet)
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

        // Removed locally only for now (no Firestore write yet)
        viewModel.messages.removeAll { $0.id == messageToDelete.id }

        self.messageToDelete = nil
        showDeleteConfirmation = false
    }

    func cancelDeleteMessage() {
        messageToDelete = nil
        showDeleteConfirmation = false
    }
}
