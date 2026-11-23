// File: Core/Payments/CommunityDashboardView.swift
// Owner dashboard for a community: members, subscribers and revenue (paid communities),
// the owner's callout record and recent members. Revenue comes from communities/{cid}/private/revenue,
// which only the server writes. In free mode (AppConfig.paidCommunitiesEnabled off) every community
// gets the free layout: members, activity, the callout record and recent members.

import SwiftUI
import FirebaseFirestore

private extension Community {
    /// Subscribers, revenue and payouts apply: paid communities are on and this one is paid
    var hasPaidDashboard: Bool { AppConfig.paidCommunitiesEnabled && isPaid }
}

@MainActor
final class CommunityDashboardViewModel: ObservableObject {
    enum RevenueState: Equatable {
        case loading
        case loaded(CommunityRevenue)
        /// No revenue doc yet: nobody has paid
        case empty
        case failed
    }

    /// The most recent members (owner excluded), newest first
    @Published private(set) var recentMembers: [CommunityMemberWithRole] = []
    /// Members who joined in the last 7 days, owner excluded
    @Published private(set) var newMembersThisWeek = 0
    @Published private(set) var isLoadingMembers = false
    @Published private(set) var membersFailed = false
    @Published private(set) var revenueState: RevenueState = .loading
    @Published private(set) var payoutStatus: StripeAccountStatus?

    private let recentLimit = 5

    func load(community: Community) async {
        if community.hasPaidDashboard {
            async let revenueTask: Void = loadRevenue(communityId: community.id)
            async let payoutsTask: Void = loadPayoutStatus()
            await loadMembers(community: community)
            await revenueTask
            await payoutsTask
        } else {
            await loadMembers(community: community)
        }
    }

    /// The newest members (one query, plus one profile read each) and a count() of this week's.
    /// Member docs without `joinedAt` are left out of both, so they never count as new.
    private func loadMembers(community: Community) async {
        isLoadingMembers = true
        membersFailed = false
        defer { isLoadingMembers = false }
        let members = FirebaseServices.shared.db.collection("communities").document(community.id).collection("members")
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        do {
            async let recentSnapshot = members
                .order(by: "joinedAt", descending: true)
                .limit(to: recentLimit + 1)  // the owner may be among them
                .getDocuments()
            async let weekCount = members
                .whereField("joinedAt", isGreaterThan: Timestamp(date: weekAgo))
                .count
                .getAggregation(source: .server)

            let recent = try await recentSnapshot.documents
            let docs = recent.filter { $0.documentID != community.createdBy }
            var count = try await weekCount.count.intValue
            // Leave the owner out of the count when their own member doc is from this week
            if !community.createdBy.isEmpty {
                let ownerData = try? await members.document(community.createdBy).getDocument().data()
                if let ownerJoined = (ownerData?["joinedAt"] as? Timestamp)?.dateValue(), ownerJoined > weekAgo {
                    count = max(count - 1, 0)
                }
            }
            newMembersThisWeek = count

            var loaded: [CommunityMemberWithRole] = []
            for doc in docs.prefix(recentLimit) {
                let data = doc.data()
                guard let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue() else { continue }
                let role = CommunityRole(rawValue: data["role"] as? String ?? "") ?? .member
                let user = try? await FirebaseServices.shared.getUserById(userId: doc.documentID)
                loaded.append(CommunityMemberWithRole(
                    userId: doc.documentID,
                    username: user?.username ?? "member",
                    fullName: user?.fullName ?? "",
                    role: role,
                    joinedAt: joinedAt,
                    profileImageUrl: user?.profileImageUrl
                ))
            }
            recentMembers = loaded
        } catch {
            membersFailed = true
        }
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
                if community.hasPaidDashboard {
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
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    /// "Paid · $9.99/mo" or "Free community" with paid communities on; "Day Trading · 128 members" in free mode
    private var headerSubtitle: String {
        guard AppConfig.paidCommunitiesEnabled else { return CommunityFormat.summary(community) }
        return community.priceTagText.map { "Paid · \($0)" } ?? "Free community"
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
                if community.hasPaidDashboard {
                    StatTile(
                        title: "Active subscribers",
                        value: revenue.map { $0.activeSubscribers.formatted() } ?? "–"
                    )
                    StatTile(
                        title: "On free trial",
                        value: revenue.map { $0.trialingSubscribers.formatted() } ?? "–"
                    )
                } else {
                    StatTile(
                        title: "New this week",
                        value: viewModel.isLoadingMembers || viewModel.membersFailed
                            ? "–"
                            : viewModel.newMembersThisWeek.formatted()
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
            if viewModel.isLoadingMembers && viewModel.recentMembers.isEmpty {
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
                        UserAvatar(username: member.username, fullName: member.fullName, imageURL: member.profileImageUrl, size: 40)
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
