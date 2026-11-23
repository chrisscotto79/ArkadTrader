// File: Core/Communities/Views/Leaderboard/CommunityLeaderboardView.swift
// A community's leaderboard: traders ranked by their closed callouts in this community, plus member search.

import SwiftUI

struct CommunityLeaderboardView: View {
    let community: Community

    @StateObject private var viewModel = CommunityLeaderboardViewModel()
    @EnvironmentObject var authService: FirebaseAuthService

    @State private var searchText = ""
    @State private var members: [User] = []
    @State private var profileUser: User?

    private var currentUserId: String? { authService.currentUser?.id }

    private var filteredMembers: [User] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return members.filter {
            $0.username.lowercased().contains(query) || $0.fullName.lowercased().contains(query)
        }
    }

    var body: some View {
        ScrollView {
            Group {
                if searchText.isEmpty {
                    leaderboard
                } else {
                    memberResults
                }
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .screenBackground()
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search members of \(community.name)")
        .refreshable { await viewModel.load(communityId: community.id, forceRefresh: true) }
        .task {
            await viewModel.load(communityId: community.id)
            members = (try? await authService.getCommunityMembers(communityId: community.id)) ?? []
        }
        .onChange(of: viewModel.category) { _, _ in viewModel.reload(communityId: community.id) }
        .sheet(item: $profileUser) { user in
            OtherUserProfileView(user: user)
                .environmentObject(authService)
        }
    }

    // MARK: - Leaderboard

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(spacing: DS.Spacing.m) {
                CommunityAvatar(community: community, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(community.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(CommunityFormat.members(community.memberCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // The filter bar's chips bleed to the screen edges; it expects a page-margin container.
            LeaderboardFilterBar(category: $viewModel.category)

            if let mine = viewModel.entry(for: currentUserId), mine.rank > 3 {
                yourRank(mine)
            }

            rankings

            if let currentUserId, viewModel.entry(for: currentUserId) == nil,
               !viewModel.isLoading, viewModel.errorMessage.isEmpty {
                yourRecordHere(userId: currentUserId)
            }
        }
    }

    @ViewBuilder
    private var rankings: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
        } else if !viewModel.errorMessage.isEmpty {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load rankings",
                message: viewModel.errorMessage,
                actionTitle: "Try again",
                action: { Task { await viewModel.load(communityId: community.id, forceRefresh: true) } }
            )
            .cardStyle(padding: 0)
        } else if viewModel.entries.isEmpty {
            EmptyStateView(
                systemImage: "trophy",
                title: "No rankings yet",
                message: "Rankings appear once traders have \(TraderStats.minimumClosedCallouts) closed callouts in \(community.name)."
            )
            .cardStyle(padding: 0)
        } else {
            LeaderboardRankingList(
                entries: viewModel.entries,
                category: viewModel.category,
                currentUserId: currentUserId,
                onSelect: { openProfile(userId: $0.userId) }
            )
        }
    }

    private func yourRank(_ entry: CommunityLeaderboardEntry) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("YOUR POSITION")
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .padding(.leading, DS.Spacing.xs)
            Button {
                openProfile(userId: entry.userId)
            } label: {
                LeaderboardRow(entry: entry, category: viewModel.category, isCurrentUser: true)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
                    .cardStyle(padding: 0)
            }
            .buttonStyle(PressableStyle())
        }
    }

    /// Not ranked yet: show the viewer how far along their record in this community is.
    private func yourRecordHere(userId: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("YOUR RECORD HERE")
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .padding(.leading, DS.Spacing.xs)
            TrackRecordCard(userId: userId, communityId: community.id)
        }
    }

    // MARK: - Member search

    @ViewBuilder
    private var memberResults: some View {
        if filteredMembers.isEmpty {
            EmptyStateView(
                systemImage: "person.2",
                title: "No members found",
                message: "No one in \(community.name) matches \"\(searchText)\"."
            )
            .cardStyle(padding: 0)
        } else {
            CommunityCardList(items: filteredMembers, dividerInset: 68) { user in
                memberRow(user)
            }
        }
    }

    private func memberRow(_ user: User) -> some View {
        Button {
            if user.id == currentUserId {
                TabRouter.shared.open(.profile(userId: nil))
            } else {
                profileUser = user
            }
        } label: {
            HStack(spacing: DS.Spacing.m) {
                UserAvatar(username: user.username, imageURL: user.profileImageUrl, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName.isEmpty ? user.username : user.fullName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: DS.Spacing.s)
                if let entry = viewModel.entry(for: user.id) {
                    Text("#\(entry.rank)")
                        .arkadNumber(15)
                        .foregroundStyle(Color.goldText)
                }
                if user.id != currentUserId {
                    CommunityChevron()
                } else {
                    Tag(text: "You")
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Helpers

    /// Someone else's profile in a sheet; your own row opens your Profile tab
    private func openProfile(userId: String) {
        guard userId != currentUserId else {
            TabRouter.shared.open(.profile(userId: nil))
            return
        }
        if let member = members.first(where: { $0.id == userId }) {
            profileUser = member
            return
        }
        Task { profileUser = try? await authService.getUserById(userId: userId) }
    }
}

#Preview {
    NavigationStack {
        CommunityLeaderboardView(
            community: Community(name: "Test Community", description: "Test", type: .general, createdBy: "test")
        )
    }
    .environmentObject(FirebaseAuthService.shared)
}
