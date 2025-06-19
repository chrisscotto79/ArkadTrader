// File: Shared/Services/DataService.swift

import Foundation

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    private let networkService = NetworkService.shared
    
    @Published var trades: [Trade] = []
    @Published var posts: [Post] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoading = false
    
    private init() {
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Initial Data Loading
    private func loadInitialData() async {
        // Load data only if user is authenticated
        guard AuthService.shared.isAuthenticated,
              let userId = AuthService.shared.currentUser?.id.uuidString else {
            return
        }
        
        isLoading = true
        
        async let tradesTask = loadTrades(for: userId)
        async let leaderboardTask = loadLeaderboard()
        async let postsTask = loadPosts()
        
        await tradesTask
        await leaderboardTask
        await postsTask
        
        isLoading = false
    }
    
    // MARK: - Trade Methods
    func loadTrades(for userId: String) async {
        do {
            self.trades = try await networkService.fetchTrades(userId: userId)
        } catch {
            print("Failed to load trades: \(error)")
            // Fallback to mock data for development
            loadMockTrades()
        }
    }
    
    func addTrade(_ trade: Trade) async throws {
        let createRequest = CreateTradeRequest(
            ticker: trade.ticker,
            tradeType: trade.tradeType,
            entryPrice: trade.entryPrice,
            quantity: trade.quantity,
            notes: trade.notes,
            strategy: trade.strategy
        )
        
        do {
            let newTrade = try await networkService.createTrade(createRequest)
            self.trades.append(newTrade)
        } catch {
            print("Failed to add trade: \(error)")
            throw error
        }
    }
    
    func updateTrade(_ trade: Trade) async throws {
        let updateRequest = UpdateTradeRequest(
            exitPrice: trade.exitPrice,
            notes: trade.notes,
            strategy: trade.strategy
        )
        
        do {
            let updatedTrade = try await networkService.updateTrade(
                id: trade.id.uuidString,
                updateRequest
            )
            
            if let index = trades.firstIndex(where: { $0.id == trade.id }) {
                trades[index] = updatedTrade
            }
        } catch {
            print("Failed to update trade: \(error)")
            throw error
        }
    }
    
    func deleteTrade(_ trade: Trade) async throws {
        do {
            try await networkService.deleteTrade(id: trade.id.uuidString)
            trades.removeAll { $0.id == trade.id }
        } catch {
            print("Failed to delete trade: \(error)")
            throw error
        }
    }
    
    // MARK: - Post Methods
    func loadPosts() async {
        do {
            self.posts = try await networkService.fetchFeed()
        } catch {
            print("Failed to load posts: \(error)")
            // Fallback to mock data for development
            loadMockPosts()
        }
    }
    
    func addPost(_ post: Post) async throws {
        let createRequest = CreatePostRequest(
            content: post.content,
            imageURL: post.imageURL,
            postType: post.postType
        )
        
        do {
            let newPost = try await networkService.createPost(createRequest)
            self.posts.insert(newPost, at: 0)
        } catch {
            print("Failed to add post: \(error)")
            throw error
        }
    }
    
    // MARK: - Leaderboard Methods
    func loadLeaderboard(timeframe: String = "weekly") async {
        do {
            self.leaderboard = try await networkService.fetchLeaderboard(timeframe: timeframe)
        } catch {
            print("Failed to load leaderboard: \(error)")
            // Fallback to mock data for development
            loadMockLeaderboard()
        }
    }
    
    // MARK: - Mock Data (for development/testing)
    private func loadMockTrades() {
        // Keep existing mock trades for development
        trades = []
    }
    
    private func loadMockPosts() {
        // Keep existing mock posts for development
        posts = []
    }
    
    private func loadMockLeaderboard() {
        leaderboard = [
            LeaderboardEntry(rank: 1, username: "ProTrader", profitLoss: 15240.50, winRate: 78.5, isVerified: true),
            LeaderboardEntry(rank: 2, username: "BullRunner", profitLoss: 12890.25, winRate: 72.3, isVerified: true),
            LeaderboardEntry(rank: 3, username: "MarketMaster", profitLoss: 11650.00, winRate: 69.8, isVerified: false),
            LeaderboardEntry(rank: 4, username: "TradingGuru", profitLoss: 9875.75, winRate: 68.2, isVerified: true),
            LeaderboardEntry(rank: 5, username: "StockWiz", profitLoss: 8420.30, winRate: 65.7, isVerified: false)
        ]
    }
    
    // MARK: - Refresh Methods
    func refreshAllData() async {
        guard let userId = AuthService.shared.currentUser?.id.uuidString else { return }
        await loadInitialData()
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

// File: Core/Search/ViewModels/SearchViewModel.swift

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

// File: Core/Settings/ViewModels/SettingsViewModel.swift

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isPrivateAccount = false
    @Published var pushNotifications = true
    @Published var emailNotifications = true
    @Published var isLoading = false
    @Published var showDeleteAccountAlert = false
    @Published var showLogoutAlert = false
    
    private let authService = AuthService.shared
    
    init() {
        loadSettings()
    }
    
    // MARK: - Settings Management
    func loadSettings() {
        // Load from user defaults or user object
        // These would typically come from the server
        isPrivateAccount = UserDefaults.standard.bool(forKey: "isPrivateAccount")
        pushNotifications = UserDefaults.standard.bool(forKey: "pushNotifications")
        emailNotifications = UserDefaults.standard.bool(forKey: "emailNotifications")
    }
    
    func updatePrivacy(_ isPrivate: Bool) {
        isLoading = true
        Task {
            do {
                _ = try await authService.updateAccountSettings(isPrivate: isPrivate)
                self.isPrivateAccount = isPrivate
                UserDefaults.standard.set(isPrivate, forKey: "isPrivateAccount")
            } catch {
                print("Failed to update privacy setting: \(error)")
            }
            self.isLoading = false
        }
    }
    
    func updateNotifications(push: Bool? = nil, email: Bool? = nil) {
        isLoading = true
        Task {
            do {
                _ = try await authService.updateAccountSettings(
                    pushNotifications: push,
                    emailNotifications: email
                )
                
                if let push = push {
                    self.pushNotifications = push
                    UserDefaults.standard.set(push, forKey: "pushNotifications")
                }
                
                if let email = email {
                    self.emailNotifications = email
                    UserDefaults.standard.set(email, forKey: "emailNotifications")
                }
            } catch {
                print("Failed to update notification settings: \(error)")
            }
            self.isLoading = false
        }
    }
    
    // MARK: - Account Actions
    func logout() {
        authService.logout()
    }
    
    func deleteAccount() {
        isLoading = true
        Task {
            do {
                try await authService.deleteAccount()
                // Account is deleted, user is automatically logged out
            } catch {
                print("Failed to delete account: \(error)")
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Export Data
    func exportUserData() {
        // Implement data export functionality
        // This would generate a file with user's trading data
        print("Exporting user data...")
    }
    
    // MARK: - Helper Methods
    var currentUser: User? {
        return authService.currentUser
    }
}
