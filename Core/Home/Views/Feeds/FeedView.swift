// File: Core/Home/Views/Feeds/FeedView.swift
// Updated to show main social feed (all posts from all users)

import SwiftUI

struct FeedView: View {
    @StateObject private var homeViewModel = HomeViewModel()
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var showCreatePost = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                if homeViewModel.isLoading {
                    EnhancedLoadingView(message: "Loading latest posts...")
                } else if homeViewModel.posts.isEmpty {
                    EnhancedEmptyFeedView {
                        withAnimation(.spring()) {
                            showCreatePost = true
                        }
                    }
                } else {
                    // Welcome banner for new users
                    if homeViewModel.posts.count < 5 {
                        WelcomeBanner()
                    }
                    
                    ForEach(homeViewModel.posts, id: \.id) { post in
                        UserPostCard(post: post, homeViewModel: homeViewModel)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            ))
                    }
                    
                    // Load more indicator
                    if homeViewModel.hasMorePosts && !homeViewModel.isLoadingMore {
                        LoadMoreButton {
                            Task {
                                await homeViewModel.loadMorePosts()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80) // Space for tab bar
        }
        .refreshable {
            await homeViewModel.refreshPosts()
        }
        .onAppear {
            Task {
                await homeViewModel.loadPosts()
            }
        }
        .alert("Error", isPresented: $homeViewModel.showError) {
            Button("OK") { homeViewModel.showError = false }
        } message: {
            Text(homeViewModel.errorMessage)
        }
    }
}

#Preview {
    FeedView()
        .environmentObject(FirebaseAuthService.shared)
}
