//
//  Color+Extensions.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Extensions/Color+Extensions.swift

// File: Shared/Extensions/Color+Extensions.swift

import SwiftUI

extension Color {
    // MARK: - ArkadTrader Brand Colors
    static let arkadGold = Color(hex: "FEBA17")        // Your brand gold
    static let arkadBlack = Color.black                // Primary black
    static let arkadWhite = Color.white                // Primary white
    
    // MARK: - Market Colors
    static let marketGreen = Color.green               // Profit/Bullish
    static let marketRed = Color.red                   // Loss/Bearish
    static let marketNeutral = Color.gray              // Neutral
    
    // MARK: - App Theme Colors (Updated to brand)
    static let primaryColor = Color.arkadGold          // Main brand color
    static let secondaryColor = Color.arkadBlack       // Secondary color
    static let accentColor = Color.arkadGold           // Accent color
    
    // MARK: - Subscription Tier Colors
    static let basicTier = Color.gray
    static let proTier = Color.arkadGold
    static let eliteTier = Color.arkadBlack
    
    // MARK: - Profit/Loss Colors
    static let profit = Color.marketGreen
    static let loss = Color.marketRed
    static let neutral = Color.marketNeutral
    
    // MARK: - Background Colors
    static let cardBackground = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
}

// MARK: - Hex Color Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
