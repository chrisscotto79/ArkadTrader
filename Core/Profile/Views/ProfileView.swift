// File: Core/Profile/Views/ProfileView.swift
// The signed-in user's profile: header, hero, stats, callout record, portfolio performance
// and tabbed content.

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var postsViewModel = UserPostsViewModel()
    @StateObject private var groupsViewModel = UserGroupsViewModel()

    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var selectedTab: ProfileTab = .posts
    @State private var showPortfolioDetails = false
    @State private var showFollowersList = false
    @State private var showFollowingList = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Profile") {
                    IconButton(systemName: "gearshape", accessibilityLabel: "Settings") {
                        showSettings = true
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    heroSection
                    statsSection
                    trackRecordSection
                    performanceSection

                    VStack(alignment: .leading, spacing: DS.Spacing.l) {
                        SegmentedPicker(options: ProfileTab.allCases, selection: $selectedTab) { tab in
                            tab.title
                        }

                        ProfileTabContent(
                            selectedTab: selectedTab,
                            portfolioViewModel: portfolioViewModel,
                            postsViewModel: postsViewModel,
                            groupsViewModel: groupsViewModel
                        )
                        .transition(.opacity)
                        .id(selectedTab)
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xxl)
            }
        }
        .screenBackground()
        .refreshable {
            await refreshProfile()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showPortfolioDetails) {
            PortfolioDetailsSheet()
                .environmentObject(portfolioViewModel)
        }
        .sheet(isPresented: $showFollowersList) {
            SimpleFollowListView(userId: authService.currentUser?.id ?? "", listType: .followers)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showFollowingList) {
            SimpleFollowListView(userId: authService.currentUser?.id ?? "", listType: .following)
                .environmentObject(authService)
        }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
            postsViewModel.loadUserPosts(userId: authService.currentUser?.id ?? "")
            groupsViewModel.loadUserGroups(userId: authService.currentUser?.id ?? "")
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        ProfileHeroView(user: authService.currentUser) {
            Button {
                showEditProfile = true
            } label: {
                Label("Edit profile", systemImage: "pencil")
            }
            .buttonStyle(PillButtonStyle(kind: .neutral))
        }
    }

    private var statsSection: some View {
        let summary = portfolioViewModel.getPortfolioSummaryForProfile()
        return ProfileStatsCard(items: [
            ProfileStatItem(
                title: "Followers",
                value: "\(authService.currentUser?.followersCount ?? 0)",
                action: { showFollowersList = true }
            ),
            ProfileStatItem(
                title: "Following",
                value: "\(authService.currentUser?.followingCount ?? 0)",
                action: { showFollowingList = true }
            ),
            ProfileStatItem(title: "Trades", value: "\(summary.totalTrades)"),
            // Portfolio win rate from price-checked and verified trades; the callout win rate is in
            // the callout record below
            ProfileStatItem(title: "Trade win rate", value: winRateText(summary.winRate))
        ])
    }

    /// Verified: built from the callouts you've posted in communities.
    @ViewBuilder
    private var trackRecordSection: some View {
        if let userId = authService.currentUser?.id {
            TrackRecordCard(userId: userId)
        }
    }

    /// Built from the trades you log in your portfolio, counting only price-checked and verified ones.
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            ProfileSourceLabel(title: "Portfolio", detail: "Price-checked & verified trades")
            ProfilePerformanceCard(
                summary: portfolioViewModel.getPortfolioSummaryForProfile(),
                bestTrade: bestClosedTrade
            ) {
                showPortfolioDetails = true
            }
        }
    }

    // MARK: - Helpers

    /// Win rate only counts closed price-checked and verified trades
    private var hasClosedTrades: Bool {
        portfolioViewModel.checkedStats.hasClosedTrades
    }

    /// Win rate only means something once a trade has been closed.
    private func winRateText(_ winRate: Double) -> String {
        hasClosedTrades ? String(format: "%.0f%%", winRate) : "—"
    }

    private var bestClosedTrade: Trade? {
        portfolioViewModel.trades
            .filter { !$0.isOpen && $0.countsTowardStats }
            .max(by: { $0.profitLoss < $1.profitLoss })
    }

    @MainActor
    private func refreshProfile() async {
        // Refresh the current user data from Firebase
        await authService.refreshCurrentUser()

        // Refresh other profile data
        portfolioViewModel.refreshPortfolio()
        await postsViewModel.refreshPosts()
        await groupsViewModel.refreshGroups()
    }
}

#Preview {
    ProfileView()
        .environmentObject(FirebaseAuthService.shared)
        .environmentObject(TabRouter())
}
