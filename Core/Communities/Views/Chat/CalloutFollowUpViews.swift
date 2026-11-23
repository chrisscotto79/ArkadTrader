// File: Core/Communities/Views/Chat/CalloutFollowUpViews.swift
// Chat rendering for the follow-ups an author posts on their own callout:
// - CalloutUpdateRow: a compact "↳ $TSLA update" row (trim, add, move stop / target, note)
// - CalloutResultCard: the result after a callout closes, green for wins and red for losses

import SwiftUI

// MARK: - Update row

struct CalloutUpdateRow: View {
    let update: CalloutUpdate
    /// The callout being updated, when its message is loaded
    let parent: TradeCallout?
    /// The message's text summary (shown when the parent isn't loaded)
    let summary: String
    /// Scrolls to the callout; nil when it isn't loaded
    var onOpenParent: (() -> Void)? = nil

    private var ticker: String? { parent?.ticker ?? Self.ticker(in: summary) }

    /// "$TSLA" from a summary like "Trimmed 50% of $TSLA at $251.20"
    static func ticker(in summary: String) -> String? {
        summary.split(separator: " ").first { $0.hasPrefix("$") && $0.count > 1 && !$0.dropFirst().first!.isNumber }
            .map { String($0.dropFirst()).trimmingCharacters(in: .punctuationCharacters) }
    }

    private var headline: String {
        guard let ticker else { return summary }
        return update.headline(ticker: ticker)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            parentLink

            HStack(alignment: .top, spacing: DS.Spacing.m) {
                IconWell(systemName: update.kind.icon, tint: update.kind.tint, size: 32)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(update.kind.displayName.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(update.kind.tint)
                        if let percent = update.percent, update.kind.usesPercent {
                            Text(CalloutUpdate.formatShare(percent))
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    if update.kind != .note {
                        Text(headline)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let note = update.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    } else if update.kind == .note {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .cardStyle(padding: DS.Spacing.m, radius: DS.Radius.m)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(update.kind.tint.opacity(0.7))
                .frame(width: 3)
                .padding(.vertical, DS.Spacing.m)
        }
        .frame(maxWidth: 360, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var parentLink: some View {
        Button {
            onOpenParent?()
        } label: {
            HStack(spacing: 4) {
                Text("↳")
                    .font(.caption.weight(.bold))
                Text(ticker.map { "$\($0) update" } ?? "Callout update")
                    .font(.caption.weight(.semibold))
                if let parent {
                    Text("· \(parent.direction.displayName)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(parent.direction.color)
                }
                if onOpenParent != nil {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onOpenParent == nil)
        .accessibilityHint(onOpenParent == nil ? "" : "Shows the callout")
    }
}

// MARK: - Result card

struct CalloutResultCard: View {
    let result: CalloutResult
    /// The callout this result closes, when it's loaded
    var parent: TradeCallout? = nil
    /// Scrolls to the callout; nil when it isn't loaded
    var onOpenParent: (() -> Void)? = nil

    /// "Price checked" needs both ends checked: the callout's entry and this exit. With the
    /// callout not loaded, only the exit can be vouched for.
    private var checkLabel: String {
        guard result.isPriceChecked else { return "Unchecked" }
        guard let parent else { return "Exit checked" }
        return parent.isPriceChecked ? "Price checked" : "Entry unchecked"
    }

    private var isFullyChecked: Bool { result.isPriceChecked && parent?.isPriceChecked == true }

    private var icon: String {
        switch result.status {
        case .targetHit: return "checkmark.circle.fill"
        case .stoppedOut: return "xmark.octagon.fill"
        default: return result.resultPercent > 0 ? "arrow.up.right" : (result.resultPercent < 0 ? "arrow.down.right" : "equal")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .center, spacing: DS.Spacing.m) {
                IconWell(systemName: icon, tint: result.tint, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("$\(result.ticker)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Tag(text: result.direction.displayName.uppercased(), tint: result.direction.color)
                    }
                    Label("Callout result", systemImage: "flag.checkered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }

                Spacer(minLength: DS.Spacing.s)

                Text(TradeCallout.formatPercent(result.resultPercent))
                    .arkadNumber(24)
                    .foregroundStyle(result.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            HStack(spacing: DS.Spacing.s) {
                Tag(text: result.howClosed, systemImage: result.status.icon, tint: result.tint)
                Text("Exit \(TradeCallout.formatPrice(result.exitPrice))")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Label(checkLabel, systemImage: isFullyChecked ? "checkmark.shield.fill" : "questionmark.circle")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isFullyChecked ? Color.goldText : Color.secondary)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .fixedSize()
            }

            if let onOpenParent {
                Button(action: onOpenParent) {
                    Label("View callout", systemImage: "arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.goldText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.l)
        .background {
            // A soft wash of the result colour over the card surface
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .fill(Color.surface)
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .fill(result.tint.opacity(0.08))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .strokeBorder(result.tint.opacity(0.35), lineWidth: 1)
        )
        .frame(maxWidth: 360)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.direction.displayName) callout on \(result.ticker), \(result.howClosed), result \(TradeCallout.formatPercent(result.resultPercent)), exit \(TradeCallout.formatPrice(result.exitPrice)), \(checkLabel)")
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            CalloutUpdateRow(
                update: CalloutUpdate(parentMessageId: "p", kind: .trim, price: 251.2, percent: 50, note: "Paying myself into strength."),
                parent: nil,
                summary: "Trimmed 50% of $TSLA at $251.20. Paying myself into strength."
            )
            CalloutResultCard(result: CalloutResult(parentMessageId: "p", ticker: "TSLA", direction: .long,
                                                    status: .targetHit, exitPrice: 270, resultPercent: 8.4, exitCheck: .live))
            CalloutResultCard(result: CalloutResult(parentMessageId: "p", ticker: "AAPL", direction: .short,
                                                    status: .stoppedOut, exitPrice: 190, resultPercent: -2.1, exitCheck: .unchecked))
        }
        .padding()
    }
    .screenBackground()
}
