// File: Core/Brokerage/BrokerageHoldingsSection.swift
// Portfolio section listing holdings synced from linked brokerages (users/{uid}/brokerageHoldings).

import SwiftUI

struct BrokerageHoldingsSection: View {
    let holdings: [BrokerageHolding]
    let onManage: () -> Void

    private var totalValue: Double { holdings.reduce(0) { $0 + $1.marketValue } }

    private var lastUpdated: Date? { holdings.compactMap(\.updatedAt).max() }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(
                title: "Brokerage holdings",
                count: holdings.count,
                actionTitle: "Manage",
                action: onManage
            )

            LazyVStack(spacing: 0) {
                ForEach(holdings) { holding in
                    BrokerageHoldingRow(holding: holding)
                    if holding.id != holdings.last?.id {
                        Divider()
                            .overlay(Color.hairline)
                            .padding(.leading, 56)
                    }
                }
            }
            .cardStyle(padding: 0)

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.marketGreen)
                Text(footnote)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, DS.Spacing.xs)
        }
    }

    private var footnote: String {
        var text = "\(totalValue.asCurrency) at your brokerage"
        if let lastUpdated {
            text += " · updated \(lastUpdated.formatted(.relative(presentation: .named)))"
        }
        return text
    }
}

private struct BrokerageHoldingRow: View {
    let holding: BrokerageHolding

    private var terms: AssetTerms { AssetTerms(holding.assetType) }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            AssetTickerBadge(symbol: holding.symbol, type: holding.assetType)

            VStack(alignment: .leading, spacing: 3) {
                Text(holding.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.s)

            VStack(alignment: .trailing, spacing: 3) {
                Text(holding.marketValue.asCurrency)
                    .arkadNumber(15, weight: .semibold)
                    .foregroundStyle(Color.primary)
                if holding.hasCostBasis {
                    Text("\(holding.unrealizedPL.asCurrencyWithSign) (\(String(format: "%+.1f%%", holding.unrealizedPLPercent)))")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(holding.unrealizedPL >= 0 ? Color.marketGreen : Color.marketRed)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private var detailLine: String {
        var parts = [terms.quantityText(holding.quantity, symbol: holding.symbol)]
        if holding.averagePrice > 0 {
            parts.append("avg \(terms.price(holding.averagePrice))")
        }
        if !holding.brokerageName.isEmpty {
            parts.append(holding.brokerageName)
        }
        return parts.joined(separator: " · ")
    }
}
