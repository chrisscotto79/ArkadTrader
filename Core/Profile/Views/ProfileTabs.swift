// File: Core/Profile/Views/ProfileTabs.swift
// Profile building blocks (hero, stats, performance, empty/loading cards) and the
// Posts, Trades and Communities tab contents of the signed-in user's profile.

import SwiftUI

// MARK: - Profile Tabs

enum ProfileTab: CaseIterable {
    case posts, trades, groups

    var title: String {
        switch self {
        case .posts: return "Posts"
        case .trades: return "Trades"
        case .groups: return "Communities"
        }
    }

    var icon: String {
        switch self {
        case .posts: return "square.and.pencil"
        case .trades: return "chart.line.uptrend.xyaxis"
        case .groups: return "person.3.fill"
        }
    }
}

// MARK: - Hero

/// Large avatar, name, @username, join date and bio, followed by the profile's actions.
struct ProfileHeroView<Actions: View>: View {
    let user: User?
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .center, spacing: DS.Spacing.l) {
                ProfileImageView(user: user, size: 88)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        if user?.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.headline)
                                .foregroundStyle(Color.goldText)
                                .accessibilityLabel("Verified")
                        }
                    }

                    if let username = user?.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let user {
                        Label(
                            "Joined \(user.createdAt.formatted(.dateTime.month(.wide).year()))",
                            systemImage: "calendar"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .labelStyle(ProfileCompactLabelStyle())
                    }
                }

                Spacer(minLength: 0)
            }

            if let bio = user?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actions()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayName: String {
        guard let user else { return "" }
        return user.fullName.isEmpty ? user.username : user.fullName
    }
}

// MARK: - Stats Row

struct ProfileStatItem {
    let title: String
    let value: String
    /// Tappable when set (followers / following lists)
    var action: (() -> Void)? = nil
}

