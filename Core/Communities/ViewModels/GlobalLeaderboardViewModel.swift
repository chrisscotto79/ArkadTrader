// File: Core/Communities/ViewModels/GlobalLeaderboardViewModel.swift
// State for the global leaderboard: category, timeframe and ranked entries.

import SwiftUI

// MARK: - Global Leaderboard ViewModel
@MainActor
class GlobalLeaderboardViewModel: ObservableObject {
    @Published var entries: [CommunityLeaderboardEntry] = []
    @Published var category: LeaderboardCategory = .profitKings
    @Published var timeframe: LeaderboardTimeframe = .allTime
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let service = CommunityLeaderboardService.shared
    private var loadTask: Task<Void, Never>?

    func loadGlobalLeaderboard(forceRefresh: Bool = false) async {
        if forceRefresh { service.invalidate(communityId: "global") }
        isLoading = entries.isEmpty
        errorMessage = ""
        do {
            entries = try await service.getGlobalLeaderboard(category: category, timeframe: timeframe, limit: 50)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await loadGlobalLeaderboard(forceRefresh: true)
    }

    /// Reload after the category or timeframe changes
    func reload() {
        loadTask?.cancel()
        entries = []
        loadTask = Task { await loadGlobalLeaderboard() }
    }
}
