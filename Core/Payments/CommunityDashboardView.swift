// File: Core/Payments/CommunityDashboardView.swift
// Owner dashboard for a community: members, subscribers and revenue (paid communities),
// the owner's callout record and recent members. Revenue comes from communities/{cid}/private/revenue,
// which only the server writes.

import SwiftUI

@MainActor
final class CommunityDashboardViewModel: ObservableObject {
    enum RevenueState: Equatable {
        case loading
        case loaded(CommunityRevenue)
        /// No revenue doc yet: nobody has paid
        case empty
        case failed
    }

    @Published private(set) var members: [CommunityMemberWithRole] = []
    @Published private(set) var isLoadingMembers = false
    @Published private(set) var membersFailed = false
    @Published private(set) var revenueState: RevenueState = .loading
    @Published private(set) var payoutStatus: StripeAccountStatus?

    func load(community: Community) async {
        if community.isPaid {
            async let revenueTask: Void = loadRevenue(communityId: community.id)
            async let payoutsTask: Void = loadPayoutStatus()
            await loadMembers(communityId: community.id)
            await revenueTask
            await payoutsTask
        } else {
            await loadMembers(communityId: community.id)
        }
    }

    /// Members who joined most recently, owner excluded
    var recentMembers: [CommunityMemberWithRole] {
        Array(members.filter { $0.role != .owner }.sorted { $0.joinedAt > $1.joinedAt }.prefix(5))
    }

    private func loadMembers(communityId: String) async {
        isLoadingMembers = true
        membersFailed = false
        do {
            members = try await CommunityFirebaseService.shared.getCommunityMembersWithRoles(communityId: communityId)
        } catch {
            membersFailed = true
        }
        isLoadingMembers = false
    }

    private func loadRevenue(communityId: String) async {
        if revenueState == .failed { revenueState = .loading }
        do {
            if let revenue = try await PaymentsService.revenue(communityId: communityId) {
                revenueState = .loaded(revenue)
            } else {
                revenueState = .empty
            }
        } catch {
            revenueState = .failed
        }
    }

    private func loadPayoutStatus() async {
        guard let userId = FirebaseAuthService.shared.currentUser?.id else { return }
        payoutStatus = try? await PaymentsService.stripeAccount(userId: userId)
    }
}

struct CommunityDashboardView: View {
    let community: Community
    @StateObject private var viewModel = CommunityDashboardViewModel()

