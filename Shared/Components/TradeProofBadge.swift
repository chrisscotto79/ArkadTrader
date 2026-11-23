// File: Shared/Components/TradeProofBadge.swift
// The proof label on trades and trade-result posts: Verified, Price checked or Self-reported.
// See TradeProof (Shared/Models/Trade.swift) and docs/backend-contracts.md, section 0.

import SwiftUI

struct TradeProofBadge: View {
    let proof: TradeProof
    /// Compact is a bare icon + label for list rows; otherwise a tinted capsule like `Tag`
    var compact = false

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 3) {
                    Image(systemName: proof.systemImage)
                    Text(proof.label)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(proof.tint)
                .lineLimit(1)
                .fixedSize()
            } else {
                Tag(text: proof.label, systemImage: proof.systemImage, tint: proof.tint)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(proof.label)
        .accessibilityHint(proof.explanation)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(TradeProof.allCases, id: \.self) { proof in
            HStack {
                TradeProofBadge(proof: proof)
                TradeProofBadge(proof: proof, compact: true)
            }
        }
    }
    .padding()
}
