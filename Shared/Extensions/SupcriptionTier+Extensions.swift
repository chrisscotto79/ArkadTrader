//
//  SubscriptionTier+Extensions.swift
//  ArkadTrader
//
//  CREATE THIS AS A NEW FILE in Shared/Extensions/
//

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
