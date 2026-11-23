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
            .onAppear {
                Task {
                    await checkFollowStatus()
                }
            }
            .alert("Follow Error", isPresented: $showError) {
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
            await MainActor.run {
                errorMessage = "Not authenticated. Please sign in again."
                showError = true
            }
            print("❌ No current user found")
            return
        }

        guard !targetUserId.isEmpty else {
            await MainActor.run {
                errorMessage = "Invalid user ID"
                showError = true
            }
            print("❌ Target user ID is empty")
            return
        }

        guard currentUserId != targetUserId else {
            await MainActor.run {
                errorMessage = "Cannot follow yourself"
                showError = true
            }
            print("❌ Trying to follow self")
            return
        }

        await MainActor.run {
            isLoading = true
        }

        do {
            if isFollowing {
                try await authService.unfollowUser(userId: targetUserId, followerId: currentUserId)
            } else {
                try await authService.followUser(userId: targetUserId, followerId: currentUserId)
            }

            await MainActor.run {
                isFollowing.toggle()
            }

        } catch {
            print("❌ Follow error: \(error)")

            await MainActor.run {
                errorMessage = "Follow failed: \(error.localizedDescription)"
                showError = true
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    private func checkFollowStatus() async {
        guard let currentUserId = authService.currentUser?.id else {
            print("❌ No current user for follow status check")
            return
        }

        guard !targetUserId.isEmpty else {
            print("❌ Empty target user ID for follow status check")
            return
        }

        do {
            let followStatus = try await authService.isFollowing(userId: currentUserId, targetUserId: targetUserId)

            await MainActor.run {
                isFollowing = followStatus
            }
        } catch {
            print("❌ Error checking follow status: \(error)")
        }
    }
}

// MARK: - Simple Follow List View

struct SimpleFollowListView: View {
    let userId: String
    let listType: ListType

    @State private var users: [User] = []
    @State private var isLoading = true
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
                .onAppear {
                    Task {
                        await loadUsers()
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .tint(Color.goldText)
        } else if users.isEmpty {
            EmptyStateView(
                systemImage: listType == .followers ? "person.2" : "person.badge.plus",
                title: "No \(listType.title.lowercased()) yet",
                message: listType.emptyMessage
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                        if index > 0 {
                            ProfileRowDivider(inset: DS.Spacing.l + 44 + DS.Spacing.m)
                        }
                        SimpleUserRow(user: user)
                    }
                }
                .cardStyle(padding: 0)
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.s)
            }
        }
    }

    private func loadUsers() async {
        isLoading = true

        do {
            let userIds: Set<String>

            switch listType {
            case .followers:
                userIds = try await authService.getUserFollowers(userId: userId)
            case .following:
                userIds = try await authService.getUserFollowing(userId: userId)
            }

            // Fetch user details
            var fetchedUsers: [User] = []
            for id in userIds {
                if let user = try await authService.getUserById(userId: id) {
                    fetchedUsers.append(user)
                }
            }

            users = fetchedUsers.sorted { $0.username < $1.username }

        } catch {
            print("Error loading users: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Simple User Row

struct SimpleUserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            UserAvatar(username: user.username, imageURL: user.profileImageUrl, size: 44)

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
