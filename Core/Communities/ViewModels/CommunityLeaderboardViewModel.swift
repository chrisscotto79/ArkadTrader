// File: Core/Communities/ViewModels/CommunityLeaderboardViewModel.swift
// State for a community's callout leaderboard: the chosen sort and the ranked entries.

import Foundation

@MainActor
class CommunityLeaderboardViewModel: ObservableObject {

    @Published var entries: [CommunityLeaderboardEntry] = []
    @Published var category: LeaderboardCategory = .winRate
    /// Starts true so the board doesn't flash its empty state before the first load
    @Published var isLoading = true
    @Published var errorMessage = ""

    private let service = CommunityLeaderboardService.shared
    private var loadTask: Task<Void, Never>?

    func load(communityId: String, forceRefresh: Bool = false) async {
        if forceRefresh { service.invalidate(communityId: communityId) }
        isLoading = entries.isEmpty
        errorMessage = ""
        do {
            entries = try await service.getLeaderboard(communityId: communityId, category: category)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = TraderStats.friendlyLoadMessage(for: error)
        }
        isLoading = false
    }

    /// Re-sort after the category changes, cancelling any load still in flight
    func reload(communityId: String) {
        loadTask?.cancel()
        loadTask = Task { await load(communityId: communityId) }
    }

    func entry(for userId: String?) -> CommunityLeaderboardEntry? {
        guard let userId else { return nil }
        return entries.first { $0.userId == userId }
    }
}
