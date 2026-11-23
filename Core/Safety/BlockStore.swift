// File: Core/Safety/BlockStore.swift
// The signed-in user's blocked accounts, loaded once and shared by every screen that hides
// blocked people's posts, comments and messages.

import Foundation
import Combine

@MainActor
final class BlockStore: ObservableObject {
    static let shared = BlockStore()

    /// Ids of accounts the current user has blocked
    @Published private(set) var blockedIds: Set<String> = []
    /// True once the list has been read for the current user
    @Published private(set) var hasLoaded = false

    private let authService = FirebaseAuthService.shared
    private let firebaseService = FirebaseServices.shared
    private var loadedForUserId: String?
    private var loadTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Start over when someone else signs in, or nobody is signed in
        authService.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .sink { [weak self] userId in
                Task { @MainActor in
                    guard let self, userId != self.loadedForUserId else { return }
                    self.reset()
                    if userId != nil { await self.loadIfNeeded() }
                }
            }
            .store(in: &cancellables)
    }

    func isBlocked(_ userId: String) -> Bool {
        blockedIds.contains(userId)
    }

    /// Loads the block list once per signed-in user. Safe to call from many screens.
    func loadIfNeeded() async {
        guard let userId = authService.currentUser?.id else { return }
        if loadedForUserId == userId && hasLoaded { return }
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await self.load(for: userId) }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// Reads the list again (pull to refresh in Blocked accounts).
    func reload() async {
        guard let userId = authService.currentUser?.id else { return }
        await load(for: userId)
    }

    func block(_ userId: String) async throws {
        guard let currentUserId = authService.currentUser?.id, userId != currentUserId else { return }
        try await firebaseService.blockUser(userId: userId, blockedBy: currentUserId)
        blockedIds.insert(userId)
    }

    func unblock(_ userId: String) async throws {
        guard let currentUserId = authService.currentUser?.id else { return }
        try await firebaseService.unblockUser(userId: userId, unblockedBy: currentUserId)
        blockedIds.remove(userId)
    }

    // MARK: - Private

    private func load(for userId: String) async {
        do {
            let ids = try await firebaseService.getUserBlockedUsers(userId: userId)
            // Ignore a late answer for someone who has since signed out
            guard authService.currentUser?.id == userId else { return }
            blockedIds = ids
            loadedForUserId = userId
            hasLoaded = true
        } catch {
            // Leave the current list in place; the next screen that needs it will try again.
            hasLoaded = false
        }
    }

    private func reset() {
        loadTask?.cancel()
        loadTask = nil
        blockedIds = []
        hasLoaded = false
        loadedForUserId = nil
    }
}
