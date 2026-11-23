import Foundation
import SwiftUI
import Combine

@MainActor
class FollowingFeedViewModel: ObservableObject {
    @Published var followingPosts: [Post] = []
    @Published var followingTrades: [Trade] = []
    @Published var followingActivity: [ActivityItem] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    /// True once the first load has finished, so switching tabs doesn't reload every time.
    @Published var hasLoaded = false

    private let authService = FirebaseAuthService.shared
    private let blockStore = BlockStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Drop a person's content as soon as they're blocked
        blockStore.$blockedIds
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] blockedIds in
                MainActor.assumeIsolated {
                    self?.removeContent(from: blockedIds)
                }
            }
            .store(in: &cancellables)
    }

    func loadFollowingContent() async {
        guard let currentUserId = authService.currentUser?.id else { return }

        isLoading = true
        await blockStore.loadIfNeeded()

        do {
            async let posts = authService.getFollowingPosts(userId: currentUserId)
            async let trades = authService.getFollowingTrades(userId: currentUserId)
            async let activity = authService.getFollowingActivity(userId: currentUserId)

            let loadedPosts = try await posts
            followingPosts = loadedPosts.filter { !$0.isHidden }
            followingTrades = try await trades
            followingActivity = try await activity
            removeContent(from: blockStore.blockedIds)

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
        hasLoaded = true
    }

    func refreshContent() async {
        await loadFollowingContent()
    }

    private func removeContent(from userIds: Set<String>) {
        guard !userIds.isEmpty else { return }
        followingPosts.removeAll { userIds.contains($0.authorId) }
        followingTrades.removeAll { userIds.contains($0.userId) }
        followingActivity.removeAll { userIds.contains($0.userId) }
    }
}
