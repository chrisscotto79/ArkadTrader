// File: Shared/Extensions/Double+Extensions.swift
// Enhanced Double Extensions for comprehensive portfolio tracking

import Foundation

extension Double {
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
    
    var asCurrencyWithSign: String {
        let formatted = abs(self).asCurrency
        return self >= 0 ? "+\(formatted)" : "-\(formatted)"
    }
    
    var asPercentage: String {
        return String(format: "%.2f%%", self)
    }
    
    var asPercentageWithSign: String {
        let sign = self >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", self))%"
    }
    
    var asCompactCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        
        if abs(self) >= 1_000_000 {
            formatter.maximumFractionDigits = 1
            let millions = self / 1_000_000
            return formatter.string(from: NSNumber(value: millions))?.replacingOccurrences(of: "$", with: "$") ?? "$0" + "M"
        } else if abs(self) >= 1_000 {
            formatter.maximumFractionDigits = 1
            let thousands = self / 1_000
            return formatter.string(from: NSNumber(value: thousands))?.replacingOccurrences(of: "$", with: "$") ?? "$0" + "K"
        } else {
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: self)) ?? "$0"
        }
    }
    
    var asShortCurrency: String {
        if abs(self) >= 1000 {
            return asCompactCurrency
        } else {
            return String(format: "$%.0f", self)
        }
    }
    
    // Portfolio-specific formatting
    var asPortfolioValue: String {
        if abs(self) >= 1_000_000 {
            return String(format: "$%.1fM", self / 1_000_000)
        } else if abs(self) >= 1_000 {
            return String(format: "$%.1fK", self / 1_000)
        } else {
            return String(format: "$%.0f", self)
        }
    }
    
    var asGainLoss: String {
        let color = self >= 0 ? "📈" : "📉"
        return "\(color) \(asCurrencyWithSign)"
    }
    
    // Analytics formatting
    var asRatio: String {
        return String(format: "%.2f", self)
    }
    
    var asMultiplier: String {
        return String(format: "%.1fx", self)
    }
    
    // Returns with proper formatting for small/large numbers
    var asSmartCurrency: String {
        if abs(self) < 1 {
            return String(format: "$%.2f", self)
        } else if abs(self) < 100 {
            return String(format: "$%.1f", self)
        } else {
            return String(format: "$%.0f", self)
        }
    }
}
