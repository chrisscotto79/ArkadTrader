// File: Core/Communities/Views/Detail/ChannelChatView.swift
// A community channel's chat: header, message list, typing indicator and mentions overlay.
// The composer and attachments live in ChannelChatView+Composer.swift and ChannelChatView+Media.swift.

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FirebaseStorage
import Photos
import MobileCoreServices


// MARK: - @Mentions Overlay Extension
extension ChannelChatView {
    var mentionSuggestionsOverlay: some View {
        VStack {
            Spacer()
            
            // Mention suggestions appear above message input
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Mention someone")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        hideMentionSuggestions()
                    }
                    .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                Divider()
                
                // User suggestions
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(mentionSuggestions.prefix(8), id: \.id) { user in
                            MentionSuggestionRow(
                                user: user,
                                onTap: {
                                    insertMention(user)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16, corners: [.topLeft, .topRight])
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingMentionSuggestions)
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    hideMentionSuggestions()
                }
        )
    }
}


// MARK: - Smart Chat Features Extensions
extension ChannelChatView {
    
    // MARK: - Typing Indicator View
    var typingIndicatorView: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Array(viewModel.typingUsernames.prefix(3)), id: \.self) { name in
                    Text(name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                
                if viewModel.typingUsernames.count > 3 {
                    Text("and \(viewModel.typingUsernames.count - 3) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(viewModel.typingUsernames.count == 1 ? "is typing" : "are typing")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Animated typing dots
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 4, height: 4)
                        .scaleEffect(animatingDot == index ? 1.2 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animatingDot
                        )
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .onAppear {
            startTypingAnimation()
        }
    }
    
    
    func startTypingAnimation() {
        typingAnimationTimer?.invalidate() // Clean up any existing timer
        typingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animatingDot = (animatingDot + 1) % 3
            }
        }
    }
    
    // MARK: - Typing Logic
    func handleTypingIndicator() {
        guard !messageText.isEmpty else {
            stopTyping()
            return
        }
        
        let now = Date()
        lastTypingTime = now
        
        // Send typing indicator (you can implement Firebase real-time typing here)
        sendTypingIndicator(isTyping: true)
        
        // Stop typing after 3 seconds of inactivity
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            stopTyping()
        }
    }
    
    func stopTyping() {
        sendTypingIndicator(isTyping: false)
        typingTimer?.invalidate()
    }
    
    func sendTypingIndicator(isTyping: Bool) {
        viewModel.setTyping(isTyping)
    }

}


// MARK: - Main ChannelChatView
struct ChannelChatView: View {
    let community: Community
        let channel: Channel
        
        @Environment(\.dismiss) var dismiss
        @StateObject var viewModel = ChannelChatViewModel()
        @EnvironmentObject var authService: FirebaseAuthService

        // Message input and UI state
        @State var messageText = ""
        @State var showingChannelInfo = false
        @State var selectedMessage: CommunityMessage?
        @State var replyingTo: CommunityMessage?
        @State var editingMessage: CommunityMessage?
        @State var editedContent = ""
        @State var showDeleteConfirmation = false
        @State var messageToDelete: CommunityMessage?
        @State var showEmojiPicker = false
        @State var emojiPickerForMessage: CommunityMessage?
        @FocusState var isMessageFieldFocused: Bool
        
        // Smart Chat Features
        @State var lastTypingTime: Date = Date()
        @State var typingTimer: Timer?
        @State var showingMessageSearch = false
        @State var searchText = ""
        @State var searchResults: [CommunityMessage] = []
        /// Message picked in search, held until the search sheet finishes closing
        @State var searchSelectionId: String?
        /// Message the list should scroll to
        @State var scrollTargetMessageId: String?
        /// Message briefly highlighted after jumping to it from search
        @State var highlightedMessageId: String?
        
        // Animation and Timer properties
        @State var animatingDot = 0
        @State var typingAnimationTimer: Timer? // ADD THIS LINE
        
        // @Mentions & Notifications
        @State var mentionSuggestions: [User] = []
        @State var showingMentionSuggestions = false
        @State var currentMentionQuery = ""
        @State var mentionRange: Range<String.Index>?
        
        // Media sharing state
        @State var showingImagePicker = false
        @State var showingCamera = false
        @State var showingDocumentPicker = false
        @State var showingMediaOptions = false
        @State var showCreateCallout = false
        @State var calloutToTrack: CommunityMessage?
        @State var selectedImage: UIImage?
        @State var selectedDocumentURL: URL?
        @State var isUploadingMedia = false
        @State var uploadErrorMessage: String?
        
