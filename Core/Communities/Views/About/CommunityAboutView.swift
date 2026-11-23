// File: Core/Communities/Views/About/CommunityAboutView.swift
// The community landing page (Whop-style), shared by the preview sheet that non-members
// see and the "About" tab inside the community:
// - CommunityLandingHeader: banner, avatar, name, tags and description
// - CommunityAboutView: the leader's track record, what's inside and their recent results
// Neither has its own scroll view.

import SwiftUI

// MARK: - Header

struct CommunityLandingHeader: View {
    let community: Community
    var isMember = false

    private let bannerHeight: CGFloat = 132
    private let avatarSize: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            ZStack(alignment: .bottomLeading) {
                banner
                    .frame(height: bannerHeight)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                            .strokeBorder(Color.hairline, lineWidth: 1)
                    )
                    .padding(.bottom, avatarSize / 2)

                CommunityAvatar(community: community, size: avatarSize)
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: (avatarSize + 6) * 0.28, style: .continuous)
                            .fill(Color.appBackground)
                    )
                    .padding(.leading, DS.Spacing.l)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(community.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(CommunityFormat.summary(community))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            tags

            Text(community.description.isEmpty ? "No description yet." : community.description)
                .font(.body)
                .foregroundStyle(community.description.isEmpty ? Color.secondary : Color.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var banner: some View {
        let tint = CommunityPalette.color(for: community.name)
        let fallback = LinearGradient(
            colors: [tint.opacity(0.55), tint.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        if let urlString = community.bannerURL,
           !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ArkadAsyncImage(urlString: urlString) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallback
            }
        } else {
            fallback
        }
    }

    private var tags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                CommunityPriceTag(community: community)
                if !community.requiresSubscription {
                    Tag(text: "Free", systemImage: "gift.fill", tint: .marketGreen)
                }
                Tag(text: community.type.displayName, systemImage: community.typeIcon, tint: .secondary)
                if community.isPrivate {
                    Tag(text: "Private", systemImage: "lock.fill", tint: .secondary)
                }
                if community.isRecentlyActive {
                    Tag(text: community.lastActivityText, systemImage: "circle.fill", tint: .marketGreen)
                }
                if isMember {
                    JoinedTag()
                }
            }
        }
    }
}

// MARK: - About content

struct CommunityAboutView: View {
    let community: Community
    /// Change it to load everything again (pull to refresh)
    var reloadToken = 0

    @StateObject private var model = CommunityAboutViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            LeaderRecordCard(
                leader: model.leader,
                phase: model.statsPhase,
                onRetry: { Task { await model.load(community: community) } }
            )
            whatsInside
            if !model.recentResults.isEmpty {
                recentResults
            }
        }
        .task(id: "\(community.id)|\(reloadToken)") {
            await model.load(community: community)
        }
    }

    // MARK: - What's inside

    private var whatsInside: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "What's inside")
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                if let channels = model.channels {
                    insideRow(
                        icon: "number",
                        title: channels.isEmpty ? "No channels yet" : (channels.count == 1 ? "1 channel" : "\(channels.count) channels"),
                        detail: channels.isEmpty ? nil : channels.map { "#\($0.name)" }.joined(separator: "  ")
                    )
                } else if !model.hasLoaded {
                    insideRow(icon: "number", title: "Channels", detail: "Loading…")
                }

                if let count = model.courseCount {
                    insideRow(
                        icon: "graduationcap.fill",
                        title: count == 0 ? "No courses yet" : (count == 1 ? "1 course" : "\(count) courses"),
                        detail: count == 0 ? nil : "Step-by-step lessons in the Classroom"
                    )
                }

                if let event = model.nextEvent {
                    insideRow(
                        icon: "calendar",
                        title: "Next event: \(event.title)",
                        detail: event.isLive()
                            ? "Live now · \(EventFormat.timeRange(event))"
                            : "\(EventFormat.day(event.startsAt)) · \(EventFormat.timeRange(event))"
                    )
                } else if model.eventsReadable {
                    insideRow(icon: "calendar", title: "No upcoming events", detail: nil)
                }

                insideRow(
                    icon: "person.2.fill",
                    title: CommunityFormat.members(community.memberCount),
                    detail: community.isPrivate ? "Private: hidden from Discover and search" : "Open to anyone on Arkad"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    private func insideRow(icon: String, title: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            IconWell(systemName: icon, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minHeight: 36)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Recent results

    private var recentResults: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Recent results")
            CommunityCardList(items: model.recentResults, dividerInset: 64) { result in
                CalloutResultRow(result: result)
            }
        }
    }
}

