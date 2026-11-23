// File: Core/Home/Views/Support/EmptyFeedView.swift
// Empty and loading states shared by the Home feeds.

import SwiftUI

/// Following feed with nobody followed (or nothing posted yet).
struct EmptyFollowingView: View {
    @EnvironmentObject var tabRouter: TabRouter

    var body: some View {
        EmptyStateView(
            systemImage: "person.2.fill",
            title: "Nothing here yet",
            message: "Follow traders to see their posts and public trades here.",
            actionTitle: "Discover traders"
        ) {
            tabRouter.selected = .search
        }
    }
}

/// Centered spinner with a short label, used while a feed loads for the first time.
struct HomeFeedLoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: DS.Spacing.m) {
            ProgressView()
                .controlSize(.large)
                .tint(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .accessibilityElement(children: .combine)
    }
}
