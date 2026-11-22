// File: Core/Communities/Views/Detail/ChannelChatView.swift
// ENHANCED VERSION - Clickable Profile Images & User Profiles with Clean UI & Media Sharing

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FirebaseStorage
import Photos
import MobileCoreServices

// MARK: - Media Content Structure (File Level)
struct MediaContent {
    let type: MediaType
    let url: String
    let fileName: String
    let fileSize: Int?
    
    enum MediaType {
        case image, document, video
    }
}

// MARK: - @Mentions Overlay Extension
extension ChannelChatView {
    private var mentionSuggestionsOverlay: some View {
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
                    .foregroundColor(.blue)
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

// MARK: - Mention Suggestion Row
struct MentionSuggestionRow: View {
    let user: User
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile image or special icon
                Group {
                    if user.id == "everyone" {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "person.3.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                            )
                    } else if user.id == "admin" {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "star.fill")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                            )
                    } else if let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                        AsyncImage(url: URL(string: profileImageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .overlay(
                                    Text(user.fullName.prefix(1))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                )
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(user.fullName.prefix(1))
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            )
                    }
                }
                
                // User info
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Special mention indicators
                if user.id == "everyone" {
                    Text("Notifies all members")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                } else if user.id == "admin" {
                    Text("Notifies admins")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
        )
    }
}

// MARK: - Smart Chat Features Extensions
extension ChannelChatView {
    
