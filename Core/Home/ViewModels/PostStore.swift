// File: Core/Home/ViewModels/PostStore.swift
// One shared record of what the signed-in user has done to posts this session: liked,
// bookmarked, the latest like/comment counts, and posts deleted or reported (hidden from you).
// Every post card reads it, so a like on a ticker page shows on Home, a deleted post leaves
// every list, and so on. Likes and bookmarks are loaded once per session; `reset()` on sign-out.

import Foundation
import SwiftUI

@MainActor
final class PostStore: ObservableObject {
    static let shared = PostStore()

    @Published private(set) var likedIds: Set<String> = []
    @Published private(set) var bookmarkedIds: Set<String> = []
    /// Latest known counts, newer than the copy a screen loaded.
    @Published private(set) var likeCounts: [String: Int] = [:]
    @Published private(set) var commentCounts: [String: Int] = [:]
    /// Deleted, or reported by you this session.
    @Published private(set) var removedIds: Set<String> = []
    /// A short message shown at the bottom of the screen ("Post deleted").
    @Published var toast: String?
    /// Set when a like or bookmark couldn't be saved.
    @Published var actionError: String?

    private var loadedUserId: String?
    private var loadTask: Task<Void, Never>?
    /// Posts with a like or bookmark write on the way; taps on them are ignored until it lands.
    private var likesInFlight: Set<String> = []
    private var bookmarksInFlight: Set<String> = []
    /// When each post's counts last changed here, so an older feed load doesn't undo them.
    private var localChangeAt: [String: Date] = [:]
    private var toastTask: Task<Void, Never>?

    private init() {}

    private var authService: FirebaseAuthService { FirebaseAuthService.shared }

    // MARK: - Session

