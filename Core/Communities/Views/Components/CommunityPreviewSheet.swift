// File: Core/Communities/Views/Components/CommunityPreviewSheet.swift
// Quick look at a community from Discover: who it's for, how big it is, the owner's track record,
// and a Join button (free) or a Subscribe button (paid, through Stripe Checkout).

import SwiftUI

struct CommunityPreviewSheet: View {
    let community: Community
    let isUserMember: Bool
    let onJoin: () -> Void
    let onEnterCommunity: () -> Void
    let onClose: () -> Void
    /// Called after a paid subscription is confirmed, so the caller can refresh its lists
    var onSubscribed: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscription = CommunitySubscriptionController()
    @State private var isJoining = false
    @State private var isBanned = false
    @State private var rules: [CommunityRule] = []
    @State private var showWelcome = false

    private var isPaid: Bool { community.requiresSubscription }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                hero
                statsRow
                aboutCard
                if isPaid {
                    pricingCard
                }
                ownerRecord
                if isPaid && !rules.isEmpty {
                    rulesCard
                }
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
        .task { await loadExtras() }
        .onChange(of: subscription.phase) { _, phase in
            if phase == .joined {
                HapticManager.shared.notification(type: .success)
                showWelcome = true
            }
        }
        .alert("Welcome to \(community.name)", isPresented: $showWelcome) {
            Button("Open community") {
                subscription.acknowledgeJoined()
                onSubscribed()
                onEnterCommunity()
                dismiss()
            }
        } message: {
            Text("You're in. Channels and callouts are open to you now.")
        }
        .alert(
            "Couldn't subscribe",
            isPresented: Binding(get: { subscription.errorMessage != nil }, set: { if !$0 { subscription.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(subscription.errorMessage ?? "")
        }
        .alert(
            "Almost there",
            isPresented: Binding(get: { subscription.pendingMessage != nil }, set: { if !$0 { subscription.pendingMessage = nil } })
        ) {
            Button("OK", role: .cancel) {
                onSubscribed()
            }
        } message: {
            Text(subscription.pendingMessage ?? "")
        }
    }

    private func loadExtras() async {
        guard !isUserMember else { return }
        if let userId = FirebaseAuthService.shared.currentUser?.id,
           let banned = try? await FirebaseServices.shared.isUserBanned(communityId: community.id, userId: userId) {
            isBanned = banned
        }
        if isPaid {
            rules = (try? await CommunityFirebaseService.shared.getCommunityRules(communityId: community.id)) ?? []
        }
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
                CommunityPriceTag(community: community)
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

    // MARK: - Paid

    private var pricingCard: some View {
        CommunityPriceSummary(community: community)
    }

    private var ownerRecord: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("The owner")
                .font(.headline)
            TrackRecordCard(userId: community.createdBy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rulesCard: some View {
        CommunityRulesList(rules: rules)
    }

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Text("What's inside")
                .font(.headline)
            featureRow(icon: "bubble.left.and.bubble.right.fill", text: "Channels to talk trades with other members")
            featureRow(icon: "megaphone.fill", text: "Trade callouts you can track in your portfolio")
            featureRow(icon: "trophy.fill", text: "A leaderboard ranked by closed trades")
            if isPaid {
                featureRow(icon: "lock.fill", text: "Channels open once you subscribe")
            } else if community.isPrivate {
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
            } else if isBanned {
                Text(CommunityJoinError.banned.errorDescription ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Color.surfaceRaised))
            } else if isPaid {
                CommunitySubscribeButton(community: community, controller: subscription)
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

// MARK: - Shared paid-community pieces

/// Price, trial and what the subscription covers
struct CommunityPriceSummary: View {
    let community: Community

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(CommunityPricing.format(community.priceMonthly ?? 0))
                    .arkadNumber(28)
                    .foregroundStyle(Color.primary)
                Text("/ month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if community.trialDays > 0 {
                    Tag(text: CommunityPricing.trialLabel(community.trialDays), systemImage: "gift.fill", tint: .marketGreen)
                }
            }
            Text(community.trialDays > 0
                 ? "Try it free for \(community.trialDays) days, then \(CommunityPricing.format(community.priceMonthly ?? 0)) a month. Cancel any time."
                 : "Billed monthly through Stripe. Cancel any time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: DS.Spacing.l)
    }
}

/// The community's rules, read-only
struct CommunityRulesList: View {
    let rules: [CommunityRule]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Text("Rules")
                .font(.headline)
            ForEach(rules.sorted { $0.order < $1.order }) { rule in
                HStack(alignment: .top, spacing: DS.Spacing.m) {
                    Image(systemName: rule.categoryIcon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.goldText)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.title)
                            .font(.subheadline.weight(.semibold))
                        Text(rule.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: DS.Spacing.l)
    }
}

/// "Subscribe · $9.99/mo", with progress while checkout opens and while the membership is confirmed
struct CommunitySubscribeButton: View {
    let community: Community
    @ObservedObject var controller: CommunitySubscriptionController

    var body: some View {
        Button {
            HapticManager.shared.impact(style: .light)
            Task { await controller.subscribe(to: community) }
        } label: {
            HStack(spacing: DS.Spacing.s) {
                if controller.isBusy {
                    ProgressView().tint(Color.onGold)
                }
                Text(title)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(controller.isBusy)
    }

    private var title: String {
        switch controller.phase {
        case .openingCheckout: return "Opening checkout…"
        case .confirming: return "Confirming…"
        default: return "Subscribe · \(community.priceTagText ?? "")"
        }
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
