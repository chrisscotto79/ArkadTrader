// File: Core/Communities/ViewModels/GlobalLeaderboardViewModel.swift
// State for the global callout leaderboard: the chosen sort and the ranked entries.

import SwiftUI

@MainActor
class GlobalLeaderboardViewModel: ObservableObject {
    @Published var entries: [CommunityLeaderboardEntry] = []
    @Published var category: LeaderboardCategory = .winRate
    @Published var isLoading = false
    @Published var errorMessage = ""
    /// True once a load has finished, so an empty board can be told apart from "not loaded yet"
    @Published var hasLoaded = false

    private let service = CommunityLeaderboardService.shared
    private var loadTask: Task<Void, Never>?

    func loadGlobalLeaderboard(forceRefresh: Bool = false) async {
        if forceRefresh { service.invalidate(communityId: "global") }
        isLoading = entries.isEmpty
        errorMessage = ""
        do {
            entries = try await service.getGlobalLeaderboard(category: category, limit: 50)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = TraderStats.friendlyLoadMessage(for: error)
        }
        isLoading = false
        hasLoaded = true
    }

    func refresh() async {
        await loadGlobalLeaderboard(forceRefresh: true)
    }

    /// Re-sort after the category changes
    func reload() {
        loadTask?.cancel()
        loadTask = Task { await loadGlobalLeaderboard() }
    }
}