    private let columns = [GridItem(.flexible(), spacing: DS.Spacing.m), GridItem(.flexible(), spacing: DS.Spacing.m)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                header
                membersSection
                if community.isPaid {
                    revenueSection
                    payoutsRow
                } else {
                    activitySection
                }
                trackRecordSection
                recentMembersSection
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .screenBackground()
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await viewModel.load(community: community) }
        .refreshable { await viewModel.load(community: community) }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.m) {
            CommunityAvatar(community: community, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(community.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(community.priceTagText.map { "Paid · \($0)" } ?? "Free community")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    // MARK: - Members

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Members")
            LazyVGrid(columns: columns, spacing: DS.Spacing.m) {
                StatTile(
                    title: "Members",
                    value: community.memberCount.formatted(),
                    footnote: "Including you"
                )
                if community.isPaid {
                    StatTile(
                        title: "Active subscribers",
                        value: revenue.map { $0.activeSubscribers.formatted() } ?? "–"
                    )
                    StatTile(
                        title: "On free trial",
                        value: revenue.map { $0.trialingSubscribers.formatted() } ?? "–"
                    )
                }
            }
        }
    }

    // MARK: - Revenue (paid)

    private var revenue: CommunityRevenue? {
        if case .loaded(let revenue) = viewModel.revenueState { return revenue }
        return nil
    }

    @ViewBuilder
    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Revenue")
            switch viewModel.revenueState {
            case .loading:
                revenueTiles(CommunityRevenue(data: [:]))
                    .redacted(reason: .placeholder)
            case .loaded(let revenue):
                revenueTiles(revenue)
                if let updated = revenue.updatedAt {
                    Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, DS.Spacing.xs)
                }
            case .empty:
                inlineNote(
                    icon: "chart.bar.fill",
                    text: "No payments yet. Revenue shows up here after your first subscriber pays."
                )
            case .failed:
                inlineNote(
                    icon: "exclamationmark.triangle.fill",
                    text: "Couldn't load revenue. Pull to refresh."
                )
            }
            Text("Arkad keeps \(CommunityPricing.feePercentText) of each payment. \(CommunityPricing.processingFeeNote)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, DS.Spacing.xs)
        }
    }

    private func revenueTiles(_ revenue: CommunityRevenue) -> some View {
        VStack(spacing: DS.Spacing.m) {
            StatTile(
                title: "Monthly recurring revenue",
                value: revenue.mrr.asCurrency,
                footnote: "Before fees"
            )
            LazyVGrid(columns: columns, spacing: DS.Spacing.m) {
                StatTile(title: "Lifetime gross", value: revenue.lifetimeGross.asCurrency)
                StatTile(title: "Arkad fees", value: revenue.lifetimeArkadFees.asCurrency)
                StatTile(
                    title: "Lifetime net",
                    value: revenue.lifetimeNet.asCurrency,
                    valueColor: revenue.lifetimeNet > 0 ? .marketGreen : .primary,
                    footnote: "Paid to you"
                )
            }
        }
    }

    private var payoutsRow: some View {
        NavigationLink {
            PayoutsView()
        } label: {
            HStack(spacing: DS.Spacing.m) {
                IconWell(systemName: "banknote.fill", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payouts")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(payoutSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: DS.Spacing.s)
                CommunityChevron()
            }
            .cardStyle()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private var payoutSummary: String {
        switch viewModel.payoutStatus?.stage {
        case .ready: return "Ready. Open your Stripe dashboard for payouts."
        case .inReview: return "Stripe is reviewing your details"
        case .notStarted: return "Finish payout setup to get paid"
        case nil: return "Manage payouts with Stripe"
        }
    }

    // MARK: - Activity (free)

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Activity")
            LazyVGrid(columns: columns, spacing: DS.Spacing.m) {
                StatTile(title: "Last activity", value: lastActivityValue)
                StatTile(title: "Created", value: community.createdAt.formatted(.dateTime.month(.abbreviated).year()))
            }
        }
    }

    private var lastActivityValue: String {
        guard community.lastActivityDate != nil else { return "Quiet" }
        let text = community.lastActivityText
        if text == "Active now" { return "Now" }
        return text.replacingOccurrences(of: "Active ", with: "")
    }

    // MARK: - Track record

    private var trackRecordSection: some View {
        TrackRecordCard(userId: community.createdBy)
    }

    // MARK: - Recent members

    @ViewBuilder
    private var recentMembersSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Recent members")
            if viewModel.isLoadingMembers && viewModel.members.isEmpty {
                HStack(spacing: DS.Spacing.m) {
                    ProgressView()
                    Text("Loading members…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            } else if viewModel.membersFailed {
                inlineNote(icon: "exclamationmark.triangle.fill", text: "Couldn't load members. Pull to refresh.")
            } else if viewModel.recentMembers.isEmpty {
                inlineNote(icon: "person.2", text: "No members yet. Share your community to get your first ones.")
            } else {
                CommunityCardList(items: viewModel.recentMembers, dividerInset: 68) { member in
                    HStack(spacing: DS.Spacing.m) {
                        UserAvatar(username: member.displayName, imageURL: member.profileImageUrl, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(member.timeInCommunity)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: DS.Spacing.s)
                        if member.role != .member {
                            Tag(text: member.role.displayName, systemImage: member.role.icon, tint: member.role.color)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.vertical, DS.Spacing.m)
                }
            }
        }
    }

    // MARK: - Building blocks

    private func inlineNote(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: icon, tint: .secondary, size: 32)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .cardStyle()
    }
}
