// File: Core/Profile/Views/OtherUserProfileView.swift
// Another trader's profile: hero, follow button, stats, public performance and their
// posts, public trades and communities. Presented as a sheet.

import SwiftUI

struct OtherUserProfileView: View {
    let user: User
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var postsViewModel = UserPostsViewModel()
    @StateObject private var groupsViewModel = UserGroupsViewModel()

    @State private var selectedTab: ProfileTab = .posts
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    @State private var userTrades: [Trade] = []
    @State private var isLoadingTrades = true
    @Environment(\.dismiss) var dismiss

    private var isCurrentUser: Bool {
        user.id == authService.currentUser?.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                topBar

                ProfileHeroView(user: user) {
                    if !isCurrentUser {
                        SimpleFollowButton(
                            targetUserId: user.id,
                            targetUsername: user.username,
                            layout: .pill
                        )
                    }
                }

                statsSection

                OtherUserPortfolioBanner(
                    portfolioSummary: calculatePortfolioSummary(),
                    isLoading: isLoadingTrades
                )

                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    SegmentedPicker(options: ProfileTab.allCases, selection: $selectedTab) { tab in
                        tab.title
                    }

                    OtherUserContent(
                        selectedTab: selectedTab,
                        user: user,
                        userTrades: userTrades,
                        isLoadingTrades: isLoadingTrades,
                        postsViewModel: postsViewModel,
                        groupsViewModel: groupsViewModel
                    )
                    .transition(.opacity)
                    .id(selectedTab)
                }
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .screenBackground()
        .refreshable {
            await refreshUserData()
        }
        .sheet(isPresented: $showFollowersList) {
            SimpleFollowListView(userId: user.id, listType: .followers)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showFollowingList) {
            SimpleFollowListView(userId: user.id, listType: .following)
                .environmentObject(authService)
        }
        .onAppear {
            Task {
                await loadUserData()
            }
        }
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            IconButton(systemName: "xmark", accessibilityLabel: "Close", size: 36) {
                dismiss()
            }
            Spacer()
        }
        .padding(.top, DS.Spacing.l)
    }

    private var statsSection: some View {
        let summary = calculatePortfolioSummary()
        let hasClosedTrades = userTrades.contains { !$0.isOpen }
        return ProfileStatsCard(items: [
            ProfileStatItem(
                title: "Followers",
                value: "\(user.followersCount)",
                action: { showFollowersList = true }
            ),
            ProfileStatItem(
                title: "Following",
                value: "\(user.followingCount)",
                action: { showFollowingList = true }
            ),
            ProfileStatItem(title: "Trades", value: isLoadingTrades ? "–" : "\(summary.totalTrades)"),
            ProfileStatItem(
                title: "Win rate",
                value: hasClosedTrades ? String(format: "%.0f%%", summary.winRate) : "—"
            )
        ])
    }

    // MARK: - Data Loading

    private func loadUserData() async {
        // Posts and groups load in their own tasks; trades load here.
        postsViewModel.loadUserPosts(userId: user.id)
        groupsViewModel.loadUserGroups(userId: user.id)
        await loadUserTrades()
    }

    private func refreshUserData() async {
        await postsViewModel.refreshPosts()
        await groupsViewModel.refreshGroups()
        await loadUserTrades()
    }

    private func loadUserTrades() async {
        isLoadingTrades = true

        do {
            let trades = try await authService.getUserTrades(userId: user.id)
            // Only show public trades for other users
            userTrades = trades.filter { $0.isPublic == true }
        } catch {
            print("Error loading user trades: \(error)")
            userTrades = []
        }

        isLoadingTrades = false
    }

    private func calculatePortfolioSummary() -> PortfolioSummary {
        let closedTrades = userTrades.filter { !$0.isOpen }
        let totalProfitLoss = closedTrades.reduce(0) { $0 + $1.profitLoss }
        let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
        let winRate = closedTrades.isEmpty ? 0.0 : Double(winningTrades) / Double(closedTrades.count) * 100

        return PortfolioSummary(
            totalValue: user.totalProfitLoss,
            totalProfitLoss: totalProfitLoss,
            dayProfitLoss: 0.0, // Not available for other users
            winRate: winRate,
            totalTrades: userTrades.count,
            openPositions: userTrades.filter { $0.isOpen }.count,
            recentTrades: Array(userTrades.prefix(5)),
            topPerformer: userTrades.max(by: { $0.profitLoss < $1.profitLoss }),
            lastUpdated: Date()
        )
    }
}

// MARK: - Public Performance Card

