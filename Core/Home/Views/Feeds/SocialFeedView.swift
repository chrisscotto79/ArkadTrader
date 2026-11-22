// File: Core/Home/Views/SocialFeedView.swift
// Enhanced Social Feed View with Clickable Usernames

import SwiftUI

struct SocialFeedView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var showCreatePost = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Feed content
                feedContent
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView { content, tickers, images in
                Task {
                    await homeViewModel.createPost(content: content, tickers: tickers, images: images)
                }
            }
            .environmentObject(authService) // Pass environment object to sheets
        }
        .onAppear {
            Task {
                await homeViewModel.loadPosts()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("Social Feed")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: { showCreatePost = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.arkadGold)
            }
        }
        .padding()
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Feed Content
    private var feedContent: some View {
        Group {
            if homeViewModel.isLoading {
                LoadingView()
            } else if homeViewModel.posts.isEmpty {
                EmptyFeedView {
                    showCreatePost = true
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(homeViewModel.posts, id: \.id) { post in
                            // ENHANCED: Explicitly pass environment object and add debug info
                            UserPostCard(post: post, homeViewModel: homeViewModel)
                                .environmentObject(authService)
                        }
                        
                        // Load more indicator
                        if homeViewModel.hasMorePosts {
                            LoadMoreButton {
                                Task {
                                    await homeViewModel.loadMorePosts()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                .refreshable {
                    await homeViewModel.refreshPosts()
                }
            }
        }
    }
    
    // MARK: - Supporting Views
    
    struct LoadingView: View {
        var body: some View {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Loading posts...")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 100)
        }
    }
    
    struct LoadMoreButton: View {
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Text("Load More Posts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Image(systemName: "arrow.down.circle")
                        .font(.subheadline)
                }
                .foregroundColor(.arkadGold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.arkadGold.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Enhanced User Post Card with Debug Info


#Preview {
    SocialFeedView()
        .environmentObject(FirebaseAuthService.shared)
}
