// File: Core/Search/ViewModels/SearchViewModel.swift

import Foundation

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [SearchResult] = []
    @Published var userResults: [User] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching = false
    @Published var showingSuggestions = false
    
    private let searchService = SearchService.shared
    private let socialService = SocialService.shared
    
    init() {
        self.recentSearches = searchService.recentSearches
    }
    
    // MARK: - Search Methods
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }
        
        Task {
            do {
                isSearching = true
                userResults = try await searchService.searchUsers(query: searchText)
                isSearching = false
            } catch {
                isSearching = false
                print("Search failed: \(error)")
            }
        }
    }
    
    func performFullSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }
        
        Task {
            do {
                isSearching = true
                searchResults = try await searchService.searchAll(query: searchText)
                isSearching = false
            } catch {
                isSearching = false
                print("Search failed: \(error)")
            }
        }
    }
    
    func clearResults() {
        searchResults = []
        userResults = []
        showingSuggestions = false
    }
    
    func selectRecentSearch(_ query: String) {
        searchText = query
        performSearch()
    }
    
    func clearRecentSearches() {
        searchService.clearRecentSearches()
        recentSearches = []
    }
    
    // MARK: - Social Actions
    func followUser(_ user: User) {
        Task {
            do {
                _ = try await socialService.followUser(user.id.uuidString)
                // Update user in results
                updateUserFollowStatus(user.id.uuidString, isFollowing: true)
            } catch {
                print("Failed to follow user: \(error)")
            }
        }
    }
    
    func unfollowUser(_ user: User) {
        Task {
            do {
                _ = try await socialService.unfollowUser(user.id.uuidString)
                // Update user in results
                updateUserFollowStatus(user.id.uuidString, isFollowing: false)
            } catch {
                print("Failed to unfollow user: \(error)")
            }
        }
    }
    
    private func updateUserFollowStatus(_ userId: String, isFollowing: Bool) {
        // Update in user results
        for i in 0..<userResults.count {
            if userResults[i].id.uuidString == userId {
                // You'd need to add an isFollowing property to User model
                // or track it separately
                break
            }
        }
    }
    
    // MARK: - Suggestions
    var searchSuggestions: [String] {
        if searchText.isEmpty {
            return searchService.getPopularSearches()
        } else {
            return searchService.getSearchSuggestions(for: searchText)
        }
    }
    
    func showSuggestions() {
        showingSuggestions = true
    }
    
    func hideSuggestions() {
        showingSuggestions = false
    }
}

// File: Core/Messaging/ViewModels/MessagingViewModel.swift

@MainActor
class MessagingViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isLoading = false
    @Published var isLoadingMessages = false
    
    private let messagingService = MessagingService.shared
    
    init() {
        loadConversations()
    }
    
    // MARK: - Conversations
    func loadConversations() {
        isLoading = true
        Task {
            await messagingService.loadConversations()
            self.conversations = messagingService.conversations
            self.isLoading = false
        }
    }
    
    func selectConversation(_ conversation: Conversation) {
        currentConversation = conversation
        loadMessages(for: conversation.id.uuidString)
        
        // Mark as read
        Task {
            await messagingService.markAsRead(conversationId: conversation.id.uuidString)
        }
    }
    
    // MARK: - Messages
    func loadMessages(for conversationId: String) {
        isLoadingMessages = true
        Task {
            await messagingService.loadMessages(for: conversationId)
            self.messages = messagingService.getMessages(for: conversationId)
            self.isLoadingMessages = false
        }
    }
    
    func sendMessage() {
        guard let conversation = currentConversation,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let recipientId = conversation.otherParticipant(
            currentUserId: AuthService.shared.currentUser?.id ?? UUID()
        )?.id.uuidString ?? ""
        
        Task {
            do {
                let message = try await messagingService.sendMessage(
                    to: recipientId,
                    content: messageText,
                    conversationId: conversation.id.uuidString
                )
                
                self.messages.append(message)
                self.messageText = ""
                
                // Reload conversations to update last message
                loadConversations()
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }
    
    func startConversation(with user: User) {
        Task {
            do {
                let conversation = try await messagingService.createConversation(with: user.id.uuidString)
                self.currentConversation = conversation
                self.messages = []
            } catch {
                print("Failed to start conversation: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    var unreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }
    
    func getOtherParticipant(in conversation: Conversation) -> User? {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return nil }
        return conversation.otherParticipant(currentUserId: currentUserId)
    }
}

// File: Core/Messaging/Views/ConversationRowView.swift

struct ConversationRowView: View {
    let conversation: Conversation
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture placeholder
            Circle()
                .fill(Color.arkadGold.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(otherParticipantInitials)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(otherParticipantName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessage.timestamp.timeAgoString)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                } else {
                    Text("No messages yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .italic()
                }
            }
            
            if conversation.unreadCount > 0 {
                VStack {
                    Spacer()
                    Circle()
                        .fill(Color.arkadGold)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("\(conversation.unreadCount)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadBlack)
                        )
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var otherParticipantName: String {
        guard let currentUserId = authViewModel.currentUser?.id else { return "Unknown" }
        return conversation.otherParticipant(currentUserId: currentUserId)?.fullName ?? "Unknown"
    }
    
    private var otherParticipantInitials: String {
        guard let currentUserId = authViewModel.currentUser?.id,
              let otherUser = conversation.otherParticipant(currentUserId: currentUserId) else {
            return "U"
        }
        
        let names = otherUser.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return String(firstInitial) + String(lastInitial)
    }
}

// File: Core/Messaging/Views/ChatView.swift

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var viewModel = MessagingViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingMessages {
                LoadingView()
            } else {
                messagesList
            }
            
            messageInputBar
        }
        .navigationTitle(otherParticipantName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectConversation(conversation)
        }
    }
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.senderId == authViewModel.currentUser?.id
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onAppear {
                // Scroll to bottom when view appears
                if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.messages.count) {
                // Scroll to bottom when new message is added
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var messageInputBar: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $viewModel.messageText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(1...4)
            
            Button(action: viewModel.sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .arkadGold)
            }
            .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var otherParticipantName: String {
        guard let currentUserId = authViewModel.currentUser?.id else { return "Chat" }
        return conversation.otherParticipant(currentUserId: currentUserId)?.fullName ?? "Chat"
    }
}

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isFromCurrentUser ? Color.arkadGold : Color.gray.opacity(0.2))
                    .foregroundColor(isFromCurrentUser ? .arkadBlack : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Text(message.timestamp.timeAgoString)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
}

struct NewMessageView: View {
    @StateObject private var searchViewModel = SearchViewModel()
    @Environment(\.dismiss) var dismiss
    let onUserSelected: (User) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                searchBar
                
                if searchViewModel.isSearching {
                    LoadingView()
                } else {
                    usersList
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search users", text: $searchViewModel.searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    searchViewModel.performSearch()
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding()
    }
    
    private var usersList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(searchViewModel.userResults) { user in
                    Button(action: {
                        onUserSelected(user)
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.arkadGold.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(userInitials(for: user))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.arkadGold)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.fullName)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
    
    private func userInitials(for user: User) -> String {
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return String(firstInitial) + String(lastInitial)
    }
}

// Extension for Date formatting
extension Date {
    var timeAgoString: String {
        let interval = Date().timeIntervalSince(self)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            if days == 1 {
                return "1d"
            } else {
                return "\(days)d"
            }
        }
    }
}