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
                VStack(spacing: 20) {
                    header
                    performanceSection

                    if let bio = user.bio, !bio.isEmpty {
                        card {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionTitle("About")
                                Text(bio)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if !visibleCommunities.isEmpty {
                        communitiesSection
                    }

                    if !isCurrentUser {
                        actionsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }

                if !isCurrentUser {
                    ToolbarItem(placement: .navigationBarTrailing) {
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
                            }
                        }
                        .disabled(isWorking)
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
        VStack(spacing: 12) {
            avatar

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.fullName.isEmpty ? "Unknown member" : user.fullName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.arkadGold)
                    }
                }

                if !user.username.isEmpty {
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 0) {
                headerStat(value: "\(user.followersCount)", label: "Followers")
                headerStat(value: "\(user.followingCount)", label: "Following")
                headerStat(value: user.createdAt.formatted(.dateTime.month(.abbreviated).year()), label: "Joined")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Color.arkadGold.opacity(0.15))

            if let urlString = user.profileImageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
            } else {
                Text(initials)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.arkadGoldDark)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.arkadGold, lineWidth: 3))
    }

    private var initials: String {
        let parts = user.fullName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        if !letters.isEmpty { return String(letters).uppercased() }
        return String(user.username.prefix(1)).uppercased()
    }

    private func headerStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trading Performance

    /// Win rate is stored as a percentage (0-100)
    private var hasClosedTrades: Bool {
        (closedTradeCount ?? 0) > 0
    }

    private var isTopPerformer: Bool {
        user.winRate >= 70 && (closedTradeCount ?? 0) >= CommunityLeaderboardService.minimumTradesForRatios
    }

    private var performanceSection: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    sectionTitle("Trading Performance")
                    Spacer()
                    if isTopPerformer {
                        Label("Top Performer", systemImage: "star.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.arkadGoldDark)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.arkadGold.opacity(0.15)))
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statTile(
                        title: "Win Rate",
                        value: hasClosedTrades ? "\(Int(user.winRate.rounded()))%" : "–",
                        color: hasClosedTrades ? (user.winRate >= 50 ? .marketGreen : .marketRed) : .primary
                    )
                    statTile(
                        title: "Total P&L",
                        value: user.totalProfitLoss.asCurrency,
                        color: user.totalProfitLoss > 0 ? .marketGreen : (user.totalProfitLoss < 0 ? .marketRed : .primary)
                    )
                    statTile(
                        title: "Closed Trades",
                        value: closedTradeCount.map { "\($0)" } ?? "–",
                        color: .primary
                    )
                    statTile(
                        title: "Communities",
                        value: "\(user.communityIds.count)",
                        color: .primary
                    )
                }

                if user.startingCapital > 0 {
                    Divider()
                    detailRow("Starting capital", user.startingCapital.asCurrency)
                    detailRow("Return on capital", String(format: "%.1f%%", user.totalProfitLoss / user.startingCapital * 100))
                }
            }
        }
    }

    private func statTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Communities

    private var communitiesSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Communities")

                ForEach(visibleCommunities.prefix(5)) { community in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(community.type.tint.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(community.initials)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(community.type.tint)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(community.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text("\(community.memberCount) member\(community.memberCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if community.createdBy == user.id {
                            Text("Owner")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.arkadGoldDark)
                        }
                    }
                }

                if visibleCommunities.count > 5 {
                    Text("+ \(visibleCommunities.count - 5) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            SimpleFollowButton(targetUserId: user.id, targetUsername: user.username)

            Button(action: { showingFullProfile = true }) {
                Text("View Full Profile")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadGoldDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.arkadGold, lineWidth: 1.5)
                    )
            }
        }
    }

    // MARK: - Building Blocks

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .fontWeight(.bold)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
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
