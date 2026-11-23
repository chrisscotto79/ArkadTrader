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
    @State private var showingReportReasons = false
    @State private var showingBlockConfirmation = false
    @State private var showingFullProfile = false
    @State private var isWorking = false
    @State private var feedback: Feedback?

    private struct Feedback: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        var dismissesSheet = false
    }

    private let reportReasons = [
        "Spam or scam",
        "Harassment or hate",
        "Misleading trading claims",
        "Impersonation",
        "Something else"
    ]

    private var isCurrentUser: Bool {
        user.id == authService.currentUser?.id
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
                            Button(action: { showingReportReasons = true }) {
                                Label("Report User", systemImage: "flag")
                            }
                            Button(role: .destructive, action: { showingBlockConfirmation = true }) {
                                Label("Block User", systemImage: "hand.raised")
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
            .confirmationDialog("Report \(displayName)", isPresented: $showingReportReasons, titleVisibility: .visible) {
                ForEach(reportReasons, id: \.self) { reason in
                    Button(reason) { report(reason: reason) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your report is sent to the Arkad team for review.")
            }
            .alert("Block \(displayName)?", isPresented: $showingBlockConfirmation) {
                Button("Block", role: .destructive) { block() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You won't see their messages in community chats.")
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
            await loadDetails()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DS.Spacing.m) {
            UserAvatar(username: user.username.isEmpty ? displayName : user.username,
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

            if user.startingCapital > 0 {
                let returnPct = user.totalProfitLoss / user.startingCapital * 100
                VStack(spacing: 0) {
                    detailRow("Starting capital") {
                        Text(user.startingCapital.asCurrency)
                            .arkadNumber(15, weight: .semibold)
                    }
                    Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, DS.Spacing.l)
                    detailRow("Return on capital") {
                        ChangePill(text: String(format: "%+.1f%%", returnPct), isPositive: returnPct >= 0)
                    }
                }
                .cardStyle(padding: 0)
            }
        }
    }

    private func detailRow<Value: View>(_ title: String, @ViewBuilder value: () -> Value) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: DS.Spacing.s)
            value()
        }
        .padding(.horizontal, DS.Spacing.l)
        .frame(minHeight: 48)
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
            SimpleFollowButton(targetUserId: user.id, targetUsername: user.username)

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

    private func report(reason: String) {
        guard let reporterId = authService.currentUser?.id else { return }
        isWorking = true
        Task {
            do {
                try await authService.reportUser(userId: user.id, reportedBy: reporterId, reason: reason)
                feedback = Feedback(title: "Report sent", message: "Thanks for letting us know. We'll review \(displayName)'s account.")
            } catch {
                feedback = Feedback(title: "Couldn't send report", message: error.localizedDescription)
            }
            isWorking = false
        }
    }

    private func block() {
        guard let blockerId = authService.currentUser?.id else { return }
        isWorking = true
        Task {
            do {
                try await authService.blockUser(userId: user.id, blockedBy: blockerId)
                onBlocked?(user.id)
                feedback = Feedback(
                    title: "\(displayName) blocked",
                    message: "You won't see their messages in community chats.",
                    dismissesSheet: true
                )
            } catch {
                feedback = Feedback(title: "Couldn't block user", message: error.localizedDescription)
            }
            isWorking = false
        }
    }
}
