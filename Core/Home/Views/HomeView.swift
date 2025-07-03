// File: Core/Home/Views/HomeView.swift
// Updated HomeView with Firebase integration

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct HomeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var selectedTab = 0 // 0 = Feed, 1 = News
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Feed/News Toggle
                HStack(spacing: 0) {
                    Button(action: { selectedTab = 0 }) {
                        Text("Feed")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == 0 ? Color.arkadGold : Color.clear)
                            .foregroundColor(selectedTab == 0 ? .arkadBlack : .gray)
                    }
                    
                    Button(action: { selectedTab = 1 }) {
                        Text("News")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == 1 ? Color.arkadGold : Color.clear)
                            .foregroundColor(selectedTab == 1 ? .arkadBlack : .gray)
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Content based on selection
                if selectedTab == 0 {
                    // Social Feed
                    SocialFeedView()
                        .environmentObject(homeViewModel)
                } else {
                    // Market News Feed
                    MarketNewsFeedView()
                }
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    AsyncImage(url: URL(string: "https://arkadwealthgroup.com/wp-content/uploads/2025/01/ARKAD_BLACK.png")) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        HStack(spacing: 2) {
                            Text("ARKAD")
                                .font(.headline)
                                .fontWeight(.black)
                                .foregroundColor(.arkadGold)
                            Text("TRADER")
                                .font(.headline)
                                .fontWeight(.thin)
                                .foregroundColor(.arkadBlack)
                        }
                    }
                    .frame(height: 32)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.marketGreen)
                            .font(.title2)
                        Text("Bullish")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.marketGreen)
                    }
                }
            }
        }
    }
}

// File: Core/Home/Views/SocialFeedView.swift
// Updated SocialFeedView with Firebase integration

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct SocialFeedView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var showCreatePost = false
    
    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if homeViewModel.isLoading {
                        ProgressView("Loading posts...")
                            .padding(.top, 40)
                    } else if homeViewModel.posts.isEmpty {
                        EmptyFeedView()
                    } else {
                        ForEach(homeViewModel.posts, id: \.id) { post in
                            SocialPostCard(post: post)
                                .environmentObject(homeViewModel)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 100) // Space for floating button
            }
            .refreshable {
                homeViewModel.refreshPosts()
            }
            
            // Floating Create Post Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showCreatePost = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.arkadGold)
                            .clipShape(Circle())
                            .shadow(color: .arkadGold.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView()
                .environmentObject(homeViewModel)
        }
        .alert("Error", isPresented: $homeViewModel.showError) {
            Button("OK") { }
        } message: {
            Text(homeViewModel.errorMessage)
        }
    }
}

struct SocialPostCard: View {
    let post: Post
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var isLiked = false
    @State private var showComments = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.arkadGold.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(post.authorUsername.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.arkadGold)
                    )
                
                VStack(alignment: .leading) {
                    Text(post.authorUsername)
                        .fontWeight(.semibold)
                    Text(post.timeAgoString)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                }
            }
            
            Text(post.content)
                .font(.body)
            
            HStack(spacing: 16) {
                Button(action: {
                    isLiked.toggle()
                    homeViewModel.likePost(post)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                        Text("\(post.likesCount + (isLiked ? 1 : 0))")
                    }
                    .font(.caption)
                }
                
                Button(action: { showComments = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                        Text("\(post.commentsCount)")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 1)
    }
}

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Posts Yet")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            Text("Be the first to share your trading insights!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
}

struct CreatePostView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var postContent = ""
    @State private var isPosting = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("What's on your mind?", text: $postContent, axis: .vertical)
                    .lineLimit(5...15)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        createPost()
                    }
                    .disabled(postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                    .foregroundColor(.arkadGold)
                }
            }
        }
    }
    
    private func createPost() {
        isPosting = true
        homeViewModel.createPost(content: postContent)
        dismiss()
    }
}

// File: Core/Search/Views/SearchView.swift
// Updated SearchView with Firebase integration

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct SearchView: View {
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var selectedSearchType = 0 // 0 = Users, 1 = Tickers, 2 = Posts
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search users, stocks, or traders...", text: $searchViewModel.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            searchViewModel.performSearch()
                        }
                    
                    if !searchViewModel.searchText.isEmpty {
                        Button(action: {
                            searchViewModel.searchText = ""
                            searchViewModel.clearSearchResults()
                        }) {
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
                
                // Search Type Selector
                Picker("Search Type", selection: $selectedSearchType) {
                    Text("Users").tag(0)
                    Text("Tickers").tag(1)
                    Text("Posts").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Search Results or Trending
                if searchViewModel.searchText.isEmpty {
                    // Show trending when no search
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Recent Searches
                            if !searchViewModel.recentSearches.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Recent Searches")
                                            .font(.headline)
                                            .padding(.horizontal)
                                        
                                        Spacer()
                                        
                                        Button("Clear") {
                                            searchViewModel.clearRecentSearches()
                                        }
                                        .font(.caption)
                                        .foregroundColor(.arkadGold)
                                        .padding(.horizontal)
                                    }
                                    
                                    ForEach(searchViewModel.recentSearches.prefix(5), id: \.self) { search in
                                        Button(action: {
                                            searchViewModel.searchText = search
                                            searchViewModel.performSearch()
                                        }) {
                                            HStack {
                                                Image(systemName: "clock")
                                                    .foregroundColor(.gray)
                                                Text(search)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                        }
                                    }
                                }
                            }
                            
                            // Popular Searches
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Popular")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(searchViewModel.getPopularSearches(), id: \.self) { ticker in
                                    TrendingStockRow(ticker: ticker)
                                }
                            }
                        }
                        .padding(.top)
                    }
                } else {
                    // Show search results
                    if searchViewModel.isSearching {
                        ProgressView("Searching...")
                            .padding(.top, 40)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(searchViewModel.searchResults, id: \.id) { result in
                                    SearchResultRow(result: result)
                                }
                                
                                if searchViewModel.searchResults.isEmpty {
                                    Text("No results found")
                                        .foregroundColor(.gray)
                                        .padding(.top, 40)
                                }
                            }
                            .padding(.top)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: searchViewModel.searchText) { _, newValue in
                if !newValue.isEmpty {
                    searchViewModel.performSearch()
                }
            }
        }
    }
}

struct TrendingStockRow: View {
    let ticker: String
    
    var body: some View {
        HStack {
            Text(ticker)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Mock price change
            Text("+\(Int.random(in: 1...5)).\(Int.random(in: 0...99))%")
                .font(.subheadline)
                .foregroundColor(.marketGreen)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2)
        .padding(.horizontal)
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    @State private var isFollowing = false
    
    var body: some View {
        HStack {
            if let user = result.user {
                Circle()
                    .fill(Color.arkadGold.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(user.initials)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.arkadGold)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: { isFollowing.toggle() }) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isFollowing ? Color.gray.opacity(0.2) : Color.arkadGold)
                        .foregroundColor(isFollowing ? .primary : .arkadBlack)
                        .cornerRadius(16)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    HomeView()
        .environmentObject(FirebaseAuthService.shared)
}
