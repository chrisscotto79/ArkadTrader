// File: Core/Communities/Views/Callouts/CalloutCardView.swift
// Card shown in chat for a structured trade callout: ticker, direction, status,
// entry / stop / target levels, the live move or final result, and its actions
// (Track in Portfolio; Close callout for the author).

import SwiftUI

struct CalloutCardView: View {
    let callout: TradeCallout
    let authorUsername: String
    /// Where the callout lives. Needed for the author's Close callout action.
    let messageId: String?
    let channelId: String?
    let communityId: String?
    /// The message's author; used when an older callout has no `authorId` of its own.
    let authorId: String?
    let onTrack: () -> Void

    @State private var showCloseSheet = false

    init(
        callout: TradeCallout,
        authorUsername: String,
        canManage: Bool = false,
        messageId: String? = nil,
        channelId: String? = nil,
        communityId: String? = nil,
        authorId: String? = nil,
        onTrack: @escaping () -> Void,
        onUpdateStatus: @escaping (TradeCallout.Status) -> Void = { _ in }
    ) {
        // `canManage` and `onUpdateStatus` are no longer used: a status can't be set by hand
        // without a result, so only the author's Close callout (with an exit price) remains.
        self.callout = callout
        self.authorUsername = authorUsername
        self.messageId = messageId
        self.channelId = channelId
        self.communityId = communityId
        self.authorId = authorId
        self.onTrack = onTrack
    }

    private var resolvedAuthorId: String? { callout.authorId ?? authorId }
    private var resolvedCommunityId: String? { communityId ?? callout.communityId }

    /// The signed-in author can close an open callout once we know where it's stored.
    private var canClose: Bool {
        guard callout.isOpen,
              let me = FirebaseAuthService.shared.currentUser?.id,
              me == resolvedAuthorId,
              messageId != nil, channelId != nil, resolvedCommunityId != nil else { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            header
            levels
            if callout.isOpen {
                liveMove
            } else {
                result
            }
            if let marker = progressMarker {
                CalloutProgressBar(callout: callout, marker: marker)
            }
            if let note = callout.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            actions
        }
        .cardStyle(padding: DS.Spacing.l, radius: DS.Radius.l)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .sheet(isPresented: $showCloseSheet) {
            if let messageId, let channelId, let communityId = resolvedCommunityId {
                CloseCalloutSheet(callout: callout) { exitPrice in
                    _ = try await CalloutTrackingService.shared.closeCallout(
                        callout,
                        exitPrice: exitPrice,
                        communityId: communityId,
                        channelId: channelId,
                        messageId: messageId,
                        authorId: authorId
                    )
                }
            }
        }
    }

    private var accessibilitySummary: String {
        var parts = ["\(callout.direction.displayName) callout on \(callout.ticker)",
                     "entry \(TradeCallout.formatPrice(callout.entryPrice))"]
        if let stop = callout.stopPrice { parts.append("stop \(TradeCallout.formatPrice(stop))") }
        if let target = callout.targetPrice { parts.append("target \(TradeCallout.formatPrice(target))") }
        parts.append("status \(callout.status.displayName)")
        if let live = callout.livePercent { parts.append("now \(TradeCallout.formatPercent(live))") }
        if let final = callout.finalPercent { parts.append("result \(TradeCallout.formatPercent(final))") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            IconWell(systemName: callout.direction.icon, tint: callout.direction.color, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("$\(callout.ticker)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Tag(text: callout.direction.displayName.uppercased(), tint: callout.direction.color)
                }
                Label("\(callout.assetType.displayName) callout", systemImage: "megaphone.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }

            Spacer(minLength: DS.Spacing.s)

            Tag(text: callout.status.displayName, systemImage: callout.status.icon, tint: statusTint)
        }
    }

    /// Manually closed callouts take the colour of their result.
    private var statusTint: Color {
        guard callout.status == .closed, let final = callout.finalPercent else { return callout.status.color }
        return final > 0 ? .marketGreen : (final < 0 ? .marketRed : .secondary)
    }

    // MARK: - Levels

    private var levels: some View {
        HStack(spacing: 0) {
            levelColumn(title: "Entry", value: TradeCallout.formatPrice(callout.entryPrice), detail: nil, color: .primary)
            levelDivider
            levelColumn(
                title: "Stop",
                value: callout.stopPrice.map(TradeCallout.formatPrice) ?? "—",
                detail: callout.stopPrice.map { TradeCallout.formatPercent(callout.percentMove(to: $0)) },
                color: callout.stopPrice == nil ? .secondary : .marketRed
            )
            levelDivider
            levelColumn(
                title: "Target",
                value: callout.targetPrice.map(TradeCallout.formatPrice) ?? "—",
                detail: callout.targetPrice.map { TradeCallout.formatPercent(callout.percentMove(to: $0)) },
                color: callout.targetPrice == nil ? .secondary : .marketGreen
            )
            if let rr = callout.riskReward {
                levelDivider
                levelColumn(title: "R:R", value: String(format: "%.1f", rr), detail: nil, color: .goldText)
            }
        }
        .padding(.vertical, DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous).fill(Color.surfaceRaised)
        )
    }

    private var levelDivider: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(width: 1, height: 34)
    }