/// Followers / following / trades / win rate in one card.
struct ProfileStatsCard: View {
    let items: [ProfileStatItem]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Color.hairline)
                        .frame(width: 1, height: 32)
                }
                statView(item)
            }
        }
        .padding(.vertical, DS.Spacing.m)
        .cardStyle(padding: 0)
    }

    @ViewBuilder
    private func statView(_ item: ProfileStatItem) -> some View {
        let label = VStack(spacing: 4) {
            Text(item.value)
                .arkadNumber(20)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(item.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(Rectangle())

        if let action = item.action {
            Button(action: action) { label }
                .buttonStyle(PressableStyle())
                .accessibilityElement(children: .combine)
                .accessibilityHint("Shows the list")
        } else {
            label
                .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Performance Card (own profile)

struct ProfilePerformanceCard: View {
    let summary: PortfolioSummary
    let bestTrade: Trade?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                HStack {
                    Text("Performance")
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Portfolio")
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.goldText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Total P&L · price-checked & verified")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(summary.totalProfitLoss.asCurrencyWithSign)
                        .arkadNumber(32)
                        .foregroundStyle(Self.color(for: summary.totalProfitLoss))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                HStack(alignment: .top, spacing: DS.Spacing.m) {
                    metric("Today", summary.dayProfitLoss.asCurrencyWithSign, Self.color(for: summary.dayProfitLoss))
                    metric("Open positions", "\(summary.openPositions)", .primary)
                    metric("Best trade", bestTrade?.profitLoss.asCurrencyWithSign ?? "—",
                           bestTrade.map { Self.color(for: $0.profitLoss) } ?? .secondary)
                }

                if summary.selfReportedTrades > 0 {
                    Label(
                        "\(summary.selfReportedTrades) self-reported trade\(summary.selfReportedTrades == 1 ? "" : "s") not counted.",
                        systemImage: TradeProof.selfReported.systemImage
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Opens your portfolio")
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .arkadNumber(15, weight: .semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func color(for value: Double) -> Color {
        if value > 0 { return .marketGreen }
        if value < 0 { return .marketRed }
        return .primary
    }
}

// MARK: - Loading / Empty Cards

struct ProfileTabLoadingCard: View {
    let message: String

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            ProgressView()
                .tint(Color.goldText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .cardStyle(padding: 0)
    }
}

struct ProfileEmptyCard: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        EmptyStateView(
            systemImage: systemImage,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
        .cardStyle(padding: 0)
    }
}

// MARK: - Portfolio Details Sheet

struct PortfolioDetailsSheet: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        // PortfolioView brings its own NavigationStack and header, so the sheet only adds a Done bar.
        PortfolioView()
            .environmentObject(portfolioViewModel)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.goldText)
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.m)
                .padding(.bottom, DS.Spacing.xs)
                .background(Color.appBackground)
            }
    }
}

// MARK: - Profile Tab Content

struct ProfileTabContent: View {
    let selectedTab: ProfileTab
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    @ObservedObject var postsViewModel: UserPostsViewModel
    @ObservedObject var groupsViewModel: UserGroupsViewModel

    var body: some View {
        switch selectedTab {
        case .posts:
            UserPostsTab(postsViewModel: postsViewModel)
        case .trades:
            UserTradesTab(portfolioViewModel: portfolioViewModel)
        case .groups:
            UserGroupsTab(groupsViewModel: groupsViewModel)
        }
    }
}

// MARK: - Posts Tab

struct UserPostsTab: View {
    @ObservedObject var postsViewModel: UserPostsViewModel
    @EnvironmentObject var tabRouter: TabRouter
    @State private var showAllPosts = false

    private var visiblePosts: [Post] {
        showAllPosts ? postsViewModel.posts : Array(postsViewModel.posts.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            if postsViewModel.isLoading && postsViewModel.posts.isEmpty {
                ProfileTabLoadingCard(message: "Loading posts…")
            } else if !postsViewModel.errorMessage.isEmpty {
                ProfileEmptyCard(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn't load posts",
                    message: postsViewModel.errorMessage,
                    actionTitle: "Try again"
                ) {
                    Task { await postsViewModel.refreshPosts() }
                }
            } else if postsViewModel.posts.isEmpty {
                // Posts are written from the Home tab's "New Post" button
                ProfileEmptyCard(
                    systemImage: "square.and.pencil",
                    title: "No posts yet",
                    message: "Share your trading insights and market thoughts with the community.",
                    actionTitle: "Write a post"
                ) {
                    tabRouter.selected = .home
                }
            } else {
                SectionHeader(
                    title: "Posts",
                    count: postsViewModel.posts.count,
                    actionTitle: postsViewModel.posts.count > 6 ? (showAllPosts ? "Show less" : "Show all") : nil
                ) {
                    withAnimation(.snappy(duration: 0.3)) { showAllPosts.toggle() }
                }

                LazyVStack(spacing: DS.Spacing.m) {
                    ForEach(visiblePosts, id: \.id) { post in
                        ProfileUserPostCard(
                            post: post,
                            onPostDeleted: {
                                Task {
                                    await postsViewModel.refreshPosts()
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Trades Tab

struct UserTradesTab: View {
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var tabRouter: TabRouter
    @State private var showAddTrade = false

    private var recentTrades: [Trade] {
        Array(portfolioViewModel.trades.prefix(10))
    }

    /// Best closed trades that count: price-checked and verified only
    private var topTrades: [Trade] {
        Array(
            portfolioViewModel.trades
                .filter { !$0.isOpen && $0.profitLoss > 0 && $0.countsTowardStats }
                .sorted { $0.profitLoss > $1.profitLoss }
                .prefix(5)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            if portfolioViewModel.isLoading && portfolioViewModel.trades.isEmpty {
                ProfileTabLoadingCard(message: "Loading trades…")
            } else if portfolioViewModel.trades.isEmpty {
                ProfileEmptyCard(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "No trades yet",
                    message: "Log your trades to track your performance and share results with the community.",
                    actionTitle: "Add your first trade"
                ) {
                    showAddTrade = true
                }
            } else {
                tradeList(
                    title: "Recent trades",
                    count: portfolioViewModel.trades.count,
                    trades: recentTrades,
                    actionTitle: "See all"
                ) {
                    tabRouter.selected = .portfolio
                }

                if !topTrades.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.m) {
                        SectionHeader(title: "Top trades")
                        VStack(spacing: 0) {
                            ForEach(Array(topTrades.enumerated()), id: \.element.id) { index, trade in
                                if index > 0 { ProfileRowDivider() }
                                TopPositionCard(trade: trade)
                            }
                        }
                        .cardStyle(padding: 0)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTrade) {
            AddTradeView()
                .environmentObject(authService)
                .environmentObject(portfolioViewModel)
        }
    }

    private func tradeList(
        title: String,
        count: Int,
        trades: [Trade],
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: title, count: count, actionTitle: actionTitle, action: action)
            VStack(spacing: 0) {
                ForEach(Array(trades.enumerated()), id: \.element.id) { index, trade in
                    if index > 0 { ProfileRowDivider() }
                    ProfileUserTradeCard(trade: trade)
                }
            }
            .cardStyle(padding: 0)
        }
    }
}

// MARK: - Communities Tab

struct UserGroupsTab: View {
    @ObservedObject var groupsViewModel: UserGroupsViewModel
    @EnvironmentObject var tabRouter: TabRouter

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.m),
        GridItem(.flexible(), spacing: DS.Spacing.m)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            if groupsViewModel.isLoading && groupsViewModel.groups.isEmpty {
                ProfileTabLoadingCard(message: "Loading communities…")
            } else if !groupsViewModel.errorMessage.isEmpty {
                ProfileEmptyCard(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn't load communities",
                    message: groupsViewModel.errorMessage,
                    actionTitle: "Try again"
                ) {
                    Task { await groupsViewModel.refreshGroups() }
                }
            } else if groupsViewModel.groups.isEmpty {
                ProfileEmptyCard(
                    systemImage: "person.3.fill",
                    title: "No communities yet",
                    message: "Join a trading community to learn with other traders and share ideas.",
                    actionTitle: "Discover communities"
                ) {
                    tabRouter.selected = .communities
                }
            } else {
                SectionHeader(
                    title: "Communities",
                    count: groupsViewModel.groups.count,
                    actionTitle: "Discover"
                ) {
                    tabRouter.selected = .communities
                }

                LazyVGrid(columns: columns, spacing: DS.Spacing.m) {
                    ForEach(groupsViewModel.groups, id: \.id) { group in
                        ProfileUserGroupCard(group: group)
                    }
                }
            }
        }
    }
}
