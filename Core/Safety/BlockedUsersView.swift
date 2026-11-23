// File: Core/Safety/BlockedUsersView.swift
// Settings > Blocked accounts: everyone the user has blocked, with an Unblock button.
// Push it inside the Settings NavigationStack: NavigationLink { BlockedUsersView() } label: { … }

import SwiftUI

struct BlockedUsersView: View {
    @ObservedObject private var blockStore = BlockStore.shared
    @State private var users: [String: User] = [:]
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var unblockingIds: Set<String> = []
    @State private var errorMessage: String?

    /// Blocked ids in a stable order: by name once loaded
    private var orderedIds: [String] {
        blockStore.blockedIds.sorted { lhs, rhs in
            displayName(for: lhs).localizedCaseInsensitiveCompare(displayName(for: rhs)) == .orderedAscending
        }
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.m)
        }
        .screenBackground()
        .navigationTitle("Blocked accounts")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load(force: true) }
        .task { await load(force: false) }
        .alert(
            "Couldn't unblock",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && !blockStore.hasLoaded {
            HStack(spacing: DS.Spacing.m) {
                ProgressView()
                Text("Loading…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else if loadFailed && !blockStore.hasLoaded {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load blocked accounts",
                message: "Check your connection and try again.",
                actionTitle: "Try again",
                action: { Task { await load(force: true) } }
            )
            .cardStyle(padding: 0)
        } else if blockStore.blockedIds.isEmpty {
            EmptyStateView(
                systemImage: "hand.raised.fill",
                title: "No blocked accounts",
                message: "When you block someone, their posts, comments and messages are hidden from you. They'll be listed here."
            )
            .cardStyle(padding: 0)
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                Text("You won't see posts, comments or messages from these accounts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.leading, DS.Spacing.xs)

                VStack(spacing: 0) {
                    ForEach(Array(orderedIds.enumerated()), id: \.element) { index, userId in
                        if index > 0 {
                            Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 72)
                        }
                        row(for: userId)
                    }
                }
                .cardStyle(padding: 0)
            }
        }
    }

    private func row(for userId: String) -> some View {
        let user = users[userId]
        return HStack(spacing: DS.Spacing.m) {
            UserAvatar(username: user?.username ?? "?", imageURL: user?.profileImageUrl, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(for: userId))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                if let username = user?.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: DS.Spacing.s)

            Button {
                unblock(userId)
            } label: {
                if unblockingIds.contains(userId) {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Unblock")
                }
            }
            .buttonStyle(PillButtonStyle(kind: .neutral))
            .disabled(unblockingIds.contains(userId))
            .accessibilityLabel("Unblock \(displayName(for: userId))")
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
    }

    private func displayName(for userId: String) -> String {
        guard let user = users[userId] else { return "Arkad member" }
        if !user.fullName.isEmpty { return user.fullName }
        return user.username.isEmpty ? "Arkad member" : "@\(user.username)"
    }

    // MARK: - Data

    private func load(force: Bool) async {
        isLoading = true
        loadFailed = false
        if force {
            await blockStore.reload()
        } else {
            await blockStore.loadIfNeeded()
        }
        loadFailed = !blockStore.hasLoaded

        for userId in blockStore.blockedIds where users[userId] == nil {
            if let user = try? await FirebaseServices.shared.getUserById(userId: userId) {
                users[userId] = user
            }
        }
        isLoading = false
    }

    private func unblock(_ userId: String) {
        unblockingIds.insert(userId)
        Task {
            do {
                try await blockStore.unblock(userId)
            } catch {
                errorMessage = "Check your connection and try again."
            }
            unblockingIds.remove(userId)
        }
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
    }
}
