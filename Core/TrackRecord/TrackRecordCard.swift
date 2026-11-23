// File: Core/TrackRecord/TrackRecordCard.swift
// A trader's callout record: win rate, returns and counts, read from `traderStats`.
// Self-loading, so any screen can drop it in with just a user id.

import SwiftUI

struct TrackRecordCard: View {
    let userId: String
    /// Limit the record to one community's callouts; nil for the record across Arkad.
    var communityId: String? = nil

    private enum Phase: Equatable {
        case loading
        case loaded(TraderStats?)
        case failed(String)
    }

    @State private var phase: Phase = .loading
    /// The user / community the current `phase` belongs to
    @State private var loadedKey: String?

    private var loadKey: String { "\(userId)|\(communityId ?? "")" }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            header
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .task(id: loadKey) { await load() }
    }

    // MARK: - Header

    private var subtitle: String {
        if communityId != nil {
            return AppConfig.serverFunctionsEnabled ? "Callouts in this community" : "Callouts in this community, tracked by the app"
        }
        return TraderStats.sourceNote
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: "checkmark.seal.fill", size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("Callout record")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            HStack(spacing: DS.Spacing.m) {
                ProgressView()
                Text("Loading record…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DS.Spacing.s)

        case .failed(let message):
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text("Couldn't load the callout record")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again") {
                    Task { await load() }
                }
                .buttonStyle(PillButtonStyle(kind: .neutral))
                .padding(.top, DS.Spacing.xs)
            }

        case .loaded(let stats):
            if let stats, stats.hasCallouts {
                if stats.isRanked {
                    fullRecord(stats)
                } else {
                    building(stats)
                }
            } else {
                noCallouts
            }
        }
    }

    private var noCallouts: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No callouts yet")
                .font(.subheadline.weight(.semibold))
            Text("Results from trade callouts posted in communities show up here. Only callouts whose entry was checked against a live price count.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Fewer than the minimum closed callouts: show progress, hold back the ratios.
    private func building(_ stats: TraderStats) -> some View {
        let needed = TraderStats.minimumClosedCallouts
        let closed = min(stats.calloutsClosed, needed)
        return VStack(alignment: .leading, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text("Not enough closed callouts yet (\(closed)/\(needed))")
                    .font(.subheadline.weight(.semibold))
                ProgressView(value: Double(closed), total: Double(needed))
                    .tint(Color.arkadGold)
                Text("Win rate and returns appear after \(needed) closed callouts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                metric("Closed", "\(stats.calloutsClosed)", .primary)
                metric("Open", "\(stats.openCallouts)", .primary)
                metric("Posted", "\(stats.calloutsTotal)", .primary)
            }
        }
    }

    private func fullRecord(_ stats: TraderStats) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.l) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Win rate")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(TraderStats.formatWinRate(stats.winRatePercent))
                        .arkadNumber(32)
                        .foregroundStyle(Color.primary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg return")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(TraderStats.formatPercent(stats.avgReturnPercent))
                        .arkadNumber(32)
                        .foregroundStyle(TraderStats.color(for: stats.avgReturnPercent))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }

            Grid(alignment: .leading, horizontalSpacing: DS.Spacing.m, verticalSpacing: DS.Spacing.m) {
                GridRow {
                    metric("Closed", "\(stats.calloutsClosed)", .primary)
                    metric("Open", "\(stats.openCallouts)", .primary)
                    metric("Wins · losses", "\(stats.wins) · \(stats.losses)", .primary)
                }
                GridRow {
                    metric("Best call", stats.bestCalloutPercent.map(TraderStats.formatPercent) ?? "—",
                           stats.bestCalloutPercent.map(TraderStats.color(for:)) ?? .secondary)
                    metric("Worst call", stats.worstCalloutPercent.map(TraderStats.formatPercent) ?? "—",
                           stats.worstCalloutPercent.map(TraderStats.color(for:)) ?? .secondary)
                    metric(TraderStats.sumOfResultsTitle, TraderStats.formatPercent(stats.totalReturnPercent),
                           TraderStats.color(for: stats.totalReturnPercent))
                }
            }

            if let updatedAt = stats.updatedAt {
                Text("Updated \(updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .arkadNumber(15, weight: .semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Loading

    private func load() async {
        let key = loadKey
        // Keep showing a loaded record while refreshing the same one
        if loadedKey != key { phase = .loading }
        do {
            let stats = try await TraderStatsService.shared.stats(userId: userId, communityId: communityId)
            phase = .loaded(stats)
            loadedKey = key
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(TraderStats.friendlyLoadMessage(for: error))
        }
    }
}

#Preview {
    ScrollView {
        TrackRecordCard(userId: "")
            .padding()
    }
    .screenBackground()
}