struct OtherUserPortfolioBanner: View {
    let portfolioSummary: PortfolioSummary
    var isLoading: Bool = false

    private var hasClosedTrades: Bool {
        portfolioSummary.totalTrades > portfolioSummary.openPositions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack {
                Text("Performance")
                    .font(.headline)
                Spacer()
                Tag(text: "Public trades only", systemImage: "eye", tint: .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Realized P&L")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if isLoading {
                    ProgressView()
                        .tint(Color.goldText)
                        .frame(height: 38)
                } else {
                    Text(hasClosedTrades ? portfolioSummary.totalProfitLoss.asCurrencyWithSign : "—")
                        .arkadNumber(32)
                        .foregroundStyle(
                            hasClosedTrades
                                ? ProfilePerformanceCard.color(for: portfolioSummary.totalProfitLoss)
                                : Color.secondary
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }

            HStack(alignment: .top, spacing: DS.Spacing.m) {
                metric("Public trades", isLoading ? "–" : "\(portfolioSummary.totalTrades)")
                metric("Open", isLoading ? "–" : "\(portfolioSummary.openPositions)")
                metric("Closed", isLoading ? "–" : "\(portfolioSummary.totalTrades - portfolioSummary.openPositions)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .arkadNumber(15, weight: .semibold)
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Other User Tab Content

struct OtherUserContent: View {
    let selectedTab: ProfileTab
    let user: User
    let userTrades: [Trade]
    var isLoadingTrades: Bool = false
    @ObservedObject var postsViewModel: UserPostsViewModel
    @ObservedObject var groupsViewModel: UserGroupsViewModel

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.m),
        GridItem(.flexible(), spacing: DS.Spacing.m)
    ]

    private var firstName: String {
        let name = user.fullName.split(separator: " ").first.map(String.init) ?? ""
        return name.isEmpty ? "@\(user.username)" : name
    }

    var body: some View {
        switch selectedTab {
        case .posts:
            postsContent
        case .trades:
            tradesContent
        case .groups:
            groupsContent
        }
    }

    @ViewBuilder
    private var postsContent: some View {
        if postsViewModel.isLoading && postsViewModel.posts.isEmpty {
            ProfileTabLoadingCard(message: "Loading posts…")
        } else if postsViewModel.posts.isEmpty {
            ProfileEmptyCard(
                systemImage: "text.bubble",
                title: "No posts yet",
                message: "\(firstName) hasn't shared any posts yet."
            )
        } else {
            LazyVStack(spacing: DS.Spacing.m) {
                ForEach(postsViewModel.posts) { post in
                    OtherUserPostCard(post: post)
                }
            }
        }
    }

    @ViewBuilder
    private var tradesContent: some View {
        if isLoadingTrades && userTrades.isEmpty {
            ProfileTabLoadingCard(message: "Loading trades…")
        } else if userTrades.isEmpty {
            ProfileEmptyCard(
                systemImage: "chart.line.uptrend.xyaxis",
                title: "No public trades",
                message: "\(firstName) hasn't shared any public trades yet."
            )
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                SectionHeader(title: "Public trades", count: userTrades.count)
                VStack(spacing: 0) {
                    ForEach(Array(userTrades.enumerated()), id: \.element.id) { index, trade in
                        if index > 0 { ProfileRowDivider() }
                        ProfileUserTradeCard(trade: trade)
                    }
                }
                .cardStyle(padding: 0)
            }
        }
    }

    @ViewBuilder
    private var groupsContent: some View {
        if groupsViewModel.isLoading && groupsViewModel.groups.isEmpty {
            ProfileTabLoadingCard(message: "Loading communities…")
        } else if groupsViewModel.groups.isEmpty {
            ProfileEmptyCard(
                systemImage: "person.3.fill",
                title: "No communities",
                message: "\(firstName) hasn't joined any public communities yet."
            )
        } else {
            LazyVGrid(columns: columns, spacing: DS.Spacing.m) {
                ForEach(groupsViewModel.groups) { group in
                    ProfileUserGroupCard(group: group)
                }
            }
        }
    }
}

// MARK: - Other User Post Card

/// Read-only post card (no delete) for another user's profile.
struct OtherUserPostCard: View {
    let post: Post

    var body: some View {
        ProfilePostCardContent(post: post)
    }
}

#Preview {
    // Create a sample user for preview
    let sampleUser = User(
        id: "sample_id",
        email: "sample@example.com",
        username: "sampleuser",
        fullName: "Sample User"
    )

    OtherUserProfileView(user: sampleUser)
        .environmentObject(FirebaseAuthService.shared)
}
