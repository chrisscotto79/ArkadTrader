// File: Core/Profile/Views/SimpleFollowButton.swift
// Follow/unfollow button and the simple follower list it opens.

import SwiftUI

// MARK: - Simple Follow Button

struct SimpleFollowButton: View {
    enum Layout {
        /// Full-width button (gold Follow / neutral Following)
        case fullWidth
        /// Compact capsule for profile headers
        case pill
    }

    let targetUserId: String
    let targetUsername: String
    var layout: Layout = .fullWidth
    /// Called after a follow (true) or unfollow (false) is saved, so the screen can move the
    /// follower count by one without reloading
    var onFollowChange: ((Bool) -> Void)? = nil

    @State private var isFollowing = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    @EnvironmentObject var authService: FirebaseAuthService

    var body: some View {
        styledButton
            .disabled(isLoading)
            .sensoryFeedback(.selection, trigger: isFollowing)
            .accessibilityLabel(isFollowing ? "Following @\(targetUsername)" : "Follow @\(targetUsername)")
            .accessibilityHint(isFollowing ? "Double-tap to unfollow" : "")
            .task(id: targetUserId) {
                await checkFollowStatus()
            }
            .alert("Couldn't Update Follow", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
    }

    @ViewBuilder
    private var styledButton: some View {
        let button = Button {
            Task {
                await toggleFollow()
            }
        } label: {
            label
        }

        switch layout {
        case .pill:
            button.buttonStyle(PillButtonStyle(kind: isFollowing ? .neutral : .gold))
        case .fullWidth:
            if isFollowing {
                button.buttonStyle(SecondaryButtonStyle())
            } else {
                button.buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var label: some View {
        HStack(spacing: 6) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(isFollowing ? Color.primary : Color.onGold)
            } else {
                Image(systemName: isFollowing ? "checkmark" : "plus")
                    .font(.footnote.weight(.bold))
            }
            Text(isFollowing ? "Following" : "Follow")
        }
        .frame(minWidth: layout == .pill ? 84 : nil)
        .animation(.snappy(duration: 0.2), value: isFollowing)
    }

    private func toggleFollow() async {
        guard let currentUserId = authService.currentUser?.id else {
            errorMessage = "You're signed out. Please sign in again."
            showError = true
            return
        }
        guard !targetUserId.isEmpty, currentUserId != targetUserId else { return }

        isLoading = true
        let follow = !isFollowing
        do {
            if follow {
                try await authService.followUser(userId: targetUserId, followerId: currentUserId)
            } else {
                try await authService.unfollowUser(userId: targetUserId, followerId: currentUserId)
            }
            isFollowing = follow
            authService.adjustFollowingCount(by: follow ? 1 : -1)
            onFollowChange?(follow)
        } catch {
            errorMessage = follow
                ? "Couldn't follow @\(targetUsername). Check your connection and try again."
                : "Couldn't unfollow @\(targetUsername). Check your connection and try again."
            showError = true
        }
        isLoading = false
    }

    private func checkFollowStatus() async {
        guard let currentUserId = authService.currentUser?.id, !targetUserId.isEmpty else { return }
        if let status = try? await authService.isFollowing(userId: currentUserId, targetUserId: targetUserId) {
            isFollowing = status
        }
    }
}

// MARK: - Simple Follow List View

struct SimpleFollowListView: View {
    let userId: String
    let listType: ListType

    @State private var users: [User] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var selectedUser: User?
    @ObservedObject private var blockStore = BlockStore.shared
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss

    enum ListType {
        case followers
        case following

        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }

        var emptyMessage: String {
            switch self {
            case .followers: return "When traders follow this account, they'll show up here."
            case .following: return "Accounts this trader follows will show up here."
            }
        }
    }

    /// Blocked accounts are left out
    private var visibleUsers: [User] {
        users.filter { !blockStore.isBlocked($0.id) }
    }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .screenBackground()
                .navigationTitle(listType.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.goldText)
                    }
                }
                .task {
                    await blockStore.loadIfNeeded()
                    await loadUsers()
                }
                .refreshable {
                    await loadUsers()
                }
        }
        .sheet(item: $selectedUser) { user in
            OtherUserProfileView(user: user)
                .environmentObject(authService)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && users.isEmpty {
            ProgressView()
                .tint(Color.goldText)
        } else if loadFailed && users.isEmpty {
            EmptyStateView(
                systemImage: "wifi.exclamationmark",
                title: "Couldn't load \(listType.title.lowercased())",
                message: "Check your connection and try again.",
                actionTitle: "Try again"
            ) {
                Task { await loadUsers() }
            }
        } else if visibleUsers.isEmpty {
            EmptyStateView(
                systemImage: listType == .followers ? "person.2" : "person.badge.plus",
                title: "No \(listType.title.lowercased()) yet",
                message: listType.emptyMessage
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(visibleUsers.enumerated()), id: \.element.id) { index, user in
                        if index > 0 {
                            ProfileRowDivider(inset: DS.Spacing.l + 44 + DS.Spacing.m)
                        }
                        Button {
                            selectedUser = user
                        } label: {
                            SimpleUserRow(user: user)
                                .foregroundStyle(Color.primary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(SettingsRowButtonStyle())
                        .accessibilityHint("Opens their profile")
                    }
                }
                .cardStyle(padding: 0)
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.s)
            }
        }
    }

    /// Reads the ids, then the profiles 30 at a time. Missing or unreadable profiles are skipped.
    private func loadUsers() async {
        guard !userId.isEmpty else {
            isLoading = false
            return
        }
        isLoading = true
        loadFailed = false

        do {
            let userIds: Set<String>
            switch listType {
            case .followers:
                userIds = try await authService.getUserFollowers(userId: userId)
            case .following:
                userIds = try await authService.getUserFollowing(userId: userId)
            }
            let fetched = try await FirebaseServices.shared.getUsers(ids: Array(userIds))
            users = fetched.sorted { $0.username < $1.username }
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}

// MARK: - Simple User Row

struct SimpleUserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            UserAvatar(user: user, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.fullName.isEmpty ? user.username : user.fullName)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.goldText)
                            .accessibilityLabel("Verified")
                    }
                }

                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .accessibilityElement(children: .combine)
    }
}
