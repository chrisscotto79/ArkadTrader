// File: Shared/Extensions/Double+Extensions.swift
// Simplified Double Extensions

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
}
