// File: Core/Communities/Views/Chat/TradeShareCard.swift
// Chat card for a shared trade (`tradeShare` on a channel message): ticker, asset type, entry,
// exit and P&L % once closed ("Open" before), the proof label and the trader's note.
// The numbers are a copy of the author's trade doc, checked by the rules when it was shared.

import SwiftUI

struct TradeShareCard: View {
    let share: TradeShareInfo

    private var resultTint: Color {
        guard let result = share.resultPercent else { return .goldText }
        return TraderStats.color(for: result)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            header
            levels
            if let note = share.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DS.Spacing.s) {
                TradeProofBadge(proof: share.proof)
                Spacer(minLength: 0)
                Text(share.quantity.quantityString + " " + unitLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .cardStyle(padding: DS.Spacing.l, radius: DS.Radius.l)
        .frame(maxWidth: 360)
        .accessibilityElement(children: .combine)
    }

    private var unitLabel: String {
        switch share.assetType {
        case .option: return share.quantity == 1 ? "contract" : "contracts"
        case .stock: return share.quantity == 1 ? "share" : "shares"
        default: return "units"
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            IconWell(systemName: share.assetType?.icon ?? "chart.line.uptrend.xyaxis", tint: .goldText, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("$\(share.ticker)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Tag(text: (share.assetType?.displayName ?? share.tradeType.capitalized).uppercased(), tint: .secondary)
                }
                Label("Shared trade", systemImage: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }

            Spacer(minLength: DS.Spacing.s)

            if let result = share.resultPercent {
                ChangePill(text: TradeCallout.formatPercent(result), isPositive: result >= 0)
            } else {
                Tag(text: "Open", systemImage: "circle.fill", tint: .goldText)
            }
        }
    }

    private var levels: some View {
        HStack(spacing: 0) {
            column(title: "Entry", value: TradeCallout.formatPrice(share.entryPrice), color: .primary)
            Rectangle().fill(Color.hairline).frame(width: 1, height: 34)
            column(title: "Exit",
                   value: share.isOpen ? "Open" : (share.exitPrice.map(TradeCallout.formatPrice) ?? "—"),
                   color: share.isOpen ? .secondary : .primary)
            Rectangle().fill(Color.hairline).frame(width: 1, height: 34)
            column(title: "P&L",
                   value: share.resultPercent.map(TradeCallout.formatPercent) ?? "—",
                   color: share.resultPercent == nil ? .secondary : resultTint)
        }
        .padding(.vertical, DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous).fill(Color.surfaceRaised)
        )
    }

    private func column(title: String, value: String, color: Color) -> some View {
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
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        TradeShareCard(share: TradeShareInfo(tradeId: "t", ticker: "AAPL", tradeType: "stock", entryPrice: 182.45,
                                             quantity: 10, isOpen: false, exitPrice: 190, proof: .priceChecked,
                                             note: "Took it off into earnings."))
        TradeShareCard(share: TradeShareInfo(tradeId: "t", ticker: "BTC", tradeType: "crypto", entryPrice: 64000,
                                             quantity: 0.05, isOpen: true, exitPrice: nil, proof: .selfReported, note: nil))
    }
    .padding()
    .screenBackground()
}
