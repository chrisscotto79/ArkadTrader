// File: Core/Home/Views/Main/FollowingTabView.swift
// Simplified FollowingTabView that works

import SwiftUI

struct FollowingTabView: View {
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
                    
                    if homeViewModel.isLoadingFollowing && homeViewModel.followingPosts.isEmpty {
                        SimpleLoadingView(message: "Loading following feed...")
                            .padding(.top, 50)
                    } else if homeViewModel.followingPosts.isEmpty {
                        EmptyFollowingView()
                            .padding(.top, 30)
                    } else {
                        // Following posts
                        ForEach(homeViewModel.followingPosts, id: \.id) { post in
                            PostCard(post: post)
                                .environmentObject(authService)
                                .environmentObject(homeViewModel)
                                .padding(.horizontal)
                        }
                        
                        // Following activities (if any)
                        if !homeViewModel.followingActivities.isEmpty {
                            LazyVStack(spacing: 12) {
                                ForEach(homeViewModel.followingActivities, id: \.id) { activity in
                                    ActivityCardView(activity: activity)
                                        .environmentObject(homeViewModel)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Load more button
                        if homeViewModel.hasMoreFollowingPosts {
                            SimpleLoadMoreButton {
                                Task {
                                    await homeViewModel.loadMoreFollowingPosts()
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
                await homeViewModel.refreshFollowingFeed()
            }
            .onChange(of: scrollToTopId) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(scrollToTopId, anchor: .top)
                }
            }
        }
    }
}
