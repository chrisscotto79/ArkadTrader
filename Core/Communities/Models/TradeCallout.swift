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

    /// Whether a price was checked against a live quote: the entry when posting (`priceCheck`
    /// on the callout), or the exit of a manual close (`exitCheck`, on the mirror doc only).
    enum PriceCheck: String, Codable {
        /// Entry was within `maxEntryDeviation` of `quoteAtPost`.
        case live
        /// No quote was available (no key, unsupported asset or no network).
        case unchecked
    }

    /// How far an entry (posting) or exit (closing by hand) may sit from the live price: 2%.
    static let maxEntryDeviation = 0.02

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

    // Anti-fake: set when posting. Only `.live` callouts count toward track records.
    var priceCheck: PriceCheck? = nil
    /// The live price the entry was checked against, when `priceCheck == .live`.
    var quoteAtPost: Double? = nil

    // Written by the price checks while the callout is open: the server's, or in free mode
    // the author's app (CalloutAutoTracker).
    var lastPrice: Double? = nil
    var lastPriceAt: Date? = nil

    // Set when the callout closes (by a price check, or by the author closing it).
    var exitPrice: Double? = nil
    var closedAt: Date? = nil
    /// Signed percent move for the callout's direction; positive is a gain.
    var resultPercent: Double? = nil

    var isOpen: Bool { status == .open }

    /// The entry was checked against a live price when posted. Unchecked callouts (and ones
    /// posted before the check existed) still show, but don't count toward track records.
    var isPriceChecked: Bool { priceCheck == .live }

    /// The validation message for an entry that's too far from the live price, or nil when it's close enough.
    static func entryCheckError(entry: Double, livePrice: Double) -> String? {
        priceCheckError("Entry", price: entry, livePrice: livePrice)
    }

    /// The same check for the exit price of a manual close.
    static func exitCheckError(exit: Double, livePrice: Double) -> String? {
        priceCheckError("Exit", price: exit, livePrice: livePrice)
    }

    private static func priceCheckError(_ label: String, price: Double, livePrice: Double) -> String? {
        guard livePrice > 0, price > 0 else { return nil }
        guard abs(price - livePrice) / livePrice > maxEntryDeviation else { return nil }
        return "\(label) must be within 2% of the current price (\(formatPrice(livePrice)))"
    }

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

    // MARK: - Auto-close

    /// Callouts with neither a stop nor a target close after this long, at the last price.
    static let maxOpenDays = 30

    /// What a price check does to this open callout, or nil when it stays open.
    /// A target fills at the target and a stop at the stop, for longs and shorts alike.
    /// With neither set, the callout closes at `price` once it's `maxOpenDays` old.
    func autoClose(at price: Double, now: Date = Date()) -> (status: Status, exitPrice: Double)? {
        guard isOpen, price > 0, price.isFinite else { return nil }
        if let target = targetPrice {
            let hit = direction == .long ? price >= target : price <= target
            if hit { return (status: Status.targetHit, exitPrice: target) }
        }
        if let stop = stopPrice {
            let hit = direction == .long ? price <= stop : price >= stop
            if hit { return (status: Status.stoppedOut, exitPrice: stop) }
        }
        if stopPrice == nil, targetPrice == nil, let postedAt,
           now.timeIntervalSince(postedAt) >= Double(Self.maxOpenDays) * 86_400 {
            return (status: Status.closed, exitPrice: price)
        }
        return nil
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
        if let priceCheck { data["priceCheck"] = priceCheck.rawValue }
        if let quoteAtPost { data["quoteAtPost"] = quoteAtPost }
        if let lastPrice { data["lastPrice"] = lastPrice }
        if let lastPriceAt { data["lastPriceAt"] = Timestamp(date: lastPriceAt) }
        if let exitPrice { data["exitPrice"] = exitPrice }
        if let closedAt { data["closedAt"] = Timestamp(date: closedAt) }
        if let resultPercent { data["resultPercent"] = resultPercent }
        return data
    }

    /// The author's mirror doc, `users/{uid}/callouts/{messageId}` (docs/backend-contracts.md,
    /// section 0). Free mode computes track records from these. `closedAt` is written by the
    /// caller as a server timestamp when the callout closes.
    func mirrorData(communityId: String, channelId: String, messageId: String) -> [String: Any] {
        var data: [String: Any] = [
            "communityId": communityId,
            "channelId": channelId,
            "messageId": messageId,
            "ticker": ticker,
            "assetType": assetType.rawValue,
            "direction": direction.rawValue,
            "entryPrice": entryPrice,
            "status": status.rawValue
        ]
        if let stopPrice { data["stopPrice"] = stopPrice }
        if let targetPrice { data["targetPrice"] = targetPrice }
        if let postedAt { data["postedAt"] = Timestamp(date: postedAt) }
        if let priceCheck { data["priceCheck"] = priceCheck.rawValue }
        if let quoteAtPost { data["quoteAtPost"] = quoteAtPost }
        if let closedAt { data["closedAt"] = Timestamp(date: closedAt) }
        if let exitPrice { data["exitPrice"] = exitPrice }
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
            priceCheck: PriceCheck(rawValue: data["priceCheck"] as? String ?? ""),
            quoteAtPost: TrackRecordDecode.double(data["quoteAtPost"]),
            lastPrice: TrackRecordDecode.double(data["lastPrice"]),
            lastPriceAt: TrackRecordDecode.date(data["lastPriceAt"]),
            exitPrice: TrackRecordDecode.double(data["exitPrice"]),
            closedAt: TrackRecordDecode.date(data["closedAt"]),
            resultPercent: TrackRecordDecode.double(data["resultPercent"])
        )
    }
}

