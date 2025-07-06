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

#Preview {
    HomeView()
        .environmentObject(FirebaseAuthService.shared)
}

