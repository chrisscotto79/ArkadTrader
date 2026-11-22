// File: Core/Communities/Views/Main/CommunitiesView+MyCommunities.swift
// The My Communities tab.

import SwiftUI

// MARK: - My Communities Content
extension CommunitiesView {
    var myCommunitiesContent: some View {
        VStack(spacing: 24) {
            if viewModel.userCommunities.isEmpty {
                emptyMyCommunitiesState
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
            }
        }
    }

    func communitySection(title: String, communities: [Community], isOwner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
                Text("\(communities.count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(communities.enumerated()), id: \.element.id) { index, community in
                    communityRow(community: community, isOwner: isOwner)
                    if index < communities.count - 1 {
                        Divider().padding(.leading, 76)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    func communityRow(community: Community, isOwner: Bool) -> some View {
        Button {
            navigateToCommunitDetail(community)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(getCommunityColor(for: community.type))
                        .frame(width: 46, height: 46)
                    Text(getCommunityInitials(from: community.name))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(community.name)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        if isOwner {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(.arkadGoldDark)
                                .accessibilityLabel("Owner")
                        }
                    }

                    Text("\(community.type.shortDisplayName) · \(community.memberCount) \(community.memberCount == 1 ? "member" : "members")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
