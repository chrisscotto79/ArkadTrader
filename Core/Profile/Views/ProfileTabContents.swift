// File: Core/Profile/Views/ProfileTabContents.swift
// Fixed ProfileTab contents - uses centralized TradeFilter from TradingEnums.swift

import SwiftUI

// MARK: - Supporting Views

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
}