        // Profile functionality
        @State var selectedUserForProfile: User?
        @State var showUserProfile = false
        @State var userCache: [String: User] = [:]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Enhanced Channel Header
                channelHeader
                
                // Messages List
                messagesScrollView
                
                // NEW: Typing Indicators
                if !viewModel.typingUsernames.isEmpty {
                    typingIndicatorView
                }
                
                // Reply Banner (if replying)
                if let replyingTo = replyingTo {
                    replyBanner(to: replyingTo)
                }
                
                // Edit Banner (if editing)
                if editingMessage != nil {
                    editBanner
                }
                
                // Message Input with Emoji Support
                enhancedMessageInput
            }
            
            // Emoji Picker Overlay
            if showEmojiPicker {
                emojiPickerOverlay
            }
            
            // NEW: Mention Suggestions Overlay
            if showingMentionSuggestions {
                mentionSuggestionsOverlay
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .sheet(isPresented: $showUserProfile) {
            if let user = selectedUserForProfile {
                UserProfileSheet(user: user, community: community, onBlocked: { blockedId in
                    viewModel.hideMessages(from: blockedId)
                })
                .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showCreateCallout) {
            CreateCalloutSheet(channelName: channel.name) { callout in
                viewModel.sendCallout(callout)
            }
        }
        .sheet(item: $calloutToTrack) { message in
            if let callout = message.callout {
                TrackCalloutSheet(callout: callout, communityName: community.name) { entry, quantity in
                    try await viewModel.trackCallout(callout, entryPrice: entry, quantity: quantity)
                }
            }
        }
        .sheet(isPresented: $showingChannelInfo) {
            ChannelInfoSheet(community: community, channel: channel)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(selectedURL: $selectedDocumentURL)
        }
        .sheet(isPresented: $showingMessageSearch, onDismiss: {
            // Scroll after the sheet has gone so the jump is visible
            if let target = searchSelectionId {
                searchSelectionId = nil
                scrollTargetMessageId = target
            }
        }) {
            MessageSearchSheet(
                messages: viewModel.messages,
                userCache: userCache,
                searchText: $searchText,
                searchResults: $searchResults,
                onMessageSelected: { message in
                    searchSelectionId = message.id
                    showingMessageSearch = false
                }
            )
        }
        .confirmationDialog("Share Media", isPresented: $showingMediaOptions) {
            Button("📷 Camera") {
                showingCamera = true
            }
            Button("🖼️ Photo Library") {
                showingImagePicker = true
            }
            Button("📄 Document") {
                showingDocumentPicker = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose what you'd like to share")
        }
        .alert(
            "Upload failed",
            isPresented: Binding(get: { uploadErrorMessage != nil }, set: { if !$0 { uploadErrorMessage = nil } })
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(uploadErrorMessage ?? "")
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
        .onAppear {
            print("🗨️ ChannelChatView appeared for #\(channel.name)")
            viewModel.loadChannelData(community: community, channel: channel)
            loadUsersForMessages()
        }
        .onDisappear {
            viewModel.cleanup()
            typingAnimationTimer?.invalidate() // This should now work
            typingTimer?.invalidate() // Also clean up the typing timer
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                handleImageUpload(image)
            }
        }
        .onChange(of: selectedDocumentURL) { oldValue, newValue in
            if let url = newValue {
                handleDocumentUpload(url)
            }
        }
        .onChange(of: messageText) {
            handleTypingIndicator()
            detectMentions()
        }
    }
}

// MARK: - Enhanced Channel Header Extension
extension ChannelChatView {
    var channelHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Back Button with improved design
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text(community.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Enhanced Channel Info
                Button(action: { showingChannelInfo = true }) {
                    HStack(spacing: 8) {
                        // Channel Icon with better styling
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
                        
                        // NEW: Search Button
                        Button(action: { showingMessageSearch = true }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
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
    
    var channelColor: Color {
        switch channel.type {
        case .text, .voice: return .blue
        case .callouts: return .orange
        }
    }
    
    var channelIcon: String {
        switch channel.type {
        case .text, .voice: return "number"
        case .callouts: return "megaphone.fill"
        }
    }
}

// MARK: - Enhanced Messages View Extension
extension ChannelChatView {
    var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        emptyChannelState
                    } else {
                        ForEach(viewModel.messages) { message in
                            EnhancedMessageRowWithReactions(
                                message: message,
                                author: userCache[message.authorId],
                                authorRole: viewModel.role(for: message.authorId),
                                community: community,
                                showUsername: shouldShowUsername(message),
                                isUserMessage: message.authorId == viewModel.currentUserId,
                                canEdit: viewModel.canEditMessage(message),
                                canDelete: viewModel.canDeleteMessage(message),
                                reactions: viewModel.getGroupedReactions(for: message.id),
                                onReply: { replyingTo = message },
                                onEdit: { startEditingMessage(message) },
                                onDelete: { requestDeleteMessage(message) },
                                onReact: { emoji in
                                    viewModel.addReaction(to: message.id, emoji: emoji)
                                },
                                onShowEmojiPicker: {
                                    emojiPickerForMessage = message
                                    showEmojiPicker = true
                                },
                                onProfileTap: { user in
                                    selectedUserForProfile = user
                                    showUserProfile = true
                                },
                                currentUserId: authService.currentUser?.id ?? "",
                                currentUsername: authService.currentUser?.username ?? "",
                                canManageCallout: viewModel.canManageCallout(message),
                                onTrackCallout: { calloutToTrack = message },
                                onUpdateCalloutStatus: { status in
                                    viewModel.updateCalloutStatus(message, to: status)
                                }
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.arkadGold.opacity(highlightedMessageId == message.id ? 0.18 : 0))
                                    .padding(.horizontal, -8)
                            )
                            .animation(.easeInOut(duration: 0.3), value: highlightedMessageId)
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .onChange(of: viewModel.messages.count) {
                // Auto-scroll to bottom when new message arrives
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
                // Load users for any new messages
                loadUsersForNewMessages()
            }
            .onChange(of: scrollTargetMessageId) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(target, anchor: .center)
                }
                highlightedMessageId = target
                scrollTargetMessageId = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    if highlightedMessageId == target {
                        highlightedMessageId = nil
                    }
                }
            }
            .onTapGesture {
                // Dismiss emoji picker when tapping outside
                if showEmojiPicker {
                    showEmojiPicker = false
                    emojiPickerForMessage = nil
                }
                isMessageFieldFocused = false
            }
        }
    }
    
    var emptyChannelState: some View {
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
    
    var channelDescription: String {
        switch channel.type {
        case .text, .voice:
            return "This is the start of the #\(channel.name) channel."
        case .callouts:
            return channel.adminOnly
                ? "Admins post trade callouts here. Use \"Track in Portfolio\" on a callout to add it to your trades."
                : "Post trade callouts here with the megaphone button. Use \"Track in Portfolio\" on a callout to add it to your trades."
        }
    }
}


// MARK: - User Loading and Caching Extension
extension ChannelChatView {
    func loadUsersForMessages() {
        let userIds = Set(viewModel.messages.map { $0.authorId })
        
        for userId in userIds {
            if userCache[userId] == nil {
                loadUser(userId: userId)
            }
        }
    }
    
    func loadUser(userId: String) {
        // Avoid loading the same user multiple times
        guard userCache[userId] == nil else { return }
        
        Task {
            do {
                print("🔄 Loading user data for: \(userId)")
                if let user = try await authService.getUserById(userId: userId) {
                    await MainActor.run {
                        userCache[userId] = user
                        print("✅ Loaded user: \(user.username) with profile image: \(user.profileImageUrl ?? "none")")
                    }
                } else {
                    print("⚠️ No user found for ID: \(userId)")
                }
            } catch {
                print("❌ Error loading user \(userId): \(error)")
            }
        }
    }
    
    func loadUsersForNewMessages() {
        let userIds = Set(viewModel.messages.map { $0.authorId })
        let cachedUserIds = Set(userCache.keys)
        let missingUserIds = userIds.subtracting(cachedUserIds)
        
        for userId in missingUserIds {
            loadUser(userId: userId)
        }
    }
}


// MARK: - Helper Methods Extension
extension ChannelChatView {
    func shouldShowUsername(_ message: CommunityMessage) -> Bool {
        guard let messageIndex = viewModel.messages.firstIndex(where: { $0.id == message.id }) else {
            return true
        }
        
        if messageIndex == 0 {
            return true
        }
        
        let previousMessage = viewModel.messages[messageIndex - 1]
        let timeDifference = message.createdAt.timeIntervalSince(previousMessage.createdAt)
        
        return previousMessage.authorId != message.authorId || timeDifference > 300
    }
}

// MARK: - Supporting Components


#Preview {
    let testCommunity = Community(
        name: "Elite Traders",
        description: "Premium trading community",
        type: .dayTrading,
        creatorId: "test-user",
        memberCount: 156,
        isPrivate: false
    )
    
    let testChannel = Channel(
        name: "general",
        type: .text,
        communityId: testCommunity.id,
        isDefault: true,
        adminOnly: false
    )
    
    NavigationView {
        ChannelChatView(community: testCommunity, channel: testChannel)
    }
    .environmentObject(FirebaseAuthService.shared)
}
