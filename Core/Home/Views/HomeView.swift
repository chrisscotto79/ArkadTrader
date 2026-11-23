// File: Core/Home/Views/HomeView.swift
// The Home tab: Arkad header with the Learn button, notifications bell and compose button,
// For You / Following / News, and the feed. The feed starts with a dismissible "Keep learning"
// card (HomeLearnCard). Learn opens in this NavigationStack; Discover keeps its own entry.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject private var tabRouter: TabRouter
    @ObservedObject private var pushManager = PushNotificationManager.shared
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var followingViewModel = FollowingFeedViewModel()
    @ObservedObject private var postStore = PostStore.shared
    @ObservedObject private var blockStore = BlockStore.shared
    @State private var selectedTab: HomeFeedTab = .feed
    @State private var showCreatePost = false
    @State private var showNotifications = false
    @State private var showLearn = false
    @State private var linkedPost: LinkedPost?

    /// A post opened from a notification
    private struct LinkedPost: Identifiable {
        let id: String
    }

    enum HomeFeedTab: CaseIterable, Hashable {
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

                ScrollView {
                    contentForSelectedTab
                        .padding(.top, DS.Spacing.s)
                        .padding(.bottom, DS.Spacing.xl)
                }
                .refreshable { await refreshContent() }
            }
            .screenBackground()
            .statusBarBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showLearn) { LearnHubView() }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView { draft in
                try await homeViewModel.createPost(draft)
            }
            .environmentObject(authService)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsInboxView()
                .environmentObject(authService)
        }
        .sheet(item: $linkedPost) { post in
            CommentsView(postId: post.id)
                .environmentObject(authService)
        }
        .onAppear { openLinkedPost(tabRouter.pendingDeepLink) }
        .onChange(of: tabRouter.pendingDeepLink) { _, link in
            openLinkedPost(link)
        }
        .task {
            if homeViewModel.posts.isEmpty {
                await homeViewModel.loadPosts()
            }
        }
        .postStoreFeedback()
        .alert("Something went wrong", isPresented: $homeViewModel.showError) {
            Button("OK") { homeViewModel.showError = false }
        } message: {
            Text(homeViewModel.errorMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.m) {
                ArkadLogo(height: 26)
                Spacer(minLength: 0)
                IconButton(systemName: "book", accessibilityLabel: "Learn") {
                    showLearn = true
                }
                notificationsButton
                IconButton(systemName: "square.and.pencil", accessibilityLabel: "New post", filled: true) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showCreatePost = true
                }
            }

            SegmentedPicker(options: HomeFeedTab.allCases, selection: $selectedTab) { $0.title }
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.top, DS.Spacing.s)
        .padding(.bottom, DS.Spacing.s)
    }

    private var notificationsButton: some View {
        let unread = pushManager.unreadCount
        return IconButton(
            systemName: "bell",
            accessibilityLabel: unread > 0 ? "Notifications, \(unread) unread" : "Notifications"
        ) {
            showNotifications = true
        }
        .overlay(alignment: .topTrailing) {
            if unread > 0 {
                Text(unread >= PushNotificationManager.unreadLimit ? "\(PushNotificationManager.unreadLimit)+" : "\(unread)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.onGold)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Capsule().fill(Color.arkadGold))
                    .overlay(Capsule().strokeBorder(Color.appBackground, lineWidth: 2))
                    .offset(x: 5, y: -4)
                    .accessibilityHidden(true)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.2), value: unread > 0)
    }

    /// Notifications about a post (replies, likes, mentions) open its comments.
    private func openLinkedPost(_ link: DeepLink?) {
        guard case .post(let postId) = link else { return }
        tabRouter.pendingDeepLink = nil
        guard showNotifications else {
            linkedPost = LinkedPost(id: postId)
            return
        }
        // A push was tapped while the inbox is open: close it first, then show the post.
        showNotifications = false
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            linkedPost = LinkedPost(id: postId)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentForSelectedTab: some View {
        switch selectedTab {
        case .feed:
            feedContent
                .transition(.opacity)
        case .following:
            FollowingFeedView(viewModel: followingViewModel)
                .environmentObject(authService)
                .transition(.opacity)
        case .marketNews:
            MarketNewsFeedView(homeViewModel: homeViewModel)
                .transition(.opacity)
        }
    }

    private var feedContent: some View {
        let visiblePosts = postStore.visible(homeViewModel.posts)

        return LazyVStack(spacing: DS.Spacing.m) {
            HomeLearnCard()

            if homeViewModel.isLoading && homeViewModel.posts.isEmpty {
                HomeFeedLoadingView(message: "Loading posts…")
            } else if let loadError = homeViewModel.loadError, homeViewModel.posts.isEmpty {
                EmptyStateView(
                    systemImage: "wifi.exclamationmark",
                    title: "Couldn't load posts",
                    message: loadError,
                    actionTitle: "Try again"
                ) {
                    Task { await homeViewModel.loadPosts() }
                }
            } else if visiblePosts.isEmpty && !homeViewModel.hasMorePosts {
                EmptyStateView(
                    systemImage: "text.bubble.fill",
                    title: "No posts yet",
                    message: "Be the first to share a trade, a chart or a market take.",
                    actionTitle: "Write a post"
                ) {
                    showCreatePost = true
                }
            } else {
                if let loadError = homeViewModel.loadError {
                    Label(loadError, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(visiblePosts, id: \.id) { post in
                    UserPostCard(post: post)
                }

                feedFooter
            }
        }
        .padding(.horizontal, DS.pageMargin)
    }

    @ViewBuilder
    private var feedFooter: some View {
        if homeViewModel.isLoadingMore {
            ProgressView()
                .padding(.vertical, DS.Spacing.l)
        } else if let error = homeViewModel.loadMoreError {
            VStack(spacing: DS.Spacing.s) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try again") {
                    Task { await homeViewModel.loadMorePosts() }
                }
                .buttonStyle(PillButtonStyle(kind: .neutral))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.l)
        } else if homeViewModel.hasMorePosts {
            Button {
                Task { await homeViewModel.loadMorePosts() }
            } label: {
                Label("Load more", systemImage: "arrow.down")
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, DS.Spacing.xs)
        }
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

#Preview {
    HomeView()
        .environmentObject(FirebaseAuthService.shared)
        .environmentObject(TabRouter())
}
