// File: Core/Communities/Views/Callouts/CalloutCardView.swift
// Card shown in chat for a structured trade callout: ticker, direction, status,
// entry / stop / target levels and the Track in Portfolio action.

import SwiftUI

struct CalloutCardView: View {
    let callout: TradeCallout
    let authorUsername: String
    /// Whether the viewer may change the callout's status (author or community admin)
    let canManage: Bool
    let onTrack: () -> Void
    let onUpdateStatus: (TradeCallout.Status) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            header
            levels
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
    }

    private var accessibilitySummary: String {
        var parts = ["\(callout.direction.displayName) callout on \(callout.ticker)",
                     "entry \(TradeCallout.formatPrice(callout.entryPrice))"]
        if let stop = callout.stopPrice { parts.append("stop \(TradeCallout.formatPrice(stop))") }
        if let target = callout.targetPrice { parts.append("target \(TradeCallout.formatPrice(target))") }
        parts.append("status \(callout.status.displayName)")
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

            Tag(text: callout.status.displayName, systemImage: callout.status.icon, tint: callout.status.color)
        }
    }

    // MARK: - Levels

    private var levels: some View {
        HStack(spacing: 0) {
            levelColumn(title: "Entry", value: TradeCallout.formatPrice(callout.entryPrice), detail: nil, color: .primary)
            levelDivider
            levelColumn(
                title: "Stop",
                value: callout.stopPrice.map(TradeCallout.formatPrice) ?? "—",
                detail: callout.stopPrice.map { String(format: "%+.1f%%", callout.percentMove(to: $0)) },
                color: callout.stopPrice == nil ? .secondary : .marketRed
            )
            levelDivider
            levelColumn(
                title: "Target",
                value: callout.targetPrice.map(TradeCallout.formatPrice) ?? "—",
                detail: callout.targetPrice.map { String(format: "%+.1f%%", callout.percentMove(to: $0)) },
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

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: DS.Spacing.s) {
            Button(action: onTrack) {
                Label(callout.status == .open ? "Track in Portfolio" : "Callout \(callout.status.displayName.lowercased())",
                      systemImage: callout.status == .open ? "plus" : callout.status.icon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(kind: callout.status == .open ? .gold : .neutral))
            .disabled(callout.status != .open)

            if canManage {
                Menu {
                    Section("Update status") {
                        ForEach(TradeCallout.Status.allCases, id: \.self) { status in
                            Button {
                                onUpdateStatus(status)
                            } label: {
                                if status == callout.status {
                                    Label(status.displayName, systemImage: "checkmark")
                                } else {
                                    Text(status.displayName)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.surfaceRaised))
                }
                .accessibilityLabel("Update callout status")
            }
        }
    }
}

#Preview {
    CalloutCardView(
        callout: TradeCallout(
            ticker: "AAPL", assetType: .stock, direction: .long,
            entryPrice: 182.45, stopPrice: 178, targetPrice: 195,
            note: "Breakout over the 50-day with volume."
        ),
        authorUsername: "trader",
        canManage: true,
        onTrack: {},
        onUpdateStatus: { _ in }
    )
    .padding()
    .screenBackground()
}
