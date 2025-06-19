//
//  Double+Extensions.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Extensions/Double+Extensions.swift

import Foundation

extension Double {
    // MARK: - Currency Formatting
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
    
    // MARK: - Percentage Formatting
    var asPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self / 100)) ?? "0.0%"
    }
    
    var asPercentageWithSign: String {
        let formatted = abs(self).asPercentage
        return self >= 0 ? "+\(formatted)" : "-\(formatted)"
    }
    
    // MARK: - Number Formatting
    var asCompactCurrency: String {
        if abs(self) >= 1_000_000 {
            return String(format: "$%.1fM", self / 1_000_000)
        } else if abs(self) >= 1_000 {
            return String(format: "$%.1fK", self / 1_000)
        } else {
            return self.asCurrency
        }
    }
    
    var rounded: String {
        return String(format: "%.2f", self)
    }
}
