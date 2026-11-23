// File: Core/Communities/Views/Main/CommunitiesView+MyCommunities.swift
// The Joined tab: communities you own and communities you're a member of.

import SwiftUI

// MARK: - My Communities Content
extension CommunitiesView {
    @ViewBuilder
    var myCommunitiesContent: some View {
        if viewModel.userCommunities.isEmpty {
            if viewModel.isLoading {
                loadingCard(text: "Loading your communities…")
            } else {
                emptyMyCommunitiesState
            }
        } else {
            if !viewModel.userOwnedCommunities.isEmpty {
                communitySection(
                    title: "Owned by you",
                    communities: viewModel.userOwnedCommunities,
                    isOwner: true
                )
            }

            if !viewModel.userMemberCommunities.isEmpty {
                communitySection(
                    title: "Member of",
                    communities: viewModel.userMemberCommunities,
                    isOwner: false
                )
            }

            discoverMoreCard
        }
        joinWithCodeButton
    }

    /// Private communities are joined with a code from someone already in them
    var joinWithCodeButton: some View {
        Button {
            showJoinWithCode = true
        } label: {
            Label("Join with invite code", systemImage: "ticket")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.goldText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.s)
        }
        .buttonStyle(PressableStyle())
    }

    func communitySection(title: String, communities: [Community], isOwner: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: title, count: communities.count)

            CommunityCardList(items: communities) { community in
                communityRow(community: community, isOwner: isOwner)
            }
        }
    }

    func communityRow(community: Community, isOwner: Bool) -> some View {
        Button {
            navigateToCommunitDetail(community)
        } label: {
            CommunityRowContent(community: community) {
                // The "Owned by you" heading already says who owns these
                CommunityChevron()
            }
        }
        .buttonStyle(PressableStyle())
    }

    /// Nudge towards finding more communities, below the joined lists
    var discoverMoreCard: some View {
        Button(action: goToDiscover) {
            HStack(spacing: DS.Spacing.m) {
                IconWell(systemName: "sparkle.magnifyingglass", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Find more communities")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text("Browse traders by style, from day trading to crypto")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: DS.Spacing.s)
                CommunityChevron()
            }
            .cardStyle(padding: DS.Spacing.l)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}
