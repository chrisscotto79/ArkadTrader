// File: Shared/Extensions/Color+Extensions.swift
// Brand and market colours. Adaptive surfaces and tokens live in Shared/Components/DesignSystem.swift.

import SwiftUI

extension Color {
    // MARK: - Brand
    static let arkadGold = Color(red: 254/255, green: 186/255, blue: 23/255)

    // MARK: - Market (adaptive)
    static let marketGreen = Color.dynamic(
        light: UIColor(red: 22/255, green: 163/255, blue: 74/255, alpha: 1),   // #16A34A
        dark: UIColor(red: 52/255, green: 211/255, blue: 110/255, alpha: 1)    // #34D36E
    )
    static let marketRed = Color.dynamic(
        light: UIColor(red: 220/255, green: 38/255, blue: 38/255, alpha: 1),   // #DC2626
        dark: UIColor(red: 248/255, green: 92/255, blue: 92/255, alpha: 1)     // #F85C5C
    )

    // MARK: - Semantic
    static let success = Color.marketGreen
    static let error = Color.marketRed
    static let warning = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let info = Color(red: 59/255, green: 130/255, blue: 246/255)

    // MARK: - Market categories
    static let stockColor = Color.blue
    static let optionColor = Color.purple
    static let cryptoColor = Color.orange
}
