// File: Shared/Extensions/Double+Extensions.swift
// Number formatting for prices, P&L and quantities. Non-finite values (NaN, infinity)
// render as "–" so a bad calculation never shows "NaN" or "$inf" on screen.

import Foundation

extension Double {
    /// Shown in place of a number that can't be displayed (NaN or infinite).
    static let missingValueText = "–"

    // MARK: - Currency

    /// US dollars. Under $10,000 it shows cents ("$0.42", "$1,234.50") so small gains don't
    /// round to "$0"; from $10,000 up it rounds to whole dollars ("$12,345").
    var asCurrency: String {
        guard isFinite else { return Self.missingValueText }
        let digits = abs(self) < 10_000 ? 2 : 0
        return Self.usdFormatter(fractionDigits: digits).string(from: NSNumber(value: self)) ?? "$0"
    }

    /// Whole US dollars ("$1,000"), for round amounts like preset buttons.
    var asWholeCurrency: String {
        guard isFinite else { return Self.missingValueText }
        return Self.usdFormatter(fractionDigits: 0).string(from: NSNumber(value: self)) ?? "$0"
    }

    /// "+$12.50" / "-$3.00"
    var asCurrencyWithSign: String {
        guard isFinite else { return Self.missingValueText }
        let formatted = abs(self).asCurrency
        return self >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    /// Price with precision that suits its size: "$0.1234", "$4.567", "$182.30".
    var asTradingPrice: String {
        guard isFinite else { return Self.missingValueText }
        if self < 1 {
            return String(format: "$%.4f", self)
        } else if self < 10 {
            return String(format: "$%.3f", self)
        } else {
            return String(format: "$%.2f", self)
        }
    }

    // MARK: - Quantities

    /// Quantity without trailing zeros: 10 -> "10", 0.5 -> "0.5", 0.00012345 -> "0.00012345"
    var quantityString: String {
        guard isFinite else { return Self.missingValueText }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    // MARK: - Rounding

    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }

    // MARK: - Private

    private static func usdFormatter(fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter
    }
}
