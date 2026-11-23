// File: Shared/Extensions/SupcriptionTier+Extensions.swift
// Display colour for each subscription tier.

import SwiftUI

extension SubscriptionTier {
    var color: Color {
        switch self {
        case .basic:
            return .gray
        case .pro:
            return .blue
        case .elite:
            return .arkadGold
        }
    }
}
