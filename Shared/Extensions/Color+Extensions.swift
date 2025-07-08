// File: Shared/Extensions/Color+Extensions.swift
// Fixed Color Extensions - removed conflicting enums and fixed blend mode issues

import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let arkadGold = Color(red: 254/255, green: 186/255, blue: 23/255)
    static let arkadBlack = Color.black
    static let arkadWhite = Color.white
    
    // MARK: - Brand Color Variations
    static let arkadGoldLight = Color(red: 255/255, green: 206/255, blue: 84/255)
    static let arkadGoldDark = Color(red: 218/255, green: 160/255, blue: 0/255)
    static let arkadGoldMuted = Color(red: 254/255, green: 186/255, blue: 23/255).opacity(0.6)
    
    // MARK: - Market Colors
    static let marketGreen = Color(red: 34/255, green: 197/255, blue: 94/255)
    static let marketRed = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let marketGreenLight = Color(red: 134/255, green: 239/255, blue: 172/255)
    static let marketRedLight = Color(red: 252/255, green: 165/255, blue: 165/255)
    static let marketGreenDark = Color(red: 21/255, green: 128/255, blue: 61/255)
    static let marketRedDark = Color(red: 153/255, green: 27/255, blue: 27/255)
    
    // MARK: - Semantic Colors
    static let success = Color.marketGreen
    static let error = Color.marketRed
    static let warning = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let info = Color(red: 59/255, green: 130/255, blue: 246/255)
    
    // MARK: - Background Colors
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)
    static let backgroundGrouped = Color(UIColor.systemGroupedBackground)
    
    // MARK: - Text Colors
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)
    static let textQuaternary = Color(UIColor.quaternaryLabel)
    
    // MARK: - Border Colors
    static let borderPrimary = Color(UIColor.separator)
    static let borderSecondary = Color(UIColor.opaqueSeparator)
    
    // MARK: - Trading Category Colors
    static let stockColor = Color(red: 99/255, green: 102/255, blue: 241/255)
    static let optionColor = Color(red: 168/255, green: 85/255, blue: 247/255)
    static let cryptoColor = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let forexColor = Color(red: 20/255, green: 184/255, blue: 166/255)
    
    // MARK: - Social Media Colors
    static let twitterBlue = Color(red: 29/255, green: 161/255, blue: 242/255)
    static let linkedInBlue = Color(red: 0/255, green: 119/255, blue: 181/255)
    static let facebookBlue = Color(red: 24/255, green: 119/255, blue: 242/255)
    static let discordPurple = Color(red: 88/255, green: 101/255, blue: 242/255)
    
    // MARK: - Chart Colors
    static let chartBlue = Color(red: 54/255, green: 162/255, blue: 235/255)
    static let chartPurple = Color(red: 153/255, green: 102/255, blue: 255/255)
    static let chartOrange = Color(red: 255/255, green: 159/255, blue: 64/255)
    static let chartYellow = Color(red: 255/255, green: 205/255, blue: 86/255)
    static let chartTeal = Color(red: 75/255, green: 192/255, blue: 192/255)
    
    // MARK: - Gradient Definitions
    static let arkadGradient = LinearGradient(
        gradient: Gradient(colors: [arkadGold, arkadGoldLight]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let successGradient = LinearGradient(
        gradient: Gradient(colors: [marketGreen, marketGreenLight]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let errorGradient = LinearGradient(
        gradient: Gradient(colors: [marketRed, marketRedLight]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [arkadGold.opacity(0.1), Color.white]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let premiumGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 167/255, green: 139/255, blue: 250/255),
            Color(red: 224/255, green: 231/255, blue: 255/255)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Performance Colors
    static func performanceColor(for value: Double) -> Color {
        switch value {
        case let x where x > 10: return marketGreen
        case let x where x > 0: return marketGreenLight
        case 0: return textSecondary
        case let x where x > -10: return marketRedLight
        default: return marketRed
        }
    }
    
    static func performanceGradient(for value: Double) -> LinearGradient {
        if value > 0 {
            return successGradient
        } else if value < 0 {
            return errorGradient
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [textSecondary, textSecondary.opacity(0.5)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    // MARK: - Trading Status Colors (using simplified approach)
    static func tradeStatusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "open": return info
        case "closed": return textSecondary
        case "profitable": return marketGreen
        case "loss": return marketRed
        default: return textSecondary
        }
    }
    
    // MARK: - Dynamic Color Creation
    static func colorFromString(_ string: String) -> Color {
        let hash = string.hashValue
        let hue = Double(abs(hash % 360)) / 360.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
    
    static func colorForTradeType(_ type: TradeType) -> Color {
        switch type {
        case .stock: return stockColor
        case .option: return optionColor
        case .crypto: return cryptoColor
        case .forex: return forexColor
        }
    }
    
    // MARK: - Accessibility Colors
    static func accessibleColor(for backgroundColor: Color) -> Color {
        // Simplified contrast calculation - in production, use proper contrast ratio calculation
        return textPrimary
    }
    
    // MARK: - Theme Support
    static func adaptiveColor(light: Color, dark: Color) -> Color {
        return Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
    
    // MARK: - Random Colors (for development/testing)
    static var random: Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
    
    // MARK: - Color Manipulation (simplified to avoid blend mode issues)
    func lighten(by percentage: Double = 0.1) -> Color {
        return self.opacity(1.0 - percentage)
    }
    
    func darken(by percentage: Double = 0.1) -> Color {
        // Simplified darkening - overlay with black
        return Color.black.opacity(percentage)
    }
    
    // MARK: - Hex Color Support
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
    
    // MARK: - Color to Hex
    var hexString: String {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else {
            return "#000000"
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}

// MARK: - Color Scheme Extensions
extension ColorScheme {
    var isDark: Bool {
        return self == .dark
    }
    
    var isLight: Bool {
        return self == .light
    }
}

// MARK: - SwiftUI Environment Extensions
extension EnvironmentValues {
    var brandColors: BrandColors {
        BrandColors()
    }
}

struct BrandColors {
    let primary = Color.arkadGold
    let secondary = Color.arkadBlack
    let accent = Color.arkadGoldLight
    let background = Color.backgroundPrimary
    let surface = Color.backgroundSecondary
    let onPrimary = Color.arkadBlack
    let onSecondary = Color.arkadWhite
    let onBackground = Color.textPrimary
    let onSurface = Color.textPrimary
}

// MARK: - Color Palette for Design System
struct ArkadColorPalette {
    // Primary palette
    static let primary50 = Color(hex: "FFFBEB")
    static let primary100 = Color(hex: "FEF3C7")
    static let primary200 = Color(hex: "FDE68A")
    static let primary300 = Color(hex: "FCD34D")
    static let primary400 = Color(hex: "FBBF24")
    static let primary500 = Color.arkadGold // Main brand color
    static let primary600 = Color(hex: "D97706")
    static let primary700 = Color(hex: "B45309")
    static let primary800 = Color(hex: "92400E")
    static let primary900 = Color(hex: "78350F")
    
    // Gray palette
    static let gray50 = Color(hex: "F9FAFB")
    static let gray100 = Color(hex: "F3F4F6")
    static let gray200 = Color(hex: "E5E7EB")
    static let gray300 = Color(hex: "D1D5DB")
    static let gray400 = Color(hex: "9CA3AF")
    static let gray500 = Color(hex: "6B7280")
    static let gray600 = Color(hex: "4B5563")
    static let gray700 = Color(hex: "374151")
    static let gray800 = Color(hex: "1F2937")
    static let gray900 = Color(hex: "111827")
}
