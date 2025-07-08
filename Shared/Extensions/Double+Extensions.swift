// File: Shared/Extensions/Double+Extensions.swift
// Fixed Double Extensions - removed conflicting enums and stored properties

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
    
    var asSmartCurrency: String {
        if abs(self) < 1 {
            return String(format: "$%.3f", self)
        } else if abs(self) < 100 {
            return String(format: "$%.2f", self)
        } else if abs(self) < 1000 {
            return String(format: "$%.1f", self)
        } else {
            return asCompactCurrency
        }
    }
    
    var asCompactCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        
        switch abs(self) {
        case 1_000_000_000...:
            formatter.maximumFractionDigits = 1
            let billions = self / 1_000_000_000
            return formatter.string(from: NSNumber(value: billions))?.replacingOccurrences(of: "$", with: "$") ?? "$0" + "B"
        case 1_000_000...:
            formatter.maximumFractionDigits = 1
            let millions = self / 1_000_000
            return formatter.string(from: NSNumber(value: millions))?.replacingOccurrences(of: "$", with: "$") ?? "$0" + "M"
        case 1_000...:
            formatter.maximumFractionDigits = 1
            let thousands = self / 1_000
            return formatter.string(from: NSNumber(value: thousands))?.replacingOccurrences(of: "$", with: "$") ?? "$0" + "K"
        default:
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
    
    // MARK: - Percentage Formatting
    var asPercentage: String {
        return String(format: "%.2f%%", self)
    }
    
    var asPercentageWithSign: String {
        let sign = self >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", self))%"
    }
    
    var asShortPercentage: String {
        if abs(self) >= 10 {
            return String(format: "%.0f%%", self)
        } else {
            return String(format: "%.1f%%", self)
        }
    }
    
    var asSmartPercentage: String {
        switch abs(self) {
        case 0..<0.01:
            return String(format: "%.3f%%", self)
        case 0.01..<0.1:
            return String(format: "%.2f%%", self)
        case 0.1..<10:
            return String(format: "%.1f%%", self)
        default:
            return String(format: "%.0f%%", self)
        }
    }
    
    // MARK: - Trading-Specific Formatting
    var asProfitLoss: String {
        let color = self >= 0 ? "📈" : "📉"
        return "\(color) \(asCurrencyWithSign)"
    }
    
    var asGainLoss: String {
        return self >= 0 ? "📈 \(asCurrencyWithSign)" : "📉 \(asCurrencyWithSign)"
    }
    
    var asPortfolioValue: String {
        switch abs(self) {
        case 1_000_000...:
            return String(format: "$%.1fM", self / 1_000_000)
        case 1_000...:
            return String(format: "$%.1fK", self / 1_000)
        default:
            return String(format: "$%.0f", self)
        }
    }
    
    var asTradingPrice: String {
        if self < 1 {
            return String(format: "$%.4f", self)
        } else if self < 10 {
            return String(format: "$%.3f", self)
        } else {
            return String(format: "$%.2f", self)
        }
    }
    
    // MARK: - Number Formatting
    var asRatio: String {
        return String(format: "%.2f", self)
    }
    
    var asMultiplier: String {
        return String(format: "%.1fx", self)
    }
    
    func asDecimalPlaces(_ places: Int) -> String {
        return String(format: "%.\(places)f", self)
    }
    
    var asWholeNumber: String {
        return String(format: "%.0f", self)
    }
    
    var asThousandsSeparated: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }
    
    // MARK: - Financial Calculations
    func percentageChange(from oldValue: Double) -> Double {
        guard oldValue != 0 else { return 0 }
        return ((self - oldValue) / oldValue) * 100
    }
    
    func profitLoss(from entryPrice: Double, quantity: Int) -> Double {
        return (self - entryPrice) * Double(quantity)
    }
    
    func profitLossPercentage(from entryPrice: Double) -> Double {
        guard entryPrice != 0 else { return 0 }
        return ((self - entryPrice) / entryPrice) * 100
    }
    
    func compound(rate: Double, periods: Int) -> Double {
        return self * pow(1 + rate, Double(periods))
    }
    
    func simpleInterest(rate: Double, time: Double) -> Double {
        return self * (1 + rate * time)
    }
    
    func presentValue(rate: Double, periods: Int) -> Double {
        return self / pow(1 + rate, Double(periods))
    }
    
    func futureValue(rate: Double, periods: Int) -> Double {
        return self * pow(1 + rate, Double(periods))
    }
    
    // MARK: - Risk Calculations (using existing RiskLevel if available)
    func sharpeRatio(riskFreeRate: Double, standardDeviation: Double) -> Double {
        guard standardDeviation != 0 else { return 0 }
        return (self - riskFreeRate) / standardDeviation
    }
    
    func maxDrawdown(from peak: Double) -> Double {
        guard peak != 0 else { return 0 }
        return ((peak - self) / peak) * 100
    }
    
    // MARK: - Portfolio Metrics
    func positionSize(portfolioValue: Double, riskPercentage: Double) -> Double {
        return portfolioValue * (riskPercentage / 100)
    }
    
    func riskRewardRatio(entryPrice: Double, stopLoss: Double, takeProfit: Double) -> Double {
        let risk = abs(entryPrice - stopLoss)
        let reward = abs(takeProfit - entryPrice)
        return risk != 0 ? reward / risk : 0
    }
    
    func portfolioWeight(portfolioValue: Double) -> Double {
        guard portfolioValue != 0 else { return 0 }
        return (self / portfolioValue) * 100
    }
    
    // MARK: - Technical Analysis Helpers
    func movingAverage(with values: [Double]) -> Double {
        let allValues = values + [self]
        return allValues.reduce(0, +) / Double(allValues.count)
    }
    
    func exponentialMovingAverage(previousEMA: Double, period: Int) -> Double {
        let multiplier = 2.0 / (Double(period) + 1.0)
        return (self * multiplier) + (previousEMA * (1 - multiplier))
    }
    
    func rsi(gains: [Double], losses: [Double]) -> Double {
        let avgGain = gains.isEmpty ? 0 : gains.reduce(0, +) / Double(gains.count)
        let avgLoss = losses.isEmpty ? 0 : losses.reduce(0, +) / Double(losses.count)
        
        guard avgLoss != 0 else { return 100 }
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }
    
    // MARK: - Utility Methods
    var isPositive: Bool { return self > 0 }
    var isNegative: Bool { return self < 0 }
    var isZero: Bool { return self == 0 }
    
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    func clamped(to range: ClosedRange<Double>) -> Double {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
    
    // MARK: - Conversion Helpers
    var asInt: Int {
        return Int(self)
    }
    
    var asFloat: Float {
        return Float(self)
    }
    
    var asCGFloat: CGFloat {
        return CGFloat(self)
    }
    
    // MARK: - Formatting with Locale Support
    func asCurrency(locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: self)) ?? ""
    }
    
    func asPercentage(locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self / 100)) ?? ""
    }
    
    // MARK: - Crypto-Specific Formatting
    var asCryptoPrice: String {
        if self < 0.0001 {
            return String(format: "%.8f", self)
        } else if self < 0.01 {
            return String(format: "%.6f", self)
        } else if self < 1 {
            return String(format: "%.4f", self)
        } else {
            return String(format: "%.2f", self)
        }
    }
    
    var asSatoshi: String {
        let satoshi = self * 100_000_000
        return String(format: "%.0f sats", satoshi)
    }
    
    // MARK: - Time-Based Calculations
    func annualized(days: Int) -> Double {
        guard days > 0 else { return 0 }
        return self * (365.0 / Double(days))
    }
    
    func dailyReturn(from days: Int) -> Double {
        guard days > 0 else { return 0 }
        return self / Double(days)
    }
    
    // MARK: - Statistical Helpers
    static func standardDeviation(values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }
    
    static func correlation(x: [Double], y: [Double]) -> Double {
        guard x.count == y.count && x.count > 1 else { return 0 }
        
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)
        
        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))
        
        return denominator != 0 ? numerator / denominator : 0
    }
    
    // MARK: - Performance Metrics
    var performanceEmoji: String {
        switch self {
        case let x where x > 20: return "🚀"
        case let x where x > 10: return "📈"
        case let x where x > 5: return "⬆️"
        case let x where x > 0: return "🟢"
        case 0: return "➡️"
        case let x where x > -5: return "🔴"
        case let x where x > -10: return "⬇️"
        case let x where x > -20: return "📉"
        default: return "💥"
        }
    }
    
    // MARK: - Market Cap Helpers
    var asMarketCap: String {
        switch abs(self) {
        case 1_000_000_000_000...:
            return String(format: "$%.1fT", self / 1_000_000_000_000)
        case 1_000_000_000...:
            return String(format: "$%.1fB", self / 1_000_000_000)
        case 1_000_000...:
            return String(format: "$%.1fM", self / 1_000_000)
        case 1_000...:
            return String(format: "$%.1fK", self / 1_000)
        default:
            return String(format: "$%.0f", self)
        }
    }
}

