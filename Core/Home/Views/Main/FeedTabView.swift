// File: Core/Home/Views/Main/FeedTabView.swift
// Simplified FeedTabView that works

import SwiftUI

struct FeedTabView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var scrollToTopId = UUID()
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Scroll to top anchor
                    Color.clear
                        .frame(height: 1)
                        .id(scrollToTopId)
                    
                    if homeViewModel.isLoading && homeViewModel.posts.isEmpty {
                        SimpleLoadingView(message: "Loading feed...")
                            .padding(.top, 50)
                    } else if homeViewModel.filteredPosts.isEmpty {
                        EmptyFeedView()
                            .padding(.top, 50)
                    } else {
                        // Posts
                        ForEach(homeViewModel.filteredPosts, id: \.id) { post in
                            PostCard(post: post)
                                .environmentObject(authService)
                                .environmentObject(homeViewModel)
                                .padding(.horizontal)
                        }
                        
                        // Load more button
                        if homeViewModel.hasMorePosts {
                            SimpleLoadMoreButton {
                                Task {
                                    await homeViewModel.loadMorePosts()
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        
                        // Loading more indicator
                        if homeViewModel.isLoadingMore {
                            SimpleLoadingView(message: "Loading more...")
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 100) // Space for tab bar
            }
            .refreshable {
                await homeViewModel.refreshFeed()
            }
            .onChange(of: scrollToTopId) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(scrollToTopId, anchor: .top)
                }
            }
        }
    }
}

// MARK: - Empty Feed View
struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "house")
                .font(.system(size: 50))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            Text("Welcome to Arkad")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start following other traders to see their posts in your feed.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Discover Users") {
                // TODO: Navigate to search/discover
            }
            .foregroundColor(.arkadGold)
            .fontWeight(.semibold)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.arkadGold.opacity(0.1))
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity)
    }
}
