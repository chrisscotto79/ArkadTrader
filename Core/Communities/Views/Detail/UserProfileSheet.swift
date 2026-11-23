// File: Core/Communities/Views/Detail/UserProfileSheet.swift
// Profile sheet opened from a username or avatar in chat and the feed.

import SwiftUI

struct UserProfileSheet: View {
    let user: User
    let community: Community?
    /// Called with the user's id after the current user blocks them, so the presenter can hide their content
    var onBlocked: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: FirebaseAuthService

    /// Closed trades on record; nil while loading or if they couldn't be read
    @State private var closedTradeCount: Int?
    /// This user's communities that the viewer is allowed to see (public, or shared with the viewer)
    @State private var visibleCommunities: [Community] = []
    @State private var reportTarget: ReportTarget?
    @State private var showingBlockConfirmation = false
    @ObservedObject private var blockStore = BlockStore.shared
    @State private var showingFullProfile = false
    @State private var isWorking = false
    @State private var feedback: Feedback?

    private struct Feedback: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        var dismissesSheet = false
    }

    private var isCurrentUser: Bool {
        user.id == authService.currentUser?.id
    }

    private var isBlocked: Bool {
        blockStore.isBlocked(user.id)
    }

    private var displayName: String {
        if !user.fullName.isEmpty { return user.fullName }
        return user.username.isEmpty ? "This member" : "@\(user.username)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    header
                    performanceSection

                    if let bio = user.bio, !bio.isEmpty {
                        section("About") {
                            Text(bio)
                                .font(.body)
                                .foregroundStyle(Color.primary.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardStyle(padding: DS.Spacing.l)
                        }
                    }

                    if !visibleCommunities.isEmpty {
                        communitiesSection
                    }

                    if !isCurrentUser {
                        actionsSection
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.l)
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .tint(Color.goldText)
                }

                if !isCurrentUser {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(action: { reportTarget = .user(id: user.id) }) {
                                Label("Report", systemImage: "flag")
                            }
                            if isBlocked {
                                Button(action: { showingBlockConfirmation = true }) {
                                    Label("Unblock", systemImage: "hand.raised.slash")
                                }
                            } else {
                                Button(role: .destructive, action: { showingBlockConfirmation = true }) {
                                    Label("Block", systemImage: "hand.raised")
                                }
                            }
                        } label: {
                            if isWorking {
                                ProgressView()
                            } else {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        .disabled(isWorking)
                        .accessibilityLabel("More options")
                    }
                }
            }
            .sheet(item: $reportTarget) { target in
                ReportSheet(target: target)
            }
            .alert(isBlocked ? "Unblock \(displayName)?" : "Block \(displayName)?", isPresented: $showingBlockConfirmation) {
                if isBlocked {
                    Button("Unblock") { unblock() }
                } else {
                    Button("Block", role: .destructive) { block() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(isBlocked
                     ? "You'll see their posts, comments and messages again. Follows aren't restored."
                     : "You won't see their posts, comments or messages, and you'll stop following each other.")
            }
            .sheet(isPresented: $showingFullProfile) {
                OtherUserProfileView(user: user)
                    .environmentObject(authService)
            }
        }
        .presentationDragIndicator(.visible)
        .alert(
            feedback?.title ?? "",
            isPresented: Binding(get: { feedback != nil }, set: { if !$0 { feedback = nil } }),
            presenting: feedback
        ) { item in
            Button("OK") {
                if item.dismissesSheet { dismiss() }
            }
        } message: { item in
            Text(item.message)
        }
        .task {
            await blockStore.loadIfNeeded()
            await loadDetails()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DS.Spacing.m) {
            UserAvatar(username: user.username,
                       fullName: user.fullName,
                       imageURL: user.profileImageUrl,
                       size: 88)

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.fullName.isEmpty ? "Unknown member" : user.fullName)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.goldText)
                            .accessibilityLabel("Verified")
                    }
                }

                if !user.username.isEmpty {
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let community, community.createdBy == user.id {
                Tag(text: "Owner of \(community.name)", systemImage: "crown.fill")
            }

            HStack(spacing: 0) {
                headerStat(value: user.followersCount.formatted(), label: "Followers")
                headerDivider
                headerStat(value: user.followingCount.formatted(), label: "Following")
                headerDivider
                headerStat(value: user.createdAt.formatted(.dateTime.month(.abbreviated).year()), label: "Joined")
            }
            .padding(.top, DS.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: DS.Spacing.xl)
    }

    private var headerDivider: some View {
        Rectangle().fill(Color.hairline).frame(width: 1, height: 28)
    }

    private func headerStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .arkadNumber(17)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Trading Performance

    /// Win rate is stored as a percentage (0-100)
    private var hasClosedTrades: Bool {
        (closedTradeCount ?? 0) > 0
    }

    private var isTopPerformer: Bool {
        user.winRate >= 70 && (closedTradeCount ?? 0) >= CommunityLeaderboardService.minimumTradesForRatios
    }

    private var pnlColor: Color {
        user.totalProfitLoss > 0 ? .marketGreen : (user.totalProfitLoss < 0 ? .marketRed : .primary)
    }

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                SectionHeader(title: "Performance")
                if isTopPerformer {
                    Tag(text: "Top performer", systemImage: "star.fill")
                }
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: DS.Spacing.m), GridItem(.flexible(), spacing: DS.Spacing.m)],
                spacing: DS.Spacing.m
            ) {
                StatTile(
                    title: "Win rate",
                    value: hasClosedTrades ? "\(Int(user.winRate.rounded()))%" : "–",
                    valueColor: hasClosedTrades ? (user.winRate >= 50 ? .marketGreen : .marketRed) : .primary
                )
                StatTile(
                    title: "Total P&L",
                    value: user.totalProfitLoss.asCurrency,
                    valueColor: pnlColor
                )
                StatTile(
                    title: "Closed trades",
                    value: closedTradeCount.map { "\($0)" } ?? "–"
                )
                StatTile(
                    title: "Communities",
                    value: "\(user.communityIds.count)"
                )
            }
        }
    }

    // MARK: - Communities

    private var communitiesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Communities", count: visibleCommunities.count)

            CommunityCardList(items: Array(visibleCommunities.prefix(5)), dividerInset: 68) { item in
                CommunityRowContent(community: item, avatarSize: 40) {
                    if item.createdBy == user.id {
                        Tag(text: "Owner", systemImage: "crown.fill")
                    }
                }
            }

            if visibleCommunities.count > 5 {
                Text("+ \(visibleCommunities.count - 5) more")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.leading, DS.Spacing.xs)
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: DS.Spacing.m) {
            if isBlocked {
                Label("You blocked this account", systemImage: "hand.raised.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .cardStyle(padding: DS.Spacing.m, radius: DS.Radius.m)
            } else {
                SimpleFollowButton(targetUserId: user.id, targetUsername: user.username)
            }

            Button("View full profile") { showingFullProfile = true }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: - Building Blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: title)
            content()
        }
    }

    // MARK: - Data

    private func loadDetails() async {
        if let trades = try? await authService.getUserTrades(userId: user.id) {
            closedTradeCount = trades.filter { !$0.isOpen }.count
        }

        guard !user.communityIds.isEmpty,
              let communities = try? await authService.getUserCommunities(userId: user.id) else { return }
        // Private communities stay hidden unless the viewer is also a member
        let viewerCommunityIds = Set(authService.currentUser?.communityIds ?? [])
        visibleCommunities = communities
            .filter { !$0.isPrivate || viewerCommunityIds.contains($0.id) }
            .sorted { $0.memberCount > $1.memberCount }
    }

    // MARK: - Moderation

    private func block() {
        isWorking = true
        Task {
            do {
                try await blockStore.block(user.id)
                onBlocked?(user.id)
                feedback = Feedback(
                    title: "\(displayName) blocked",
                    message: "You won't see their posts, comments or messages.",
                    dismissesSheet: true
                )
            } catch {
                feedback = Feedback(title: "Couldn't block", message: "Check your connection and try again.")
            }
            isWorking = false
        }
    }

    private func unblock() {
        isWorking = true
        Task {
            do {
                try await blockStore.unblock(user.id)
            } catch {
                feedback = Feedback(title: "Couldn't unblock", message: "Check your connection and try again.")
            }
            isWorking = false
        }
    }
}