    /// Loads your likes and bookmarks once per signed-in user.
    func loadIfNeeded() async {
        guard let userId = authService.currentUser?.id else { return }
        if loadedUserId == userId { return }
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            async let likes = try? FirebaseServices.shared.getUserLikedPosts(userId: userId)
            async let bookmarks = try? FirebaseServices.shared.getUserBookmarkedPosts(userId: userId)
            let (loadedLikes, loadedBookmarks) = await (likes, bookmarks)
            // Signed out or switched account while loading
            guard self.authService.currentUser?.id == userId else { return }
            // Keep taps made while loading
            self.likedIds.formUnion(loadedLikes ?? [])
            self.bookmarkedIds.formUnion(loadedBookmarks ?? [])
            if loadedLikes != nil && loadedBookmarks != nil {
                self.loadedUserId = userId
            }
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// Forgets everything. Call on sign-out (and account switch).
    func reset() {
        loadTask?.cancel()
        loadTask = nil
        loadedUserId = nil
        likedIds = []
        bookmarkedIds = []
        likeCounts = [:]
        commentCounts = [:]
        removedIds = []
        likesInFlight = []
        bookmarksInFlight = []
        localChangeAt = [:]
        toast = nil
        actionError = nil
    }

    // MARK: - Reading

    func isLiked(_ postId: String) -> Bool { likedIds.contains(postId) }
    func isBookmarked(_ postId: String) -> Bool { bookmarkedIds.contains(postId) }

    func likesCount(for post: Post) -> Int { likeCounts[post.id] ?? post.likesCount }
    func commentsCount(for post: Post) -> Int { commentCounts[post.id] ?? post.commentsCount }

    /// Not deleted, not hidden by reports, not reported by you and not by someone you blocked.
    func isVisible(_ post: Post) -> Bool {
        !post.isHidden && !removedIds.contains(post.id) && !BlockStore.shared.isBlocked(post.authorId)
    }

    func visible(_ posts: [Post]) -> [Post] {
        posts.filter(isVisible)
    }

    /// Takes the counts from freshly loaded posts as the latest, except for posts you've
    /// just liked or commented on here (their write may be newer than the load).
    func absorb(_ posts: [Post]) {
        let now = Date()
        var likes = likeCounts
        var comments = commentCounts
        for post in posts {
            if likesInFlight.contains(post.id) { continue }
            if let changed = localChangeAt[post.id], now.timeIntervalSince(changed) < 15 { continue }
            likes[post.id] = post.likesCount
            comments[post.id] = post.commentsCount
        }
        if likes != likeCounts { likeCounts = likes }
        if comments != commentCounts { commentCounts = comments }
    }

    // MARK: - Likes

    /// Likes or unlikes, updating the heart and count right away. Taps while a write for the
    /// same post is still on the way are ignored, so fast double taps can't race.
    func toggleLike(_ post: Post) {
        guard let userId = authService.currentUser?.id, !likesInFlight.contains(post.id) else { return }
        let wasLiked = isLiked(post.id)
        let before = likesCount(for: post)

        likesInFlight.insert(post.id)
        setLiked(!wasLiked, postId: post.id)
        likeCounts[post.id] = max(0, before + (wasLiked ? -1 : 1))
        localChangeAt[post.id] = Date()

        Task {
            do {
                if wasLiked {
                    try await FirebaseServices.shared.unlikePost(postId: post.id, userId: userId)
                } else {
                    try await FirebaseServices.shared.likePost(postId: post.id, userId: userId)
                }
            } catch {
                setLiked(wasLiked, postId: post.id)
                likeCounts[post.id] = before
                actionError = wasLiked ? "Couldn't remove your like. Try again." : "Couldn't save your like. Try again."
            }
            likesInFlight.remove(post.id)
        }
    }

    private func setLiked(_ liked: Bool, postId: String) {
        if liked { likedIds.insert(postId) } else { likedIds.remove(postId) }
    }

    // MARK: - Bookmarks

    func toggleBookmark(_ post: Post) {
        guard let userId = authService.currentUser?.id, !bookmarksInFlight.contains(post.id) else { return }
        let wasBookmarked = isBookmarked(post.id)
        bookmarksInFlight.insert(post.id)
        setBookmarked(!wasBookmarked, postId: post.id)

        Task {
            do {
                if wasBookmarked {
                    try await FirebaseServices.shared.unbookmarkPost(postId: post.id, userId: userId)
                } else {
                    try await FirebaseServices.shared.bookmarkPost(postId: post.id, userId: userId)
                }
            } catch {
                setBookmarked(wasBookmarked, postId: post.id)
                actionError = "Couldn't update your bookmark. Try again."
            }
            bookmarksInFlight.remove(post.id)
        }
    }

    private func setBookmarked(_ bookmarked: Bool, postId: String) {
        if bookmarked { bookmarkedIds.insert(postId) } else { bookmarkedIds.remove(postId) }
    }

    // MARK: - Comments, deletes and reports

    /// The comment count after the comments sheet added or removed one.
    func setCommentsCount(_ count: Int, for postId: String) {
        commentCounts[postId] = max(0, count)
        localChangeAt[postId] = Date()
    }

    /// Drops a deleted or reported post from every list.
    func markRemoved(_ postId: String) {
        removedIds.insert(postId)
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.snappy(duration: 0.3)) { toast = message }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.3)) { self?.toast = nil }
        }
    }
}

// MARK: - Toast and errors

/// Shows PostStore's toast at the bottom of the screen and its action errors as an alert.
/// Put it on each screen that lists posts.
struct PostStoreFeedback: ViewModifier {
    @ObservedObject private var store = PostStore.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message = store.toast {
                    HStack(spacing: DS.Spacing.s) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.marketGreen)
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, DS.Spacing.s)
                    .background(Capsule().fill(Color.surfaceRaised))
                    .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: 1))
                    .padding(.bottom, DS.Spacing.l)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { store.actionError != nil },
                set: { if !$0 { store.actionError = nil } }
            )) {
                Button("OK", role: .cancel) { store.actionError = nil }
            } message: {
                Text(store.actionError ?? "")
            }
    }
}

extension View {
    /// PostStore's "Post deleted" toast and like/bookmark errors.
    func postStoreFeedback() -> some View {
        modifier(PostStoreFeedback())
    }
}
