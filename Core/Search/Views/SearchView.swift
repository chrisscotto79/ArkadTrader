// File: Core/Search/Views/SearchView.swift

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedTab = 0 // 0 = Users, 1 = Posts, 2 = All
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                
                if viewModel.isSearching {
                    LoadingView()
                } else if viewModel.searchText.isEmpty {
                    searchSuggestions
                } else {
                    searchResults
                }
            }
            .navigationTitle("Search")
        }
    }
    
    private var searchBar: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search traders, posts, or symbols", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        viewModel.performSearch()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        viewModel.clearResults()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Search type selector
            if !viewModel.searchText.isEmpty {
                Picker("Search Type", selection: $selectedTab) {
                    Text("Users").tag(0)
                    Text("Posts").tag(1)
                    Text("All").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedTab) {
                    if selectedTab == 2 {
                        viewModel.performFullSearch()
                    } else {
                        viewModel.performSearch()
                    }
                }
            }
        }
        .padding(.top)
    }
    
    private var searchSuggestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !viewModel.recentSearches.isEmpty {
                    recentSearchesSection
                }
                
                popularSearchesSection
            }
            .padding()
        }
    }
    
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Searches")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Clear") {
                    viewModel.clearRecentSearches()
                }
                .font(.caption)
                .foregroundColor(.arkadGold)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(viewModel.recentSearches, id: \.self) { search in
                    Button(action: {
                        viewModel.selectRecentSearch(search)
                    }) {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(search)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
    
    private var popularSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular Searches")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(viewModel.searchSuggestions, id: \.self) { suggestion in
                    Button(action: {
                        viewModel.searchText = suggestion
                        viewModel.performSearch()
                    }) {
                        Text(suggestion)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.arkadGold.opacity(0.1))
                            .foregroundColor(.arkadGold)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if selectedTab == 0 || selectedTab == 2 {
                    // User results
                    ForEach(viewModel.userResults) { user in
                        SearchUserRowView(user: user) { action in
                            switch action {
                            case .follow:
                                viewModel.followUser(user)
                            case .unfollow:
                                viewModel.unfollowUser(user)
                            case .message:
                                // Navigate to messaging
                                break
                            case .profile:
                                // Navigate to profile
                                break
                            }
                        }
                    }
                }
                
                if selectedTab == 1 || selectedTab == 2 {
                    // Post results (implement when needed)
                    Text("Post search coming soon")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .padding()
        }
    }
}

// MARK: - Search User Action
enum SearchUserAction {
    case follow, unfollow, message, profile
}

// MARK: - Search User Row View
struct SearchUserRowView: View {
    let user: User
    let onAction: (SearchUserAction) -> Void
    @State private var isFollowing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            Circle()
                .fill(Color.arkadGold.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(userInitials)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.fullName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.arkadGold)
                            .font(.caption)
                    }
                }
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Button(action: {
                    isFollowing.toggle()
                    onAction(isFollowing ? .follow : .unfollow)
                }) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(isFollowing ? Color.gray.opacity(0.2) : Color.arkadGold)
                        .foregroundColor(isFollowing ? .primary : .arkadBlack)
                        .cornerRadius(16)
                }
                
                Button(action: { onAction(.message) }) {
                    Image(systemName: "message")
                        .font(.caption)
                        .foregroundColor(.arkadGold)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var userInitials: String {
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return String(firstInitial) + String(lastInitial)
    }
}

// File: Core/Messaging/Views/MessagingView.swift

struct MessagingView: View {
    @StateObject private var viewModel = MessagingViewModel()
    @State private var showingNewMessage = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.conversations.isEmpty {
                    EmptyMessagesView()
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewMessage = true }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.arkadGold)
                    }
                }
            }
            .sheet(isPresented: $showingNewMessage) {
                NewMessageView { user in
                    viewModel.startConversation(with: user)
                    showingNewMessage = false
                }
            }
            .refreshable {
                viewModel.loadConversations()
            }
        }
    }
    
    private var conversationsList: some View {
        List(viewModel.conversations) { conversation in
            NavigationLink(destination: ChatView(conversation: conversation)) {
                ConversationRowView(conversation: conversation)
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct EmptyMessagesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Messages Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            Text("Start a conversation with other traders to share insights and tips")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SearchView()
}

#Preview {
    MessagingView()
}