    // MARK: - Typing Indicator View
    private var typingIndicatorView: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Array(typingUsers.prefix(3)), id: \.self) { userId in
                    if let user = userCache[userId] {
                        Text(user.username)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if typingUsers.count > 3 {
                    Text("and \(typingUsers.count - 3) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(typingUsers.count == 1 ? "is typing" : "are typing")
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
    
    
    private func startTypingAnimation() {
        typingAnimationTimer?.invalidate() // Clean up any existing timer
        typingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animatingDot = (animatingDot + 1) % 3
            }
        }
    }
    
    // MARK: - Typing Logic
    private func handleTypingIndicator() {
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
    
    private func stopTyping() {
        sendTypingIndicator(isTyping: false)
        typingTimer?.invalidate()
    }
    
    private func sendTypingIndicator(isTyping: Bool) {
        // TODO: Implement Firebase real-time typing indicators
        // For now, simulate with local state
        if isTyping {
            // In real implementation, send to Firebase that current user is typing
            print("💬 \(authService.currentUser?.username ?? "User") is typing...")
        } else {
            // In real implementation, remove current user from typing list in Firebase
            print("💬 \(authService.currentUser?.username ?? "User") stopped typing")
        }
    }

    private func cleanupTypingIndicators() {
        // Remove users who haven't typed in 5+ seconds
        _ = Date().addingTimeInterval(-5)
        // In real implementation, clean up Firebase typing indicators based on timestamp
    }
}

// MARK: - Message Search Sheet
struct MessageSearchSheet: View {
    let messages: [CommunityMessage]
    let userCache: [String: User]
    @Binding var searchText: String
    @Binding var searchResults: [CommunityMessage]
    let onMessageSelected: (CommunityMessage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search messages...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                            searchResults = []
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                Divider()
                
                // Search Results
                if searchText.isEmpty {
                    // Recent messages or suggestions
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("Search Messages")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Find messages, mentions, and shared media")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                } else if searchResults.isEmpty {
                    // No results
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("No Results")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Try different keywords or check spelling")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                } else {
                    // Search Results List
                    List(searchResults) { message in
                        SearchMessageRow(
                            message: message,
                            author: userCache[message.authorId],
                            searchTerm: searchText,
                            onTap: {
                                onMessageSelected(message)
                            }
                        )
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        let query = searchText.lowercased()
        searchResults = messages.filter { message in
            // Search in message content
            message.content.lowercased().contains(query) ||
            // Search in author username
            message.authorUsername.lowercased().contains(query) ||
            // Search in author full name
            (userCache[message.authorId]?.fullName.lowercased().contains(query) ?? false)
        }
        .sorted { $0.createdAt > $1.createdAt } // Most recent first
    }
}

// MARK: - Search Message Row
struct SearchMessageRow: View {
    let message: CommunityMessage
    let author: User?
    let searchTerm: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Author and timestamp
                HStack {
                    // Profile image
                    Group {
                        if let author = author,
                           let profileImageUrl = author.profileImageUrl,
                           !profileImageUrl.isEmpty {
                            AsyncImage(url: URL(string: profileImageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .overlay(
                                        Text(author.fullName.prefix(1))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    )
                            }
                        } else {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .overlay(
                                    Text(message.authorUsername.prefix(1))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                )
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.authorUsername)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(formatTimestamp(message.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Message content with highlighted search term
                Text(highlightedMessageContent)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var highlightedMessageContent: AttributedString {
        var attributedString = AttributedString(message.content)
        
        // Highlight search term (simple version)
        if let range = attributedString.range(of: searchTerm, options: .caseInsensitive) {
            attributedString[range].backgroundColor = .yellow.opacity(0.3)
        }
        
        return attributedString
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Image Picker Component (File Level)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Document Picker Component (File Level)
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf, .plainText, .rtf, .spreadsheet, .presentation,
            .zip, .gzip, .image, .movie
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.selectedURL = url
            }
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

// MARK: - Main ChannelChatView
struct ChannelChatView: View {
    let community: Community
        let channel: Channel
        
        @Environment(\.dismiss) private var dismiss
        @StateObject private var viewModel = ChannelChatViewModel()
        @EnvironmentObject private var authService: FirebaseAuthService

        // Message input and UI state
        @State private var messageText = ""
        @State private var showingChannelInfo = false
        @State private var selectedMessage: CommunityMessage?
        @State private var replyingTo: CommunityMessage?
        @State private var editingMessage: CommunityMessage?
        @State private var editedContent = ""
        @State private var showDeleteConfirmation = false
        @State private var messageToDelete: CommunityMessage?
        @State private var showEmojiPicker = false
        @State private var emojiPickerForMessage: CommunityMessage?
        @FocusState private var isMessageFieldFocused: Bool
        
        // Smart Chat Features
        @State private var typingUsers: Set<String> = []
        @State private var lastTypingTime: Date = Date()
        @State private var typingTimer: Timer?
        @State private var readReceipts: [String: Set<String>] = [:] // messageId: [userIds who read it]
        @State private var showingMessageSearch = false
        @State private var searchText = ""
        @State private var searchResults: [CommunityMessage] = []
        
        // Animation and Timer properties
        @State private var animatingDot = 0
        @State private var typingAnimationTimer: Timer? // ADD THIS LINE
        
        // @Mentions & Notifications
        @State private var mentionSuggestions: [User] = []
        @State private var showingMentionSuggestions = false
        @State private var currentMentionQuery = ""
        @State private var mentionRange: Range<String.Index>?
        @State private var unreadMentions: Set<String> = [] // Message IDs with unread mentions
        
        // Media sharing state
        @State private var showingImagePicker = false
        @State private var showingCamera = false
        @State private var showingDocumentPicker = false
        @State private var showingMediaOptions = false
        @State private var selectedImage: UIImage?
        @State private var selectedDocumentURL: URL?
        @State private var isUploadingMedia = false
        
        // Profile functionality
        @State private var selectedUserForProfile: User?
        @State private var showUserProfile = false
        @State private var userCache: [String: User] = [:]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Enhanced Channel Header
                channelHeader
                
                // Messages List
                messagesScrollView
                
                // NEW: Typing Indicators
                if !typingUsers.isEmpty {
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
                UserProfileSheet(user: user, community: community)
                    .environmentObject(authService)
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
        .sheet(isPresented: $showingMessageSearch) {
            MessageSearchSheet(
                messages: viewModel.messages,
                userCache: userCache,
                searchText: $searchText,
                searchResults: $searchResults,
                onMessageSelected: { message in
                    showingMessageSearch = false
                    // TODO: Scroll to selected message
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
            
            // Demo: Simulate some users typing (remove in production)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                simulateTypingUsers()
            }
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
        .onReceive(Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()) { _ in
            cleanupTypingIndicators()
        }
    }
}

// MARK: - Enhanced Channel Header Extension
extension ChannelChatView {
    private var channelHeader: some View {
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
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
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

// MARK: - Enhanced Messages View Extension
extension ChannelChatView {
    private var messagesScrollView: some View {
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
                                readReceipts: readReceipts[message.id] ?? [],
                                currentUserId: authService.currentUser?.id ?? ""
                            )
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

// MARK: - Enhanced Message Row with Clickable Profile Images
struct EnhancedMessageRowWithReactions: View {
    let message: CommunityMessage
    let author: User?
    let community: Community
    let showUsername: Bool
    let isUserMessage: Bool
    let canEdit: Bool
    let canDelete: Bool
    let reactions: [EmojiReactionGroup]
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onReact: (String) -> Void
    let onShowEmojiPicker: () -> Void
    let onProfileTap: (User) -> Void
    let readReceipts: Set<String> // NEW: User IDs who have read this message
    let currentUserId: String // NEW: Current user ID
    
    @State private var showingActions = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // ENHANCED: Clickable Profile Image/Avatar
            if showUsername {
                profileImageView
            } else {
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(showingActions ? 1.0 : 0.0)
                    .frame(width: 40, alignment: .center)
                    .animation(.easeInOut(duration: 0.2), value: showingActions)
            }
            
            // Message Content
            VStack(alignment: .leading, spacing: 6) {
                // Username and timestamp
                if showUsername {
                    usernameAndTimestamp
                }
                
                // Enhanced Message Content with integrated reactions
                messageContent
                
                // Message actions (simplified)
                if showingActions {
                    messageActionsView
                }
            }
            
            Spacer(minLength: 50)
        }
        .padding(.vertical, showUsername ? 8 : 2)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingActions.toggle()
            }
        }
    }
    
    // MARK: - ENHANCED: Clickable Profile Image Component
    private var profileImageView: some View {
        Button(action: {
            if let author = author {
                onProfileTap(author)
            }
        }) {
            Group {
                if let author = author,
                   let profileImageUrl = author.profileImageUrl,
                   !profileImageUrl.isEmpty {
                    
                    AsyncImage(url: URL(string: profileImageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // Loading state with user color background
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [userColor.opacity(0.8), userColor.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.6)
                            )
                    }
                } else {
                    // Fallback to initials circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [userColor.opacity(0.8), userColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(userInitials)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
            .overlay(
                // Online status indicator (optional)
                shouldShowOnlineStatus ?
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: 16, y: 16) : nil
            )
        }
        .buttonStyle(ProfileImageButtonStyle())
    }
    
    private var usernameAndTimestamp: some View {
        HStack(spacing: 8) {
            // Username with role badges
            HStack(spacing: 6) {
                Text(message.authorUsername)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(userColor)
                
                // MOD/ADMIN Badge - ENHANCED with simplified role system!
                if let author = author {
                    if isUserOwner(author) {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .background(
                                Circle()
                                    .fill(.purple.opacity(0.15))
                                    .frame(width: 16, height: 16)
                            )
                    } else if isUserAdmin(author) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .background(
                                Circle()
                                    .fill(.orange.opacity(0.15))
                                    .frame(width: 16, height: 16)
                            )
                    } else if isUserModerator(author) {
                        Image(systemName: "shield.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .background(
                                Circle()
                                    .fill(.blue.opacity(0.15))
                                    .frame(width: 16, height: 16)
                            )
                    }
                }
                
                // Verified badge
                if let author = author, author.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                // Subscription tier badge
                if let author = author, author.subscriptionTier != .basic {
                    Text(author.subscriptionTier.displayName.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(subscriptionTierColor(author.subscriptionTier))
                        .cornerRadius(4)
                }
            }
            
            Text(formatTimestamp(message.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ENHANCED: Handle different message types
            if let mediaContent = getMediaContent(from: message) {
                mediaMessageView(mediaContent)
            } else {
                // Regular text message bubble with mention highlighting
                HStack {
                    Text(attributedMessageContent)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(messageBackgroundColor)
                        )
                    
                    Spacer()
                }
            }
            
            // Reactions positioned below and to the left
            if !reactions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(reactions) { reactionGroup in
                        Button(action: {
                            onReact(reactionGroup.emoji)
                        }) {
                            HStack(spacing: 4) {
                                Text(reactionGroup.emoji)
                                    .font(.caption)
                                
                                if reactionGroup.count > 1 {
                                    Text("\(reactionGroup.count)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(reactionGroup.hasUserReacted ?
                                          Color.yellow.opacity(0.3) :
                                          Color(.systemGray5)
                                    )
                            )
                            .scaleEffect(reactionGroup.hasUserReacted ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3), value: reactionGroup.hasUserReacted)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Add reaction button
                    Button(action: onShowEmojiPicker) {
                        Image(systemName: "plus")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(Color(.systemGray5))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
            }
            
            // NEW: Read Receipts (only show for current user's messages)
            if isUserMessage && !readReceipts.isEmpty {
                readReceiptsView
            }
        }
    }
    
    // MARK: - Media Message View
    @ViewBuilder
    private func mediaMessageView(_ mediaContent: MediaContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch mediaContent.type {
            case .image:
                AsyncImage(url: URL(string: mediaContent.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 250, maxHeight: 300)
                        .cornerRadius(12)
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 250, height: 200)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                
            case .document:
                documentPreviewView(mediaContent)
                
            case .video:
                videoPreviewView(mediaContent)
            }
            
            // Caption text if present (but not for pure media messages)
            if !message.content.isEmpty && !message.content.hasPrefix("[MEDIA:") {
                HStack {
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private func documentPreviewView(_ mediaContent: MediaContent) -> some View {
        HStack(spacing: 12) {
            // Document icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: documentIcon(for: mediaContent.fileName))
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // Document info
            VStack(alignment: .leading, spacing: 2) {
                Text(mediaContent.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let fileSize = mediaContent.fileSize {
                    Text(formatFileSize(fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Download button
            Button(action: {
                // to do - downloadDocument(mediaContent)
            }) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .frame(maxWidth: 280)
    }
    
    @ViewBuilder
    private func videoPreviewView(_ mediaContent: MediaContent) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(width: 250, height: 140)
            
            VStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Text("Video Message")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var messageActionsView: some View {
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
        .padding(.leading, 52)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Helper Methods for Role Checking
    private func isUserAdmin(_ user: User) -> Bool {
        // TODO: Implement actual admin checking logic
        // This should check if the user has admin role in the current community
        // For now, returning false as placeholder - you'll need to integrate with your community role system
        return false // Placeholder
    }
    
    private func isUserModerator(_ user: User) -> Bool {
        // TODO: Implement actual moderator checking logic
        // This should check if the user has moderator role in the current community
        // For now, returning false as placeholder - you'll need to integrate with your community role system
        return false // Placeholder
    }
    
    private func isUserOwner(_ user: User) -> Bool {
        // Check if the user is the owner of the current community
        return user.id == community.creatorId
    }
    
    // MARK: - Helper Properties and Methods
    private var userColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .indigo, .teal]
        let hash = message.authorId.hashValue
        return colors[abs(hash) % colors.count]
    }
    
    private var userInitials: String {
        if let author = author {
            let names = author.fullName.components(separatedBy: " ")
            if names.count >= 2 {
                return String(names[0].prefix(1)) + String(names[1].prefix(1))
            } else if let firstChar = names.first?.first {
                return String(firstChar)
            }
        }
        return String(message.authorUsername.prefix(2)).uppercased()
    }
    
    private var shouldShowOnlineStatus: Bool {
        // Implement online status logic if needed
        return false
    }
    
    private func subscriptionTierColor(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .basic: return .gray
        case .pro: return .blue
        case .elite: return .purple
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func getMediaContent(from message: CommunityMessage) -> MediaContent? {
        let content = message.content
        
        if content.hasPrefix("[MEDIA:IMAGE]") {
            let url = String(content.dropFirst(13))
            return MediaContent(type: .image, url: url, fileName: "image.jpg", fileSize: nil)
        } else if content.hasPrefix("[MEDIA:DOCUMENT]") {
            let parts = String(content.dropFirst(16)).components(separatedBy: "|")
            if parts.count >= 2 {
                return MediaContent(type: .document, url: parts[0], fileName: parts[1], fileSize: nil)
            }
        } else if content.hasPrefix("[MEDIA:VIDEO]") {
            let url = String(content.dropFirst(13))
            return MediaContent(type: .video, url: url, fileName: "video.mp4", fileSize: nil)
        }
        
        return nil
    }
    
    private func documentIcon(for fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return "doc.richtext"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "tablecells"
        case "ppt", "pptx":
            return "rectangle.on.rectangle"
        case "txt":
            return "doc.plaintext"
        case "zip", "rar":
            return "archivebox"
        default:
            return "doc"
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Mention Highlighting
    private var attributedMessageContent: AttributedString {
        var attributedString = AttributedString(message.content)
        
        // Detect @mentions and apply styling
        let mentionPattern = #"@(\w+)"#
        let regex = try? NSRegularExpression(pattern: mentionPattern)
        let nsString = message.content as NSString
        let matches = regex?.matches(in: message.content, range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches.reversed() { // Reverse to maintain indices
            if let range = Range(match.range, in: message.content) {
                if let attributedRange = Range(range, in: attributedString) {
                    attributedString[attributedRange].foregroundColor = .blue
                    attributedString[attributedRange].font = .body.weight(.semibold)
                    
                    // Check if this mention is for current user
                    let mentionText = String(message.content[range])
                    if mentionText.lowercased().contains(currentUserId.lowercased()) {
                        attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
                    }
                }
            }
        }
        
        return attributedString
    }
    
    private var messageBackgroundColor: Color {
        // Highlight message background if current user is mentioned
        let mentionPattern = #"@(\w+)"#
        let regex = try? NSRegularExpression(pattern: mentionPattern)
        let matches = regex?.matches(in: message.content, range: NSRange(location: 0, length: message.content.count)) ?? []
        
        let currentUserMentioned = matches.contains { match in
            if let range = Range(match.range, in: message.content) {
                let mentionText = String(message.content[range])
                return mentionText.lowercased().contains(currentUserId.lowercased())
            }
            return false
        }
        
        return currentUserMentioned ? Color.blue.opacity(0.1) : Color(.systemGray6)
    }
    
    // MARK: - Read Receipts View
    private var readReceiptsView: some View {
        HStack(spacing: 4) {
            if readReceipts.count > 0 {
                Image(systemName: readReceipts.count == 1 ? "checkmark" : "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(readReceipts.count == 1 ? .secondary : .blue)
                
                if readReceipts.count > 1 {
                    Text("\(readReceipts.count)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                Text("Read")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.top, 2)
    }
}

// MARK: - Button Styles
struct ProfileImageButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

// MARK: - User Loading and Caching Extension
extension ChannelChatView {
    private func loadUsersForMessages() {
        let userIds = Set(viewModel.messages.map { $0.authorId })
        
        for userId in userIds {
            if userCache[userId] == nil {
                loadUser(userId: userId)
            }
        }
    }
    
    private func loadUser(userId: String) {
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
    
    private func loadUsersForNewMessages() {
        let userIds = Set(viewModel.messages.map { $0.authorId })
        let cachedUserIds = Set(userCache.keys)
        let missingUserIds = userIds.subtracting(cachedUserIds)
        
        for userId in missingUserIds {
            loadUser(userId: userId)
        }
    }
}

// MARK: - Enhanced Message Input Extension
extension ChannelChatView {
    private var enhancedMessageInput: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // ENHANCED: Attachment Button with Media Options
                Button(action: {
                    showingMediaOptions = true
                }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.canUserPost ? Color.blue : Color.gray)
                            .frame(width: 32, height: 32)
                        
                        if isUploadingMedia {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
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
                                .foregroundColor(showEmojiPicker ? .blue : .gray)
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
        
        // Stop typing indicator
        stopTyping()
        
        viewModel.sendMessage(content: finalMessage)
        messageText = ""
        replyingTo = nil
        
        // Simulate read receipts for demo (in real app, this would come from Firebase)
        if let lastMessage = viewModel.messages.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                simulateReadReceipts(for: lastMessage.id)
            }
        }
    }
    
    // MARK: - Simulate Read Receipts (Demo Only)
    private func simulateReadReceipts(for messageId: String) {
        // In real implementation, this would come from Firebase real-time listeners
        let simulatedReaders = Set(["user1", "user2", "user3"]) // Simulate some users reading
        readReceipts[messageId] = simulatedReaders
    }
    
    // MARK: - Demo Typing Users (Remove in Production)
    private func simulateTypingUsers() {
        // Simulate other users typing for demo purposes
        typingUsers.insert("demoUser1")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            typingUsers.insert("demoUser2")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            typingUsers.removeAll()
        }
    }
    
    // MARK: - @Mentions Detection
    private func detectMentions() {
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
    
    private func searchForMentionUsers(query: String) {
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
    
    private func createSpecialMentionUser(username: String, fullName: String) -> User {
        return User(id: username, email: "", username: username, fullName: fullName)
    }
    
    private func hideMentionSuggestions() {
        showingMentionSuggestions = false
        mentionSuggestions = []
        currentMentionQuery = ""
    }
    
    private func insertMention(_ user: User) {
        // Replace the current @query with @username
        if let atIndex = messageText.lastIndex(of: "@") {
            let beforeAt = String(messageText[..<atIndex])
            messageText = beforeAt + "@\(user.username) "
        }
        hideMentionSuggestions()
    }
}

// MARK: - Media Handling Extensions
extension ChannelChatView {
    private func handleImageUpload(_ image: UIImage) {
        isUploadingMedia = true
        
        Task {
            do {
                let imageUrl = try await uploadImageToFirebase(image)
                let mediaMessage = "[MEDIA:IMAGE]\(imageUrl)"
                await MainActor.run {
                    sendMediaMessage(content: mediaMessage)
                    selectedImage = nil
                    isUploadingMedia = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to upload image: \(error)")
                    isUploadingMedia = false
                }
            }
        }
    }
    
    private func handleDocumentUpload(_ url: URL) {
        isUploadingMedia = true
        
        Task {
            do {
                let documentUrl = try await uploadDocumentToFirebase(url)
                let fileName = url.lastPathComponent
                let mediaMessage = "[MEDIA:DOCUMENT]\(documentUrl)|\(fileName)"
                await MainActor.run {
                    sendMediaMessage(content: mediaMessage)
                    selectedDocumentURL = nil
                    isUploadingMedia = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to upload document: \(error)")
                    isUploadingMedia = false
                }
            }
        }
    }
    
    private func sendMediaMessage(content: String) {
        viewModel.sendMessage(content: content)
    }
    
    private func uploadImageToFirebase(_ image: UIImage) async throws -> String {
        print("🔄 Starting chat image upload...")
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("❌ Failed to convert image to data")
            throw NSError(domain: "ImageUpload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
        }
        
        print("📊 Image data size: \(imageData.count) bytes")
        
        let fileName = "\(UUID().uuidString).jpg"
        let storageRef = Storage.storage().reference().child("chat_images").child(fileName)
        
        print("🔍 Upload path: chat_images/\(fileName)")
        
        do {
            print("🔄 Uploading chat image to Firebase Storage...")
            
            // Upload the file using proper async/await pattern
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                storageRef.putData(imageData, metadata: nil) { metadata, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let metadata = metadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ImageUpload", code: 3, userInfo: [NSLocalizedDescriptionKey: "Upload failed with no error"]))
                    }
                }
            }
            print("✅ Chat image uploaded successfully")
            
            // Add retry logic for download URL
            var downloadURL: URL?
            var attempts = 0
            let maxAttempts = 5
            
            while downloadURL == nil && attempts < maxAttempts {
                do {
                    attempts += 1
                    print("🔄 Attempting to get download URL (attempt \(attempts)/\(maxAttempts))...")
                    
                    downloadURL = try await storageRef.downloadURL()
                    print("✅ Download URL obtained: \(downloadURL!.absoluteString)")
                    
                } catch {
                    print("⚠️ Download URL attempt \(attempts) failed: \(error)")
                    
                    if attempts < maxAttempts {
                        // Wait before retrying (exponential backoff)
                        let delay = Double(attempts) * 0.5 // 0.5s, 1s, 1.5s, 2s
                        print("⏳ Waiting \(delay)s before retry...")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } else {
                        print("❌ All download URL attempts failed")
                        throw error
                    }
                }
            }
            
            guard let finalURL = downloadURL else {
                throw NSError(domain: "ImageUpload", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL after upload"])
            }
            
            return finalURL.absoluteString
            
        } catch {
            print("❌ Chat image upload failed: \(error)")
            throw error
        }
    }
    
    private func uploadDocumentToFirebase(_ url: URL) async throws -> String {
        print("🔄 Starting document upload: \(url.lastPathComponent)")
        
        guard let documentData = try? Data(contentsOf: url) else {
            print("❌ Failed to read document data")
            throw NSError(domain: "DocumentUpload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read document"])
        }
        
        print("📊 Document data size: \(documentData.count) bytes")
        
        let originalName = url.lastPathComponent
        let fileExtension = (originalName as NSString).pathExtension
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let storageRef = Storage.storage().reference().child("chat_documents").child(fileName)
        
        print("🔍 Upload path: chat_documents/\(fileName)")
        
        do {
            print("🔄 Uploading document to Firebase Storage...")
            
            // Upload the file
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                storageRef.putData(documentData, metadata: nil) { metadata, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let metadata = metadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: NSError(domain: "DocumentUpload", code: 3, userInfo: [NSLocalizedDescriptionKey: "Upload failed with no error"]))
                    }
                }
            }
            print("✅ Document uploaded successfully")
            
            // Add retry logic for download URL
            var downloadURL: URL?
            var attempts = 0
            let maxAttempts = 5
            
            while downloadURL == nil && attempts < maxAttempts {
                do {
                    attempts += 1
                    print("🔄 Attempting to get download URL (attempt \(attempts)/\(maxAttempts))...")
                    
                    downloadURL = try await storageRef.downloadURL()
                    print("✅ Download URL obtained: \(downloadURL!.absoluteString)")
                    
                } catch {
                    print("⚠️ Download URL attempt \(attempts) failed: \(error)")
                    
                    if attempts < maxAttempts {
                        // Wait before retrying (exponential backoff)
                        let delay = Double(attempts) * 0.5 // 0.5s, 1s, 1.5s, 2s
                        print("⏳ Waiting \(delay)s before retry...")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } else {
                        print("❌ All download URL attempts failed")
                        throw error
                    }
                }
            }
            
            guard let finalURL = downloadURL else {
                throw NSError(domain: "DocumentUpload", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL after upload"])
            }
            
            return finalURL.absoluteString
            
        } catch {
            print("❌ Document upload failed: \(error)")
            throw error
        }
    }
}

// MARK: - Emoji Picker Overlay Extension
extension ChannelChatView {
    private var emojiPickerOverlay: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showEmojiPicker = false
                    emojiPickerForMessage = nil
                }
            
            VStack {
                Spacer()
                
                // Emoji Picker Card
                VStack(spacing: 0) {
                    // Handle bar
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    // Header
                    HStack {
                        Text(emojiPickerForMessage != nil ? "React to message" : "Add emoji")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Done") {
                            showEmojiPicker = false
                            emojiPickerForMessage = nil
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                    
                    // Emoji Grid
                    emojiGrid
                }
                .background(Color(.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showEmojiPicker)
    }
    
    private var emojiGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 16) {
                ForEach(EmojiData.popularEmojis, id: \.self) { emoji in
                    Button(action: {
                        handleEmojiSelection(emoji)
                    }) {
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .cornerRadius(22)
                    }
                    .buttonStyle(EmojiButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 300)
    }
    
    private func handleEmojiSelection(_ emoji: String) {
        if let message = emojiPickerForMessage {
            viewModel.addReaction(to: message.id, emoji: emoji)
        } else {
            if editingMessage != nil {
                editedContent += emoji
            } else {
                messageText += emoji
            }
        }
        
        showEmojiPicker = false
        emojiPickerForMessage = nil
    }
}

// MARK: - Reply and Edit Banners Extension
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

// MARK: - Message Management Extension
extension ChannelChatView {
    private func startEditingMessage(_ message: CommunityMessage) {
        guard viewModel.canEditMessage(message) else { return }
        editingMessage = message
        editedContent = message.content
    }
    
    private func saveEditedMessage() {
        guard let editingMessage = editingMessage else { return }
        
        let trimmedContent = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        // Update locally (you can add Firebase integration later)
        if let index = viewModel.messages.firstIndex(where: { $0.id == editingMessage.id }) {
            viewModel.messages[index].content = trimmedContent + " (edited)"
        }
        
        cancelEditing()
    }
    
    private func cancelEditing() {
        editingMessage = nil
        editedContent = ""
    }
    
    private func requestDeleteMessage(_ message: CommunityMessage) {
        guard viewModel.canDeleteMessage(message) else { return }
        messageToDelete = message
        showDeleteConfirmation = true
    }
    
    private func confirmDeleteMessage() {
        guard let messageToDelete = messageToDelete else { return }
        
        // Remove from local array (you can add Firebase integration later)
        viewModel.messages.removeAll { $0.id == messageToDelete.id }
        
        self.messageToDelete = nil
        showDeleteConfirmation = false
    }
    
    private func cancelDeleteMessage() {
        messageToDelete = nil
        showDeleteConfirmation = false
    }
}

// MARK: - Helper Methods Extension
extension ChannelChatView {
    private func shouldShowUsername(_ message: CommunityMessage) -> Bool {
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

struct EmojiButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

// Emoji Data
struct EmojiData {
    static let popularEmojis = [
        "👍", "❤️", "😂", "😮", "😢", "😡", "👎", "🎉",
        "🔥", "💯", "⭐", "✅", "❌", "🚀", "💎", "📈",
        "📉", "💰", "🤑", "🎯", "⚡", "💪", "🙌", "👏",
        "🤔", "😎", "🤩", "😍", "🥳", "🤯", "😴", "🤪",
        "🙄", "😤", "🤬", "😱", "🥺", "😭", "🤝", "👋",
        "✋", "👌", "🤞", "🤟", "🤘", "👊", "✊", "👆",
        "🐂", "🐻", "📊", "📋", "💼", "💻", "📱", "⌚",
        "🎲", "🎰", "🏆", "🥇", "🥈", "🥉", "🎖️", "🏅"
    ]
}

// Helper for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}


// MARK: - Channel Info Sheet (Simplified)
struct ChannelInfoSheet: View {
    let community: Community
    let channel: Channel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(channelColor.opacity(0.15))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: channelIcon)
                                .font(.title2)
                                .foregroundColor(channelColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("#\(channel.name)")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(channel.type.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("About") {
                    Text(channelDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Channel Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
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
    
    private var channelDescription: String {
        switch channel.type {
        case .text:
            return "A text channel for general discussions and conversations between community members."
        case .callouts:
            return "An admin-only channel for posting trading callouts, market signals, and important announcements."
        case .voice:
            return "A voice channel for real-time audio conversations and live discussions."
        }
    }
}

// MARK: - Enhanced User Profile Sheet (Moved from nested scope)
struct UserProfileSheet: View {
    let user: User
    let community: Community?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: FirebaseAuthService
    
    @State private var isFollowing = false
    @State private var showingMessageComposer = false
    @State private var showingMoreOptions = false
    @State private var animateContent = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with Background
                    headerWithBackground
                    
                    // Profile Content
                    VStack(spacing: 24) {
                        // Stats Grid
                        enhancedStatsSection
                        
                        // Bio Section
                        if let bio = user.bio, !bio.isEmpty {
                            bioSection(bio)
                        }
                        
                        // Trading Performance Section
                        tradingPerformanceSection
                        
                        // Communities Section
                        communitiesSection
                        
                        // Recent Activity Section
                        recentActivitySection
                        
                        // Action Buttons
                        if user.id != authService.currentUser?.id {
                            actionButtonsSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if user.id != authService.currentUser?.id {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingMoreOptions = true }) {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
        }
        .confirmationDialog("User Options", isPresented: $showingMoreOptions) {
            Button("Report User") {
                // Handle report
            }
            Button("Block User") {
                // Handle block
            }
            Button("Share Profile") {
                // Handle share
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Header with Background
    private var headerWithBackground: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    subscriptionTierColor(user.subscriptionTier).opacity(0.3),
                    subscriptionTierColor(user.subscriptionTier).opacity(0.1),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .frame(height: 280)
            
            VStack(spacing: 20) {
                Spacer().frame(height: 60)
                
                // ENHANCED: Profile Image (same style as chat)
                profileImageView
                
                // Name and Username
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text(user.fullName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                        
                        if user.subscriptionTier != .basic {
                            subscriptionBadge
                        }
                    }
                    .opacity(animateContent ? 1 : 0)
                    .scaleEffect(animateContent ? 1 : 0.9)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateContent)
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.easeInOut(duration: 0.6).delay(0.3), value: animateContent)
                }
                
                // Follow Stats Row
                followStatsRow
                
                Spacer()
            }
        }
    }
    
    // ENHANCED: Profile Image (matching chat style)
    private var profileImageView: some View {
        Group {
            if let profileImageUrl = user.profileImageUrl,
               !profileImageUrl.isEmpty {
                AsyncImage(url: URL(string: profileImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [subscriptionTierColor(user.subscriptionTier).opacity(0.2), subscriptionTierColor(user.subscriptionTier).opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: subscriptionTierColor(user.subscriptionTier)))
                                .scaleEffect(0.8)
                        )
                }
            } else {
                // Fallback to initials circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [subscriptionTierColor(user.subscriptionTier).opacity(0.2), subscriptionTierColor(user.subscriptionTier).opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Text(String(user.fullName.prefix(1)))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(subscriptionTierColor(user.subscriptionTier))
                    )
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(subscriptionTierColor(user.subscriptionTier).opacity(0.3), lineWidth: 3)
        )
        .shadow(color: subscriptionTierColor(user.subscriptionTier).opacity(0.3), radius: 12, x: 0, y: 6)
        .scaleEffect(animateContent ? 1 : 0.8)
        .opacity(animateContent ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
    }
    
    private var subscriptionBadge: some View {
        Text(user.subscriptionTier.displayName.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(subscriptionTierColor(user.subscriptionTier))
                    .shadow(color: subscriptionTierColor(user.subscriptionTier).opacity(0.5), radius: 4, x: 0, y: 2)
            )
    }
    
    private var followStatsRow: some View {
        HStack(spacing: 32) {
            VStack(spacing: 4) {
                Text("\(user.followersCount)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Followers")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("\(user.followingCount)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Following")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text(memberSinceText)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Member Since")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateContent)
    }
    
    // MARK: - Enhanced Stats Section
    private var enhancedStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trading Performance")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if user.winRate > 0.7 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Top Performer")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Win Rate Card
                enhancedStatCard(
                    title: "Win Rate",
                    value: "\(Int(user.winRate * 100))%",
                    subtitle: getWinRateDescription(user.winRate),
                    icon: "chart.line.uptrend.xyaxis",
                    color: user.winRate > 0.6 ? .green : .orange,
                    trend: user.winRate > 0.6 ? .up : .down
                )
                
                // Total P&L Card
                enhancedStatCard(
                    title: "Total P&L",
                    value: formatCurrency(user.totalProfitLoss),
                    subtitle: getProfitDescription(user.totalProfitLoss),
                    icon: "dollarsign.circle",
                    color: user.totalProfitLoss >= 0 ? .green : .red,
                    trend: user.totalProfitLoss >= 0 ? .up : .down
                )
                
                // Subscription Card
                enhancedStatCard(
                    title: "Subscription",
                    value: user.subscriptionTier.displayName,
                    subtitle: getSubscriptionDescription(user.subscriptionTier),
                    icon: "star.circle",
                    color: subscriptionTierColor(user.subscriptionTier),
                    trend: .neutral
                )
                
                // Communities Card
                enhancedStatCard(
                    title: "Communities",
                    value: "\(user.communityIds.count)",
                    subtitle: user.communityIds.count > 3 ? "Very Active" : "Active",
                    icon: "person.2.circle",
                    color: .purple,
                    trend: .neutral
                )
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.5), value: animateContent)
    }
    
    private func enhancedStatCard(title: String, value: String, subtitle: String, icon: String, color: Color, trend: TrendDirection) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                if trend != .neutral {
                    Image(systemName: trend == .up ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(trend == .up ? .green : .red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(color)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Trading Performance Section
    private var tradingPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Stats")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                statRow("Starting Capital", formatCurrency(user.startingCapital))
                statRow("Current P&L", formatCurrency(user.totalProfitLoss))
                statRow("ROI", "\(calculateROI())%")
                statRow("Risk Rating", getRiskRating())
                statRow("Trading Style", getTradingStyle())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.6), value: animateContent)
    }
    
    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Bio Section
    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(bio)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.7), value: animateContent)
    }
    
    // MARK: - Communities Section
    private var communitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Communities (\(user.communityIds.count))")
                .font(.headline)
                .fontWeight(.bold)
            
            if user.communityIds.isEmpty {
                Text("No communities joined yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                // Community list would go here - for now showing count
                VStack(spacing: 8) {
                    ForEach(0..<min(3, user.communityIds.count), id: \.self) { index in
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("#")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Community \(index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("Member since 2024")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    if user.communityIds.count > 3 {
                        Text("+ \(user.communityIds.count - 3) more communities")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.8), value: animateContent)
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                activityItem(
                    icon: "message.circle",
                    title: "Posted in Elite Traders",
                    subtitle: "2 hours ago",
                    color: .blue
                )
                
                activityItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Successful trade on AAPL",
                    subtitle: "1 day ago",
                    color: .green
                )
                
                activityItem(
                    icon: "person.badge.plus",
                    title: "Joined new community",
                    subtitle: "3 days ago",
                    color: .purple
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.9), value: animateContent)
    }
    
    private func activityItem(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // Follow/Unfollow Button
                Button(action: toggleFollow) {
                    HStack(spacing: 8) {
                        Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text(isFollowing ? "Unfollow" : "Follow")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(isFollowing ? .primary : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(isFollowing ? Color(.systemGray5) : subscriptionTierColor(user.subscriptionTier))
                            .shadow(color: isFollowing ? .clear : subscriptionTierColor(user.subscriptionTier).opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                
                // Message Button
                Button(action: { showingMessageComposer = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "message")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text("Message")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(subscriptionTierColor(user.subscriptionTier))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .strokeBorder(subscriptionTierColor(user.subscriptionTier), lineWidth: 2)
                    )
                }
            }
            
            // Additional action buttons
            HStack(spacing: 12) {
                actionButton("Copy Trades", "doc.on.clipboard", .blue)
                actionButton("View Calls", "megaphone", .orange)
                actionButton("Share", "square.and.arrow.up", .green)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(1.0), value: animateContent)
    }
    
    private func actionButton(_ title: String, _ icon: String, _ color: Color) -> some View {
        Button(action: {}) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
        }
    }
    struct RoundedCorner: Shape {
        var radius: CGFloat = .infinity
        var corners: UIRectCorner = .allCorners

        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: radius, height: radius)
            )
            return Path(path.cgPath)
        }
    }
    
    // MARK: - Helper Methods
    private var memberSinceText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: user.createdAt)
    }
    
    private func subscriptionTierColor(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .basic: return .gray
        case .pro: return .blue
        case .elite: return .purple
        }
    }
    
    private func getWinRateDescription(_ winRate: Double) -> String {
        switch winRate {
        case 0.8...: return "Exceptional"
        case 0.7..<0.8: return "Excellent"
        case 0.6..<0.7: return "Good"
        case 0.5..<0.6: return "Average"
        default: return "Needs Work"
        }
    }
    
    private func getProfitDescription(_ profit: Double) -> String {
        if profit >= 10000 {
            return "High Performer"
        } else if profit >= 1000 {
            return "Profitable"
        } else if profit >= 0 {
            return "Break Even"
        } else {
            return "At Loss"
        }
    }
    
    private func getSubscriptionDescription(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .basic: return "Standard Access"
        case .pro: return "Premium Features"
        case .elite: return "Full Access"
        }
    }
    
    private func calculateROI() -> Int {
        guard user.startingCapital > 0 else { return 0 }
        let roi = (user.totalProfitLoss / user.startingCapital) * 100
        return Int(roi)
    }
    
    private func getRiskRating() -> String {
        let roi = calculateROI()
        switch roi {
        case 50...: return "High Risk"
        case 20..<50: return "Medium Risk"
        case 0..<20: return "Low Risk"
        default: return "Conservative"
        }
    }
    
    private func getTradingStyle() -> String {
        // This could be determined by various factors
        return user.subscriptionTier == .elite ? "Day Trader" : "Swing Trader"
    }
    
    private func toggleFollow() {
        withAnimation(.spring()) {
            isFollowing.toggle()
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Supporting Types
enum TrendDirection {
    case up, down, neutral
}

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
