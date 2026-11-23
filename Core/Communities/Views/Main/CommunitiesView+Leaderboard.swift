// File: Core/Communities/Views/Main/CommunitiesView+Leaderboard.swift
// The Leaderboard tab: your communities' boards, and the global board of every Arkad trader,
// all ranked by verified callout results.

import SwiftUI

// MARK: - Leaderboard Content
extension CommunitiesView {
    @ViewBuilder
    var leaderboardContent: some View {
        leaderboardModePicker

        switch selectedLeaderboardMode {
        case .communities:
            communityLeaderboardsContent
        case .globalTraders:
            globalTradersContent
        }
    }

    var leaderboardModePicker: some View {
        SegmentedPicker(
            options: LeaderboardMode.allCases,
            selection: leaderboardModeSelection,
            title: { $0.displayName }
        )
    }

    private var leaderboardModeSelection: Binding<LeaderboardMode> {
        Binding(
            get: { selectedLeaderboardMode },
            set: { mode in
                selectedLeaderboardMode = mode
                if mode == .globalTraders && !globalLeaderboardViewModel.hasLoaded {
                    Task { await globalLeaderboardViewModel.loadGlobalLeaderboard() }
                }
            }
        )
    }

    var communityLeaderboardsContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                SectionHeader(title: "Your communities", count: viewModel.userCommunities.count)
                Text("Each board ranks members by their closed callouts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            CommunityCardList(items: viewModel.userCommunities) { community in
                communityLeaderboardCard(community: community)
            }
        }
    }

    func communityLeaderboardCard(community: Community) -> some View {
        Button {
            navigateToLeaderboard(community)
        } label: {
            CommunityRowContent(community: community, subtitle: CommunityFormat.members(community.memberCount)) {
                HStack(spacing: DS.Spacing.s) {
                    Text("Rankings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.goldText)
                    CommunityChevron()
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(community.name) leaderboard")
    }

    var globalTradersContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: 2) {
                SectionHeader(title: "Top callers")
                Text("Traders on Arkad, ranked by the results of their callouts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LeaderboardFilterBar(category: $globalLeaderboardViewModel.category)

            globalTradersBody
        }
        .onChange(of: globalLeaderboardViewModel.category) { _, _ in globalLeaderboardViewModel.reload() }
        .onAppear {
            if !globalLeaderboardViewModel.hasLoaded && !globalLeaderboardViewModel.isLoading {
                Task { await globalLeaderboardViewModel.loadGlobalLeaderboard() }
            }
        }
        .sheet(item: $globalProfileUser) { user in
            OtherUserProfileView(user: user)
                .environmentObject(authService)
        }
    }

    @ViewBuilder
    private var globalTradersBody: some View {
        if globalLeaderboardViewModel.isLoading || !globalLeaderboardViewModel.hasLoaded {
            loadingView
        } else if !globalLeaderboardViewModel.errorMessage.isEmpty {
            errorView
        } else if globalLeaderboardViewModel.entries.isEmpty {
            noRankedCallersView
        } else {
            LeaderboardRankingList(
                entries: globalLeaderboardViewModel.entries,
                category: globalLeaderboardViewModel.category,
                currentUserId: authService.currentUser?.id,
                onSelect: { openGlobalProfile(userId: $0.userId) }
            )
        }
    }

    private var noRankedCallersView: some View {
        EmptyStateView(
            systemImage: "trophy.fill",
            title: "No rankings yet",
            message: "Rankings appear once traders have \(TraderStats.minimumClosedCallouts) closed callouts. Post callouts in a community to build your record."
        )
        .cardStyle(padding: 0)
    }

    func openGlobalProfile(userId: String) {
        guard userId != authService.currentUser?.id else {
            TabRouter.shared.open(.profile(userId: nil))
            return
        }
        Task { globalProfileUser = try? await authService.getUserById(userId: userId) }
    }
}
