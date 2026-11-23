// File: Core/Portfolio/Views/TradeProofCheckCard.swift
// Shown before a trade is saved or closed: the proof label it will get and why, plus a one-tap
// "use current price" helper. The decision itself is TradePriceCheckRules.evaluate.

import SwiftUI

struct TradeProofCheckCard: View {
    let outcome: PriceCheckOutcome
    let message: String
    /// The live price, already formatted ("$187.20"), when there is one
    var currentPriceText: String? = nil
    /// Shown only when the typed price differs from the live one
    var showsUseCurrentPrice = false
    var onUseCurrentPrice: (() -> Void)? = nil

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
                } else {
                    TradeProofBadge(proof: outcome.proof)
                }
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .animation(nil, value: message)

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

            Text(outcome.proof == .priceChecked
                 ? "Price-checked trades count toward your win rate and P&L."
                 : "Self-reported trades stay in your portfolio but don't count toward your win rate or P&L.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }
}