    private func levelColumn(title: String, value: String, detail: String?, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .arkadNumber(15)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let detail {
                Text(detail)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - Live move (open)

    @ViewBuilder
    private var liveMove: some View {
        if let lastPrice = callout.lastPrice, let live = callout.livePercent {
            HStack(spacing: DS.Spacing.s) {
                ChangePill(text: TradeCallout.formatPercent(live), isPositive: live >= 0)
                Text(TradeCallout.formatPrice(lastPrice))
                    .arkadNumber(14, weight: .semibold)
                    .foregroundStyle(Color.primary)
                if let at = callout.lastPriceAt {
                    Text("as of \(TradeCallout.formatTime(at))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        } else {
            Label("Waiting for the first price check", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Result (closed)

    private var result: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RESULT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Text(callout.finalPercent.map(TradeCallout.formatPercent) ?? "—")
                    .arkadNumber(22)
                    .foregroundStyle(callout.finalPercent.map(TraderStats.color(for:)) ?? .secondary)
            }

            Spacer(minLength: DS.Spacing.s)

            VStack(alignment: .trailing, spacing: 2) {
                if let exit = callout.exitPrice {
                    Text("Exit \(TradeCallout.formatPrice(exit))")
                        .arkadNumber(14, weight: .semibold)
                        .foregroundStyle(Color.primary)
                }
                if let closedAt = callout.closedAt {
                    Text("Closed \(closedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(statusTint.opacity(0.1))
        )
    }

    // MARK: - Progress

    /// Exit price once closed, last price while open. Nil when there's nothing to plot.
    private var progressMarker: Double? {
        guard callout.stopPrice != nil, callout.targetPrice != nil else { return nil }
        let price = callout.isOpen ? callout.lastPrice : callout.exitPrice
        return price.flatMap { callout.progress(at: $0) } ?? callout.progress(at: callout.entryPrice)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: DS.Spacing.s) {
            Button(action: onTrack) {
                Label(callout.isOpen ? "Track in Portfolio" : "Callout \(callout.status.displayName.lowercased())",
                      systemImage: callout.isOpen ? "plus" : callout.status.icon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(kind: callout.isOpen ? .gold : .neutral))
            .disabled(!callout.isOpen)

            if canClose {
                Button {
                    showCloseSheet = true
                } label: {
                    Label("Close callout", systemImage: "flag.checkered")
                }
                .buttonStyle(PillButtonStyle(kind: .neutral))
            }
        }
    }
}

// MARK: - Progress bar

/// A bar from stop (left) to target (right) with a tick at entry and a dot at the current
/// or exit price (at entry until the first price check). Only shown when both a stop and a target are set.
struct CalloutProgressBar: View {
    let callout: TradeCallout
    /// Position of the price being shown, 0 = stop, 1 = target (clamped for drawing)
    let marker: Double

    private var entryPosition: Double { callout.progress(at: callout.entryPrice) ?? 0.5 }
    private var markerColor: Color { marker >= entryPosition ? .marketGreen : .marketRed }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let clampedMarker = CGFloat(min(max(marker, 0), 1))
                let clampedEntry = CGFloat(min(max(entryPosition, 0), 1))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.marketRed.opacity(0.35), Color.surfaceRaised, Color.marketGreen.opacity(0.35)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 6)
                    Rectangle()
                        .fill(Color.secondary)
                        .frame(width: 2, height: 12)
                        .offset(x: clampedEntry * width - 1)
                    Circle()
                        .fill(markerColor)
                        .overlay(Circle().strokeBorder(Color.surface, lineWidth: 2))
                        .frame(width: 12, height: 12)
                        .offset(x: clampedMarker * width - 6)
                }
                .frame(height: 12)
            }
            .frame(height: 12)

            HStack {
                Text("Stop")
                Spacer()
                Text("Target")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress to target: \(Int((min(max(marker, 0), 1) * 100).rounded())) percent of the way from stop to target")
    }
}

// MARK: - Formatting

extension TradeCallout {
    /// "+4.2%"
    static func formatPercent(_ value: Double) -> String {
        String(format: "%+.1f%%", value)
    }

    /// "2:15 PM" today, otherwise "Nov 3, 2:15 PM".
    static func formatTime(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}

#Preview {
    VStack(spacing: 16) {
        CalloutCardView(
            callout: TradeCallout(
                ticker: "AAPL", assetType: .stock, direction: .long,
                entryPrice: 182.45, stopPrice: 178, targetPrice: 195,
                note: "Breakout over the 50-day with volume.",
                lastPrice: 186.10, lastPriceAt: Date()
            ),
            authorUsername: "trader",
            onTrack: {}
        )
        CalloutCardView(
            callout: TradeCallout(
                ticker: "TSLA", assetType: .stock, direction: .short,
                entryPrice: 250, stopPrice: 262, targetPrice: 230,
                status: .closed, exitPrice: 238, closedAt: Date(), resultPercent: 4.8
            ),
            authorUsername: "trader",
            onTrack: {}
        )
    }
    .padding()
    .screenBackground()
}
