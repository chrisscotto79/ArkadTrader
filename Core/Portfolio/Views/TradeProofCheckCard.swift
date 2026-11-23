// File: Core/Portfolio/Views/TradeProofCheckCard.swift
// Shown before a trade is saved or closed: the proof label it will get and why, plus a one-tap
// "use current price" helper, and "Try again" when live prices are unavailable.
// The decision itself is TradePriceCheckRules.evaluate.

import SwiftUI

struct TradeProofCheckCard: View {
    let outcome: PriceCheckOutcome
    let message: String
    /// The live price, already formatted ("$187.20"), when there is one
    var currentPriceText: String? = nil
    /// Shown only when the typed price differs from the live one
    var showsUseCurrentPrice = false
    var onUseCurrentPrice: (() -> Void)? = nil
    /// Shown when live prices are unavailable right now
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .center, spacing: DS.Spacing.s) {
                Text("Proof label")
                    .font(.headline)
                Spacer(minLength: DS.Spacing.s)
                if outcome.isChecking {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Checking")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                } else if outcome.isQuotesUnavailable {
                    Label("Unavailable", systemImage: "wifi.exclamationmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    TradeProofBadge(proof: outcome.proof)
                }
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .animation(nil, value: message)

            if outcome.isQuotesUnavailable, let onRetry {
                Button {
                    onRetry()
                } label: {
                    Label("Try again", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(PillButtonStyle(kind: .neutral))
            }

            if showsUseCurrentPrice, let currentPriceText, let onUseCurrentPrice {
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    onUseCurrentPrice()
                } label: {
                    Label("Use current price \(currentPriceText)", systemImage: "dot.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(PillButtonStyle(kind: .neutral))
            }

            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    private var footnote: String {
        if outcome.proof == .priceChecked {
            return "Price-checked trades count toward your win rate and P&L."
        }
        return "Self-reported trades stay in your portfolio but don't count toward your win rate or P&L."
    }
}