// MARK: - Array Extensions for Financial Calculations
extension Array where Element == Double {
    var sum: Double {
        return self.reduce(0, +)
    }
    
    var average: Double {
        guard !isEmpty else { return 0 }
        return sum / Double(count)
    }
    
    var standardDeviation: Double {
        return Double.standardDeviation(values: self)
    }
    
    var variance: Double {
        guard count > 1 else { return 0 }
        let mean = average
        let variance = self.map { pow($0 - mean, 2) }.reduce(0, +) / Double(count - 1)
        return variance
    }
    
    var minimum: Double {
        return self.min() ?? 0
    }
    
    var maximum: Double {
        return self.max() ?? 0
    }
    
    var range: Double {
        return maximum - minimum
    }
    
    func percentile(_ p: Double) -> Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let index = p * Double(sorted.count - 1)
        let lower = Int(floor(index))
        let upper = Int(ceil(index))
        
        if lower == upper {
            return sorted[lower]
        } else {
            let weight = index - Double(lower)
            return sorted[lower] * (1 - weight) + sorted[upper] * weight
        }
    }
    
    var median: Double {
        return percentile(0.5)
    }
    
    func movingAverage(period: Int) -> [Double] {
        guard period > 0 && period <= count else { return [] }
        
        var result: [Double] = []
        for i in (period - 1)..<count {
            let slice = Array(self[(i - period + 1)...i])
            result.append(slice.average)
        }
        return result
    }
    
    func exponentialMovingAverage(period: Int) -> [Double] {
        guard !isEmpty && period > 0 else { return [] }
        
        var result: [Double] = []
        let multiplier = 2.0 / (Double(period) + 1.0)
        
        // First EMA is simple average of first 'period' values
        if count >= period {
            let initialValues = Array(self.prefix(period))
            var ema = initialValues.average
            result.append(ema)
            
            // Calculate subsequent EMAs
            for i in period..<count {
                ema = (self[i] * multiplier) + (ema * (1 - multiplier))
                result.append(ema)
            }
        }
        
        return result
    }
}
