// File: Core/Communities/Views/Leaderboard/CommunityLeaderboardView.swift
// A community's leaderboard: members ranked by their closed trades, plus member search.

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
            if searchText.isEmpty {
                leaderboard
            } else {
                memberResults
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
        .onChange(of: viewModel.timeframe) { _, _ in viewModel.reload(communityId: community.id) }
        .sheet(item: $profileUser) { user in
            OtherUserProfileView(user: user)
                .environmentObject(authService)
        }
    }

    // MARK: - Leaderboard

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 16) {
            LeaderboardFilterBar(category: $viewModel.category, timeframe: $viewModel.timeframe)
                .padding(.top, 8)

            if let mine = viewModel.entry(for: currentUserId), mine.rank > 3 {
                yourRank(mine)
            }

            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if !viewModel.errorMessage.isEmpty {
                    message(
                        icon: "exclamationmark.triangle",
                        title: "Couldn't load rankings",
                        detail: viewModel.errorMessage,
                        action: ("Try Again", { Task { await viewModel.load(communityId: community.id, forceRefresh: true) } })
                    )
                } else if viewModel.entries.isEmpty {
                    message(
                        icon: "trophy",
                        title: "No rankings yet",
                        detail: emptyDetail,
                        action: nil
                    )
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.entries) { entry in
                            Button {
                                openProfile(userId: entry.userId)
                            } label: {
                                LeaderboardRow(entry: entry, category: viewModel.category, isCurrentUser: entry.userId == currentUserId)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 32)
    }

    private var emptyDetail: String {
        let window = viewModel.timeframe == .allTime ? "" : " this \(viewModel.timeframe.displayName.lowercased())"
        switch viewModel.category {
        case .consistencyMasters, .riskMasters:
            return "Members need at least \(CommunityLeaderboardService.minimumTradesForRatios) closed trades\(window) to rank here."
        default:
            return "Close a trade in your portfolio\(window) to get on the board."
        }
    }

    private func yourRank(_ entry: CommunityLeaderboardEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR POSITION")
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
            LeaderboardRow(entry: entry, category: viewModel.category, isCurrentUser: true)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Member search

    private var memberResults: some View {
        LazyVStack(spacing: 8) {
            if filteredMembers.isEmpty {
                message(icon: "person.2", title: "No members found", detail: "No one in \(community.name) matches \"\(searchText)\".", action: nil)
            }
            ForEach(filteredMembers) { user in
                Button {
                    if user.id != currentUserId { profileUser = user }
                } label: {
                    HStack(spacing: 12) {
                        UserAvatar(username: user.username, imageURL: user.profileImageUrl, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.fullName.isEmpty ? user.username : user.fullName)
                                .font(.subheadline.weight(.semibold))
                            Text("@\(user.username)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let entry = viewModel.entry(for: user.id) {
                            Text("#\(entry.rank)")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundColor(.arkadGold)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    // MARK: - Helpers

    private func message(icon: String, title: String, detail: String, action: (String, () -> Void)?) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.arkadGold)
            Text(title).font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let action {
                Button(action.0, action: action.1)
                    .buttonStyle(.borderedProminent)
                    .tint(.arkadGold)
                    .foregroundColor(.black)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }

    private func openProfile(userId: String) {
        guard userId != currentUserId else { return }
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