// MARK: - Callout follow-ups (docs/backend-contracts.md, section 11)

/// A follow-up the author posts on their own open callout, in the same channel:
/// `calloutUpdate: { parentMessageId, kind, price?, percent?, note? }` on a channel message.
/// Moving the stop or target also changes `callout.stopPrice` / `callout.targetPrice` on the parent.
struct CalloutUpdate: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case trim
        case add
        case moveStop = "move_stop"
        case moveTarget = "move_target"
        case note

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .trim: return "Trim"
            case .add: return "Add"
            case .moveStop: return "Move stop"
            case .moveTarget: return "Move target"
            case .note: return "Note"
            }
        }

        var icon: String {
            switch self {
            case .trim: return "scissors"
            case .add: return "plus.circle.fill"
            case .moveStop: return "shield.lefthalf.filled"
            case .moveTarget: return "target"
            case .note: return "text.bubble.fill"
            }
        }

        var tint: Color {
            switch self {
            case .trim: return .goldText
            case .add: return .info
            case .moveStop: return .marketRed
            case .moveTarget: return .marketGreen
            case .note: return .secondary
            }
        }

        /// Members get a `callout_update` notification for these, not for adds or notes.
        var notifiesMembers: Bool {
            switch self {
            case .trim, .moveStop, .moveTarget: return true
            case .add, .note: return false
            }
        }

        /// Trims and adds carry the share of the position (1–100).
        var usesPercent: Bool { self == .trim || self == .add }
    }

    var parentMessageId: String
    var kind: Kind
    var price: Double?
    /// Share of the position trimmed or added, 1–100
    var percent: Double?
    var note: String?

    /// "50%", "12.5%"
    static func formatShare(_ percent: Double) -> String {
        percent.rounded() == percent ? "\(Int(percent))%" : String(format: "%.1f%%", percent)
    }

    /// Plain-text summary used as the message's `content`: "Trimmed 50% of $TSLA at $251.20".
    func summary(ticker: String) -> String {
        let symbol = "$\(ticker)"
        var text: String
        switch kind {
        case .trim:
            text = "Trimmed \(percent.map(Self.formatShare) ?? "part") of \(symbol)"
            if let price { text += " at \(TradeCallout.formatPrice(price))" }
        case .add:
            text = "Added \(percent.map(Self.formatShare) ?? "more") to \(symbol)"
            if let price { text += " at \(TradeCallout.formatPrice(price))" }
        case .moveStop:
            text = "Moved \(symbol) stop to \(price.map(TradeCallout.formatPrice) ?? "a new level")"
        case .moveTarget:
            text = "Moved \(symbol) target to \(price.map(TradeCallout.formatPrice) ?? "a new level")"
        case .note:
            text = "\(symbol) update"
        }
        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            text += kind == .note ? ": \(note)" : ". \(note)"
        }
        return text
    }

    /// The headline without the note, for compact rows and the timeline.
    func headline(ticker: String) -> String {
        var copy = self
        copy.note = nil
        return kind == .note ? "Note" : copy.summary(ticker: ticker)
    }

    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "parentMessageId": parentMessageId,
            "kind": kind.rawValue
        ]
        if let price { data["price"] = price }
        if let percent { data["percent"] = percent }
        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty { data["note"] = note }
        return data
    }

    static func fromFirestore(_ data: [String: Any]) -> CalloutUpdate? {
        guard let parentMessageId = data["parentMessageId"] as? String, !parentMessageId.isEmpty,
              let kind = Kind(rawValue: data["kind"] as? String ?? "") else { return nil }
        return CalloutUpdate(
            parentMessageId: parentMessageId,
            kind: kind,
            price: TrackRecordDecode.double(data["price"]),
            percent: TrackRecordDecode.double(data["percent"]),
            note: data["note"] as? String
        )
    }
}

