// File: Core/Communities/Models/TradeCallout.swift
// A structured trade idea posted by a community admin in a callouts channel.

import Foundation
import SwiftUI

struct TradeCallout: Codable, Equatable {
    enum Direction: String, Codable, CaseIterable {
        case long, short

        var displayName: String { self == .long ? "Long" : "Short" }
        var color: Color { self == .long ? .marketGreen : .marketRed }
        var icon: String { self == .long ? "arrow.up.right" : "arrow.down.right" }
    }

    enum Status: String, Codable, CaseIterable {
        case open
        case targetHit = "target_hit"
        case stoppedOut = "stopped_out"
        case closed

        var displayName: String {
            switch self {
            case .open: return "Open"
            case .targetHit: return "Target Hit"
            case .stoppedOut: return "Stopped Out"
            case .closed: return "Closed"
            }
        }

        var color: Color {
            switch self {
            case .open: return .goldText
            case .targetHit: return .marketGreen
            case .stoppedOut: return .marketRed
            case .closed: return .secondary
            }
        }

        var icon: String {
            switch self {
            case .open: return "circle.fill"
            case .targetHit: return "checkmark.circle.fill"
            case .stoppedOut: return "xmark.octagon.fill"
            case .closed: return "lock.fill"
            }
        }
    }

    /// Price with cents ("$182.45"), or more decimals for sub-dollar prices ("$0.0042").
    static func formatPrice(_ price: Double) -> String {
        let digits = abs(price) < 1 ? 4 : 2
        return price.formatted(.currency(code: "USD").precision(.fractionLength(digits)))
    }

    var ticker: String
    var assetType: TradeType
    var direction: Direction
    var entryPrice: Double
    var stopPrice: Double?
    var targetPrice: Double?
    var note: String?
    var status: Status = .open

    /// Reward-to-risk ratio, when both a stop and a target are set.
    var riskReward: Double? {
        guard let stop = stopPrice, let target = targetPrice else { return nil }
        let risk = abs(entryPrice - stop)
        guard risk > 0 else { return nil }
        return abs(target - entryPrice) / risk
    }

    /// Percent move from entry to a price, signed so a gain for this direction is positive.
    func percentMove(to price: Double) -> Double {
        guard entryPrice > 0 else { return 0 }
        let raw = (price - entryPrice) / entryPrice * 100
        return direction == .long ? raw : -raw
    }

    /// Plain-text summary used as the message body (shows in search and older app versions).
    var summary: String {
        var parts = ["📣 \(direction.displayName.uppercased()) $\(ticker) @ \(entryPrice.asCurrency)"]
        if let stop = stopPrice { parts.append("Stop \(stop.asCurrency)") }
        if let target = targetPrice { parts.append("Target \(target.asCurrency)") }
        return parts.joined(separator: " · ")
    }

    /// Validation message for the create form, or nil when the callout is valid.
    var validationError: String? {
        if ticker.trimmingCharacters(in: .whitespaces).isEmpty { return "Enter a ticker" }
        if entryPrice <= 0 { return "Enter an entry price" }
        if let stop = stopPrice {
            if direction == .long && stop >= entryPrice { return "For a long, the stop should be below entry" }
            if direction == .short && stop <= entryPrice { return "For a short, the stop should be above entry" }
        }
        if let target = targetPrice {
            if direction == .long && target <= entryPrice { return "For a long, the target should be above entry" }
            if direction == .short && target >= entryPrice { return "For a short, the target should be below entry" }
        }
        return nil
    }

    // MARK: - Firestore

    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "ticker": ticker,
            "assetType": assetType.rawValue,
            "direction": direction.rawValue,
            "entryPrice": entryPrice,
            "status": status.rawValue
        ]
        if let stopPrice { data["stopPrice"] = stopPrice }
        if let targetPrice { data["targetPrice"] = targetPrice }
        if let note, !note.isEmpty { data["note"] = note }
        return data
    }

    static func fromFirestore(_ data: [String: Any]) -> TradeCallout? {
        guard let ticker = data["ticker"] as? String,
              let entry = (data["entryPrice"] as? Double) ?? (data["entryPrice"] as? Int).map(Double.init) else {
            return nil
        }
        return TradeCallout(
            ticker: ticker,
            assetType: TradeType(rawValue: data["assetType"] as? String ?? "") ?? .stock,
            direction: Direction(rawValue: data["direction"] as? String ?? "") ?? .long,
            entryPrice: entry,
            stopPrice: data["stopPrice"] as? Double,
            targetPrice: data["targetPrice"] as? Double,
            note: data["note"] as? String,
            status: Status(rawValue: data["status"] as? String ?? "") ?? .open
        )
    }
}
