// File: Core/Communities/ViewModels/CommunityLeaderboardViewModel.swift
// State for a community's leaderboard: the chosen category and timeframe, and the ranked entries.

import Foundation

@MainActor
class CommunityLeaderboardViewModel: ObservableObject {

    @Published var entries: [CommunityLeaderboardEntry] = []
    @Published var category: LeaderboardCategory = .profitKings
    @Published var timeframe: LeaderboardTimeframe = .monthly
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let service = CommunityLeaderboardService.shared
    private var loadTask: Task<Void, Never>?

    func load(communityId: String, forceRefresh: Bool = false) async {
        if forceRefresh { service.invalidate(communityId: communityId) }
        isLoading = entries.isEmpty
        errorMessage = ""
        do {
            entries = try await service.getLeaderboard(communityId: communityId, category: category, timeframe: timeframe)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Reload after the category or timeframe changes, cancelling any load still in flight
    func reload(communityId: String) {
        loadTask?.cancel()
        entries = []
        loadTask = Task { await load(communityId: communityId) }
    }

    func entry(for userId: String?) -> CommunityLeaderboardEntry? {
        guard let userId else { return nil }
        return entries.first { $0.userId == userId }
    }
}