/// The author's result post after a callout closes:
/// `calloutResult: { parentMessageId, ticker, direction, status, exitPrice, resultPercent, exitCheck }`.
/// `status`, `exitPrice` and `resultPercent` are exactly the values written to the closed callout
/// (the rules compare them).
struct CalloutResult: Codable, Equatable {
    var parentMessageId: String
    var ticker: String
    var direction: TradeCallout.Direction
    var status: TradeCallout.Status
    var exitPrice: Double
    var resultPercent: Double
    /// "live" when the exit was checked against a live price (auto-closes, checked manual closes)
    var exitCheck: TradeCallout.PriceCheck

    init(parentMessageId: String, ticker: String, direction: TradeCallout.Direction, status: TradeCallout.Status,
         exitPrice: Double, resultPercent: Double, exitCheck: TradeCallout.PriceCheck) {
        self.parentMessageId = parentMessageId
        self.ticker = ticker
        self.direction = direction
        self.status = status
        self.exitPrice = exitPrice
        self.resultPercent = resultPercent
        self.exitCheck = exitCheck
    }

    /// From a callout that just closed, with the numbers that were written to it. Nil while open.
    init?(closed callout: TradeCallout, parentMessageId: String, exitCheck: TradeCallout.PriceCheck) {
        guard !callout.isOpen, let exit = callout.exitPrice, let result = callout.resultPercent else { return nil }
        self.init(parentMessageId: parentMessageId, ticker: callout.ticker, direction: callout.direction,
                  status: callout.status, exitPrice: exit, resultPercent: result, exitCheck: exitCheck)
    }

    var isWin: Bool { resultPercent > 0 }

    /// Green for wins, red for losses, neutral when flat.
    var tint: Color {
        if resultPercent > 0 { return .marketGreen }
        if resultPercent < 0 { return .marketRed }
        return .secondary
    }

    /// How it closed: "Target hit", "Stopped out" or "Closed".
    var howClosed: String { status.displayName }

    var isPriceChecked: Bool { exitCheck == .live }

    /// "Price checked" or "Unchecked"
    var checkLabel: String { isPriceChecked ? "Price checked" : "Unchecked" }

    /// Plain-text summary used as the message's `content`.
    var summary: String {
        let mark = resultPercent > 0 ? "✅" : (resultPercent < 0 ? "🔻" : "➖")
        return "\(mark) $\(ticker) \(howClosed.lowercased()): \(TradeCallout.formatPercent(resultPercent))"
            + " (\(direction.displayName), exit \(TradeCallout.formatPrice(exitPrice))) · \(checkLabel)"
    }

    func toFirestore() -> [String: Any] {
        [
            "parentMessageId": parentMessageId,
            "ticker": ticker,
            "direction": direction.rawValue,
            "status": status.rawValue,
            "exitPrice": exitPrice,
            "resultPercent": resultPercent,
            "exitCheck": exitCheck.rawValue
        ]
    }

    static func fromFirestore(_ data: [String: Any]) -> CalloutResult? {
        guard let parentMessageId = data["parentMessageId"] as? String,
              let ticker = data["ticker"] as? String,
              let status = TradeCallout.Status(rawValue: data["status"] as? String ?? ""),
              let exitPrice = TrackRecordDecode.double(data["exitPrice"]),
              let resultPercent = TrackRecordDecode.double(data["resultPercent"]) else { return nil }
        return CalloutResult(
            parentMessageId: parentMessageId,
            ticker: ticker,
            direction: TradeCallout.Direction(rawValue: data["direction"] as? String ?? "") ?? .long,
            status: status,
            exitPrice: exitPrice,
            resultPercent: resultPercent,
            exitCheck: TradeCallout.PriceCheck(rawValue: data["exitCheck"] as? String ?? "") ?? .unchecked
        )
    }
}
