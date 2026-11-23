// File: Core/Payments/CommunityPricing.swift
// Price rules, wording and small views for paid communities. Arkad keeps AppConfig.platformFeePercent.

import SwiftUI

enum CommunityPricing {
    static let minimumPrice = 1.0
    static let maximumPrice = 500.0
    static let trialOptions = [0, 3, 7]

    static var feePercent: Double { Double(AppConfig.platformFeePercent) }

    /// "10%"
    static var feePercentText: String {
        "\(feePercent.formatted(.number.precision(.fractionLength(0...1))))%"
    }

    /// What the owner gets from one monthly payment, before Stripe's processing fees
    static func ownerEarnings(for price: Double) -> Double {
        price * (100 - feePercent) / 100
    }

    /// "$10" for whole dollars, "$9.99" otherwise
    static func format(_ price: Double) -> String {
        let isWhole = price.rounded() == price
        return price.formatted(.currency(code: "USD").precision(.fractionLength(isWhole ? 0 : 2)))
    }

    /// "Members pay $10/mo · You get $9 after Arkad's 10% fee"
    static func earningsLine(for price: Double) -> String {
        "Members pay \(format(price))/mo · You get \(format(ownerEarnings(for: price))) after Arkad's \(feePercentText) fee"
    }

    static let processingFeeNote = "Stripe's processing fees also apply."

    /// "No trial", "3-day free trial"
    static func trialLabel(_ days: Int) -> String {
        days == 0 ? "No trial" : "\(days)-day free trial"
    }

    /// Short chip title: "None", "3 days"
    static func trialChipTitle(_ days: Int) -> String {
        days == 0 ? "None" : "\(days) days"
    }

    /// Parses a typed price, rounded to cents
    static func parsePrice(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: "$", with: "")
        guard let value = AssetTerms.parseNumber(cleaned) else { return nil }
        return (value * 100).rounded() / 100
    }

    /// nil when the price is fine
    static func validationMessage(for text: String) -> String? {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return "Enter a monthly price." }
        guard let price = parsePrice(text) else { return "Enter a price like 9.99." }
        if price < minimumPrice { return "The lowest price is \(format(minimumPrice))/mo." }
        if price > maximumPrice { return "The highest price is \(format(maximumPrice))/mo." }
        return nil
    }

    /// Text for a price input field
    static func inputText(for price: Double?) -> String {
        guard let price else { return "" }
        return AssetTerms.inputString(price)
    }
}

// MARK: - Views

/// Small gold "$9.99/mo" tag for paid communities in cards and rows
struct CommunityPriceTag: View {
    let community: Community

    var body: some View {
        if let text = community.priceTagText {
            Tag(text: text)
                .accessibilityLabel("Paid, \(text.replacingOccurrences(of: "/mo", with: " a month"))")
        }
    }
}

/// "Members pay … · You get …" with the processing-fee note
struct CommunityEarningsBreakdown: View {
    let price: Double

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(CommunityPricing.earningsLine(for: price))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(CommunityPricing.processingFeeNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
