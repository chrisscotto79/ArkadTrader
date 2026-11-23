// File: Core/Communities/Views/Main/CommunitiesView+EmptyStates.swift
// Empty, loading and error states for the Communities tabs.

import SwiftUI

extension CommunitiesView {
    var emptyMyCommunitiesState: some View {
        VStack(spacing: 0) {
            EmptyStateView(
                systemImage: "person.3.fill",
                title: "Find your trading crew",
                message: "Join a community to chat with other traders, follow trade callouts from experienced members and climb the leaderboard.",
                actionTitle: "Discover communities",
                action: goToDiscover
            )

            Button("Or start your own", action: showCreate)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.goldText)
                .padding(.bottom, DS.Spacing.xl)
                .padding(.top, -DS.Spacing.l)
        }
        .cardStyle(padding: 0)
    }

    var emptyLeaderboardState: some View {
        EmptyStateView(
            systemImage: "trophy.fill",
            title: "Join a community first",
            message: "Each community ranks its members by their closed trades. Join one to see where you stand, or check the global board.",
            actionTitle: "Discover communities",
            action: goToDiscover
        )
        .cardStyle(padding: 0)
    }

    var emptyGlobalTradersView: some View {
        EmptyStateView(
            systemImage: "globe.americas.fill",
            title: "No rankings yet",
            message: "The global board fills up as traders close trades. Close one in your portfolio to get on it."
        )
        .cardStyle(padding: 0)
    }

    var loadingView: some View {
        loadingCard(text: "Loading rankings…")
    }

    func loadingCard(text: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            ProgressView()
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .cardStyle(padding: DS.Spacing.l)
    }

    var errorView: some View {
        EmptyStateView(
            systemImage: "exclamationmark.triangle.fill",
            title: "Couldn't load rankings",
            message: globalLeaderboardViewModel.errorMessage,
            actionTitle: "Try again",
            action: {
                Task { await globalLeaderboardViewModel.refresh() }
            }
        )
        .cardStyle(padding: 0)
    }
}
