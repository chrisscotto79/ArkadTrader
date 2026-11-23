// File: Core/Communities/Views/Components/CommunityPreviewSheet.swift
// Quick look at a community from Discover: who it's for, how big it is, and a Join button.

import SwiftUI

struct CommunityPreviewSheet: View {
    let community: Community
    let isUserMember: Bool
    let onJoin: () -> Void
    let onEnterCommunity: () -> Void
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isJoining = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                hero
                statsRow
                aboutCard
                featuresCard
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.l)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .overlay(alignment: .topTrailing) {
            IconButton(systemName: "xmark", accessibilityLabel: "Close", size: 32) {
                onClose()
                dismiss()
            }
            .padding(DS.Spacing.l)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            CommunityAvatar(community: community, size: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(community.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.primary)
                Text(CommunityFormat.summary(community))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: DS.Spacing.s) {
                Tag(text: community.type.displayName, systemImage: community.typeIcon, tint: .secondary)
                if community.isPrivate {
                    Tag(text: "Private", systemImage: "lock.fill", tint: .secondary)
                }
                if isUserMember {
                    JoinedTag()
                }
            }
        }
        .padding(.trailing, 44) // room for the close button
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: DS.Spacing.s) {
            StatTile(title: "Members", value: community.memberCount.formatted())
            StatTile(title: "Created", value: community.createdAt.formatted(.dateTime.month(.abbreviated).year()))
            StatTile(title: "Activity", value: activityValue)
        }
    }

    /// "2h ago" style activity, or "Quiet" when nothing's been posted recently
    private var activityValue: String {
        guard community.lastActivityDate != nil else { return "Quiet" }
        let text = community.lastActivityText
        if text == "Active now" { return "Now" }
        return text.replacingOccurrences(of: "Active ", with: "")
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("About")
                .font(.headline)
            Text(community.description.isEmpty ? "No description yet." : community.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: DS.Spacing.l)
    }

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Text("What's inside")
                .font(.headline)
            featureRow(icon: "bubble.left.and.bubble.right.fill", text: "Channels to talk trades with other members")
            featureRow(icon: "megaphone.fill", text: "Trade callouts you can track in your portfolio")
            featureRow(icon: "trophy.fill", text: "A leaderboard ranked by closed trades")
            if community.isPrivate {
                featureRow(icon: "lock.fill", text: "Private: hidden from Discover and search")
            } else {
                featureRow(icon: "globe", text: "Public: anyone can find and join")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: DS.Spacing.l)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: icon, size: 32)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Action

    private var actionBar: some View {
        Group {
            if isUserMember {
                Button {
                    onEnterCommunity()
                    dismiss()
                } label: {
                    Label("Open community", systemImage: "arrow.right")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button(action: joinCommunity) {
                    HStack(spacing: DS.Spacing.s) {
                        if isJoining {
                            ProgressView().tint(Color.onGold)
                        }
                        Text(isJoining ? "Joining…" : "Join community")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isJoining)
            }
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.top, DS.Spacing.m)
        .padding(.bottom, DS.Spacing.s)
        .background(Color.appBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
    }

    // MARK: - Helper Methods
    private func joinCommunity() {
        isJoining = true
        onJoin()
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    let sampleCommunity = Community(
        name: "Crypto Elite Traders",
        description: "Advanced cryptocurrency trading community focused on technical analysis and market trends.",
        type: .crypto,
        creatorId: "user123",
        memberCount: 1247,
        isPrivate: false
    )

    CommunityPreviewSheet(
        community: sampleCommunity,
        isUserMember: false,
        onJoin: {},
        onEnterCommunity: {},
        onClose: {}
    )
}
