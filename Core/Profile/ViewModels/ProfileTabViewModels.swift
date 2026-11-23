// File: Core/Profile/ViewModels/ProfileTabViewModels.swift
// View models for the profile Posts and Communities tabs.

import SwiftUI
import FirebaseFirestore

// MARK: - Posts

@MainActor
class UserPostsViewModel: ObservableObject {
    static let postLimit = 30

    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private var currentUserId: String = ""

    func loadUserPosts(userId: String) {
        currentUserId = userId
        guard !userId.isEmpty else { return }
        isLoading = true
        Task { await refreshPosts() }
    }

    func refreshPosts() async {
        let userId = currentUserId
        guard !userId.isEmpty else { return }

        isLoading = true
        errorMessage = ""
        do {
            // That user's newest posts only (authorId == uid, newest first, 30 reads at most)
            let snapshot = try await FirebaseServices.shared.db.collection("posts")
                .whereField("authorId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: Self.postLimit)
                .getDocuments()
            let userPosts = snapshot.documents.compactMap(Post.fromDocument)
            guard userId == currentUserId else { return }
            posts = userPosts
        } catch {
            guard userId == currentUserId else { return }
            errorMessage = "Couldn't load posts. Pull to refresh to try again."
        }
        isLoading = false
    }
}

// MARK: - Communities

@MainActor
class UserGroupsViewModel: ObservableObject {
    @Published var groups: [TradingGroup] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let authService = FirebaseAuthService.shared
    private var currentUserId: String = ""

    func loadUserGroups(userId: String) {
        currentUserId = userId
        guard !userId.isEmpty else { return }
        isLoading = true
        Task { await refreshGroups() }
    }

    func refreshGroups() async {
        let userId = currentUserId
        guard !userId.isEmpty else { return }

        isLoading = true
        errorMessage = ""
        do {
            let communities = try await visibleCommunities(of: userId)
            guard userId == currentUserId else { return }
            groups = communities.map(TradingGroup.init(community:))
        } catch {
            guard userId == currentUserId else { return }
            errorMessage = "Couldn't load communities. Pull to refresh to try again."
        }
        isLoading = false
    }

    /// Your own profile: every community you're in. Someone else's: their public communities,
    /// plus private ones you're also a member of. Private communities can only be read by
    /// members, so public ones are queried with `isPrivate == false` and shared private ones
    /// are read one by one.
    private func visibleCommunities(of userId: String) async throws -> [Community] {
        if userId == authService.currentUser?.id {
            return try await authService.getUserCommunities(userId: userId)
        }

        guard let user = try await authService.getUserById(userId: userId) else { return [] }
        let ids = Array(Set(user.communityIds))
        guard !ids.isEmpty else { return [] }

        let db = FirebaseServices.shared.db
        var communities: [Community] = []
        for chunk in ids.chunked(into: 30) {
            let snapshot = try await db.collection("communities")
                .whereField(FieldPath.documentID(), in: chunk)
                .whereField("isPrivate", isEqualTo: false)
                .getDocuments()
            communities += snapshot.documents.compactMap { document in
                try? Community.fromFirestore(data: document.data(), id: document.documentID)
            }
        }

        let found = Set(communities.map(\.id))
        let viewerIds = Set(authService.currentUser?.communityIds ?? [])
        for id in ids where viewerIds.contains(id) && !found.contains(id) {
            if let data = try? await db.collection("communities").document(id).getDocument().data(),
               let community = try? Community.fromFirestore(data: data, id: id) {
                communities.append(community)
            }
        }
        return communities.sorted { $0.memberCount > $1.memberCount }
    }
}

// MARK: - Supporting Models

struct TradingGroup: Identifiable {
    let id: String
    let name: String
    let description: String
    let memberCount: Int
    let isPrivate: Bool
    let imageUrl: String?
    let category: String
    let createdAt: Date
}

extension TradingGroup {
    init(community: Community) {
        self.init(
            id: community.id,
            name: community.name,
            description: community.description,
            memberCount: community.memberCount,
            isPrivate: community.isPrivate,
            imageUrl: nil,
            category: community.type.displayName,
            createdAt: community.createdAt
        )
    }
}
