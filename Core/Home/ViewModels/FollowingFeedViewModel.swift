// File: Core/Home/ViewModels/FollowingFeedViewModel.swift
// The Following feed: posts, public trades and activity from people you follow. Each kind
// loads on its own, so one failing doesn't empty the others.

import Foundation
import SwiftUI
import Combine

@MainActor
class FollowingFeedViewModel: ObservableObject {
    @Published var followingPosts: [Post] = []
    @Published var followingTrades: [Trade] = []
    @Published var followingActivity: [ActivityItem] = []
    @Published var isLoading = false
    /// Set when nothing could be loaded.
    @Published var loadError: String?
    /// True once the first load has finished, so switching tabs doesn't reload every time.
    @Published var hasLoaded = false

    private let authService = FirebaseAuthService.shared
    private let blockStore = BlockStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Drop a person's trades and activity as soon as they're blocked (posts are filtered
        // by PostStore when shown)
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
        let services = FirebaseServices.shared

        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        async let interactions: Void = PostStore.shared.loadIfNeeded()
        await blockStore.loadIfNeeded()

        let followingIds: [String]
        do {
            followingIds = try await services.followingIdsForFeed(userId: currentUserId)
        } catch {
            await interactions
            loadError = TickerFeedError.friendlyMessage(for: error)
            return
        }

        async let posts = Self.attempt { try await services.getFollowingPosts(followingIds: followingIds) }
        async let trades = Self.attempt { try await services.getFollowingTrades(followingIds: followingIds) }
        async let activity = Self.attempt { try await services.getFollowingActivity(followingIds: followingIds) }
        let (postResult, tradeResult, activityResult) = await (posts, trades, activity)
        await interactions

        var failure: Error?
        switch postResult {
        case .success(let loaded):
            followingPosts = loaded
            PostStore.shared.absorb(loaded)
        case .failure(let error): failure = error
        }
        switch tradeResult {
        case .success(let loaded): followingTrades = loaded
        case .failure(let error): failure = failure ?? error
        }
        switch activityResult {
        case .success(let loaded): followingActivity = loaded
        case .failure(let error): failure = failure ?? error
        }
        removeContent(from: blockStore.blockedIds)

        let nothingLoaded = followingPosts.isEmpty && followingTrades.isEmpty && followingActivity.isEmpty
        loadError = (failure != nil && nothingLoaded) ? TickerFeedError.friendlyMessage(for: failure!) : nil
    }

    func refreshContent() async {
        await loadFollowingContent()
    }

    private static func attempt<T>(_ work: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    private func removeContent(from userIds: Set<String>) {
        guard !userIds.isEmpty else { return }
        followingTrades.removeAll { userIds.contains($0.userId) }
        followingActivity.removeAll { userIds.contains($0.userId) }
    }
}
