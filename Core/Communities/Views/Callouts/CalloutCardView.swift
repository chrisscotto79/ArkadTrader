// File: Core/Communities/Views/Callouts/CalloutCardView.swift
// Card shown in chat for a structured trade callout.

import SwiftUI

struct CalloutCardView: View {
    let callout: TradeCallout
    let authorUsername: String
    /// Whether the viewer may change the callout's status (author or community admin)
    let canManage: Bool
    let onTrack: () -> Void
    let onUpdateStatus: (TradeCallout.Status) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            levels
            if let note = callout.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            actions
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(callout.direction.color.opacity(0.35), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(callout.direction.color)
                .frame(width: 4)
                .padding(.vertical, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(callout.direction.displayName) callout on \(callout.ticker), entry \(callout.entryPrice.asCurrency), status \(callout.status.displayName)")
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "megaphone.fill")
                .font(.caption)
                .foregroundColor(.arkadGold)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.arkadGold.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("$\(callout.ticker)")
                        .font(.headline)
                    Label(callout.direction.displayName, systemImage: callout.direction.icon)
                        .font(.caption.weight(.bold))
                        .foregroundColor(callout.direction.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(callout.direction.color.opacity(0.12)))
                }
                Text("\(callout.assetType.displayName) callout")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(callout.status.displayName)
                .font(.caption.weight(.semibold))
                .foregroundColor(callout.status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(callout.status.color.opacity(0.12)))
        }
    }

    private var levels: some View {
        HStack(spacing: 0) {
            levelColumn(title: "Entry", value: callout.entryPrice.asCurrency, detail: nil, color: .primary)
            Divider().frame(height: 36)
            levelColumn(
                title: "Stop",
                value: callout.stopPrice?.asCurrency ?? "—",
                detail: callout.stopPrice.map { String(format: "%+.1f%%", callout.percentMove(to: $0)) },
                color: .marketRed
            )
            Divider().frame(height: 36)
            levelColumn(
                title: "Target",
                value: callout.targetPrice?.asCurrency ?? "—",
                detail: callout.targetPrice.map { String(format: "%+.1f%%", callout.percentMove(to: $0)) },
                color: .marketGreen
            )
            if let rr = callout.riskReward {
                Divider().frame(height: 36)
                levelColumn(title: "R:R", value: String(format: "%.1f", rr), detail: nil, color: .arkadGold)
            }
        }
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemGroupedBackground)))
    }

    private func levelColumn(title: String, value: String, detail: String?, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: onTrack) {
                Label("Track in Portfolio", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.arkadGold))
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            .disabled(callout.status != .open)
            .opacity(callout.status == .open ? 1 : 0.5)

            if canManage {
                Menu {
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
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 40, height: 36)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemGroupedBackground)))
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("Update callout status")
            }
        }
    }
}
