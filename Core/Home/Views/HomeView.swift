// File: Core/Home/Views/HomeView.swift
// The Home tab: header with compose button, Feed / Following / News tabs, and the post list.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var followingViewModel = FollowingFeedViewModel()
    @State private var selectedTab: HomeFeedTab = .feed
    @State private var showCreatePost = false
    @Namespace private var tabUnderline

    enum HomeFeedTab: CaseIterable {
        case feed, following, marketNews

        var title: String {
            switch self {
            case .feed: return "For You"
            case .following: return "Following"
            case .marketNews: return "News"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                tabSelector
                Divider()

                ScrollView {
                    contentForSelectedTab
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                .refreshable { await refreshContent() }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView { draft in
                Task {
                    await homeViewModel.createPost(draft)
                }
            }
            .environmentObject(authService)
        }
        .task {
            if homeViewModel.posts.isEmpty {
                await homeViewModel.loadPosts()
            }
        }
        .alert("Something went wrong", isPresented: $homeViewModel.showError) {
            Button("OK") { homeViewModel.showError = false }
        } message: {
            Text(homeViewModel.errorMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image("arkad_logo")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 28)
                .accessibilityLabel("Arkad")

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showCreatePost = true
            } label: {
                Label("New Post", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.arkadGold))
            }
            .accessibilityHint("Write a post")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(.systemBackground))
    }

    // MARK: - Tabs

    private var tabSelector: some View {
        HStack(spacing: 24) {
            ForEach(HomeFeedTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.subheadline.weight(selectedTab == tab ? .bold : .medium))
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        ZStack {
                            Capsule().fill(Color.clear).frame(height: 3)
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.arkadGold)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(id: "underline", in: tabUnderline)
                            }
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Content

    @ViewBuilder
    private var contentForSelectedTab: some View {
        switch selectedTab {
        case .feed:
            feedContent
        case .following:
            FollowingFeedView(viewModel: followingViewModel, homeViewModel: homeViewModel)
                .environmentObject(authService)
        case .marketNews:
            MarketNewsFeedView(homeViewModel: homeViewModel)
        }
    }

    private var feedContent: some View {
        LazyVStack(spacing: 12) {
            if homeViewModel.isLoading && homeViewModel.posts.isEmpty {
                EnhancedLoadingView(message: "Loading posts…")
            } else if homeViewModel.posts.isEmpty {
                EnhancedEmptyFeedView { showCreatePost = true }
            } else {
                ForEach(homeViewModel.posts, id: \.id) { post in
                    UserPostCard(post: post, homeViewModel: homeViewModel)
                }

                if homeViewModel.hasMorePosts && !homeViewModel.isLoadingMore {
                    LoadMoreButton {
                        Task { await homeViewModel.loadMorePosts() }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    @MainActor
    private func refreshContent() async {
        switch selectedTab {
        case .feed:
            await homeViewModel.refreshPosts()
        case .following:
            await followingViewModel.refreshContent()
        case .marketNews:
            await homeViewModel.loadMarketNews()
        }
    }
}

struct EnhancedLoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .arkadGold))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

struct EnhancedEmptyFeedView: View {
    let onCreatePost: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.arkadGold.opacity(0.7))
                
                Text("No posts yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Be the first to share a trade, a chart or a market take.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: onCreatePost) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Write a Post")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.arkadBlack)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.arkadGold)
                .cornerRadius(25)
                .shadow(color: .arkadGold.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.vertical, 60)
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
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(FirebaseAuthService.shared)
        .environmentObject(TabRouter())
}