// MARK: - Leader record

/// The leader's record from traderStats/{ownerId}: win rate, average result and the number
/// of closed callouts, once there are enough of them (TraderStats.isRanked). Only callouts
/// whose entry and exit were checked against a live price are in those stats.
struct LeaderRecordCard: View {
    let leader: CommunityAboutViewModel.Leader?
    let phase: CommunityAboutViewModel.StatsPhase
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            identity
            content
            Label(footnote, systemImage: "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var footnote: String {
        let rule = "Only callouts with entry and exit checked against a live price count."
        return AppConfig.serverFunctionsEnabled ? rule : "\(rule) Tracked by the app."
    }

    private var identity: some View {
        HStack(spacing: DS.Spacing.m) {
            UserAvatar(username: leader?.username ?? "", fullName: leader?.fullName, imageURL: leader?.imageURL, size: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text("Led by")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(leader.map { "@\($0.username)" } ?? "The owner")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Tag(text: "Track record", systemImage: "chart.line.uptrend.xyaxis")
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            HStack(spacing: DS.Spacing.m) {
                ProgressView()
                Text("Loading track record…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .failed:
            HStack(spacing: DS.Spacing.m) {
                Text("Couldn't load the track record.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("Try again", action: onRetry)
                    .buttonStyle(PillButtonStyle(kind: .neutral))
            }

        case .loaded(let stats):
            if let stats, stats.isRanked {
                record(stats)
            } else if let stats, stats.calloutsClosed > 0 {
                building(stats)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No checked callouts yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    if let open = stats?.openCallouts, open > 0 {
                        Text(open == 1 ? "1 open callout is being tracked." : "\(open) open callouts are being tracked.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func record(_ stats: TraderStats) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            metric("Win rate", TraderStats.formatWinRate(stats.winRatePercent), .primary)
            metric("Avg result", TraderStats.formatPercent(stats.avgReturnPercent), TraderStats.color(for: stats.avgReturnPercent))
            metric("Closed", "\(stats.calloutsClosed)", .primary)
        }
    }

    /// Fewer closed callouts than a full record needs: progress only, no win rate yet.
    private func building(_ stats: TraderStats) -> some View {
        let needed = TraderStats.minimumClosedCallouts
        let closed = min(stats.calloutsClosed, needed)
        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Building a record: \(closed) of \(needed) closed callouts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
            ProgressView(value: Double(closed), total: Double(needed))
                .tint(Color.arkadGold)
            Text("Win rate and results show after \(needed) closed callouts.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .arkadNumber(24)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Result row

struct CalloutResultRow: View {
    let result: CalloutResultSummary

    private var tint: Color { TraderStats.color(for: result.resultPercent) }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(
                systemName: result.resultPercent >= 0 ? "arrow.up.right" : "arrow.down.right",
                tint: result.resultPercent == 0 ? .secondary : tint,
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(result.ticker)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.primary)
                    if let direction = result.direction {
                        Text(direction.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(direction.color)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.s)

            VStack(alignment: .trailing, spacing: 2) {
                Text(TraderStats.formatPercent(result.resultPercent))
                    .arkadNumber(17)
                    .foregroundStyle(tint)
                Label(result.isPriceChecked ? "Price checked" : "Unchecked",
                      systemImage: result.isPriceChecked ? "checkmark.seal.fill" : "exclamationmark.circle")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(result.isPriceChecked ? Color.goldText : Color.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let status = result.status { parts.append(status.displayName) }
        if let exit = result.exitPrice { parts.append("Exit \(TradeCallout.formatPrice(exit))") }
        if result.postedAt != .distantPast {
            parts.append(result.postedAt.formatted(.relative(presentation: .named)))
        }
        return parts.joined(separator: " · ")
    }
}
