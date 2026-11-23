// File: Core/Communities/Models/TradeCallout.swift
// A structured trade idea posted by a community admin in a callouts channel.

import Foundation
import SwiftUI
import FirebaseFirestore

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

    // Track record. The app sets these three when the callout is created.
    var authorId: String? = nil
    var communityId: String? = nil
    var postedAt: Date? = nil

    // Written by the server's price checks while the callout is open.
    var lastPrice: Double? = nil
    var lastPriceAt: Date? = nil

    // Set when the callout closes (by the server, or by the author closing it).
    var exitPrice: Double? = nil
    var closedAt: Date? = nil
    /// Signed percent move for the callout's direction; positive is a gain.
    var resultPercent: Double? = nil

    var isOpen: Bool { status == .open }

    /// Live move from entry to the last checked price, for open callouts.
    var livePercent: Double? {
        guard isOpen, let lastPrice, lastPrice > 0 else { return nil }
        return percentMove(to: lastPrice)
    }

    /// Final result of a closed callout. Falls back to the exit price for older docs.
    var finalPercent: Double? {
        guard !isOpen else { return nil }
        if let resultPercent { return resultPercent }
        if let exitPrice, exitPrice > 0 { return percentMove(to: exitPrice) }
        return nil
    }

    /// Where a price sits between the stop (0) and the target (1). Works for longs and shorts.
    /// Nil unless both a stop and a target are set.
    func progress(at price: Double) -> Double? {
        guard let stop = stopPrice, let target = targetPrice, target != stop else { return nil }
        return (price - stop) / (target - stop)
    }

    /// The same callout with the fields the app must set when posting it.
    func stamped(authorId: String, communityId: String, postedAt: Date = Date()) -> TradeCallout {
        var copy = self
        copy.authorId = authorId
        copy.communityId = communityId
        copy.postedAt = postedAt
        return copy
    }

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
        if let authorId { data["authorId"] = authorId }
        if let communityId { data["communityId"] = communityId }
        if let postedAt { data["postedAt"] = Timestamp(date: postedAt) }
        if let lastPrice { data["lastPrice"] = lastPrice }
        if let lastPriceAt { data["lastPriceAt"] = Timestamp(date: lastPriceAt) }
        if let exitPrice { data["exitPrice"] = exitPrice }
        if let closedAt { data["closedAt"] = Timestamp(date: closedAt) }
        if let resultPercent { data["resultPercent"] = resultPercent }
        return data
    }

    static func fromFirestore(_ data: [String: Any]) -> TradeCallout? {
        guard let ticker = data["ticker"] as? String,
              let entry = TrackRecordDecode.double(data["entryPrice"]) else {
            return nil
        }
        return TradeCallout(
            ticker: ticker,
            assetType: TradeType(rawValue: data["assetType"] as? String ?? "") ?? .stock,
            direction: Direction(rawValue: data["direction"] as? String ?? "") ?? .long,
            entryPrice: entry,
            stopPrice: TrackRecordDecode.double(data["stopPrice"]),
            targetPrice: TrackRecordDecode.double(data["targetPrice"]),
            note: data["note"] as? String,
            status: Status(rawValue: data["status"] as? String ?? "") ?? .open,
            authorId: data["authorId"] as? String,
            communityId: data["communityId"] as? String,
            postedAt: TrackRecordDecode.date(data["postedAt"]),
            lastPrice: TrackRecordDecode.double(data["lastPrice"]),
            lastPriceAt: TrackRecordDecode.date(data["lastPriceAt"]),
            exitPrice: TrackRecordDecode.double(data["exitPrice"]),
            closedAt: TrackRecordDecode.date(data["closedAt"]),
            resultPercent: TrackRecordDecode.double(data["resultPercent"])
        )
    }
}
