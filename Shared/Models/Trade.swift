// File: Shared/Models/Trade.swift
// A logged trade: trades/{id}. Long or short (`side`); every P&L is signed by the side.

import Foundation
import FirebaseFirestore
import SwiftUI

struct Trade: Identifiable, Codable {
    var id: String
    var userId: String
    var ticker: String
    var tradeType: TradeType
    var entryPrice: Double
    var exitPrice: Double?
    var currentPrice: Double?
    /// Shares, contracts, coins or units. Fractional amounts are allowed (crypto, forex, fractional shares).
    var quantity: Double
    var entryDate: Date
    var exitDate: Date?
    var notes: String?
    var strategy: String?
    var isOpen: Bool
    var sharedCommunityIds: [String]
    var isPublic: Bool = false
    /// Long (profit when the price rises) or short (profit when it falls). Missing on old trades = long.
    var side: TradeSide = .long
    
    // MARK: - Enhanced Properties (Optional - can be nil if not set)
    var stopLossPrice: Double?
    var takeProfitPrice: Double?
    var sector: String?
    var tags: [String] = []

    // MARK: - Brokerage import (written by the server, never by the app)
    /// "brokerage" for trades imported through SnapTrade; nil or "manual" for trades the user entered
    var source: String?
    /// True for imported trades, which come straight from the brokerage
    var isVerified: Bool?
    /// The brokerage's id for this trade, used by the server to avoid importing it twice
    var externalId: String?
    var brokerageConnectionId: String?

    /// Imported trades are read-only in the app
    var isImported: Bool { source == "brokerage" }

    // MARK: - Proof label (docs/backend-contracts.md, section 0: "Proof labels")
    /// How much the trade can be trusted. A missing `proof` field means self-reported.
    /// Set when the trade is logged and never lowered afterwards (closing doesn't change it).
    var proof: TradeProof = .selfReported
    /// The proof the entry got when the trade was logged. Written once on create and never changed
    /// (the rules lock it). Nil on trades logged before it existed: use `entryProofValue`.
    var entryProof: TradeProof?
    /// Server time the trade was logged (`FieldValue.serverTimestamp()` on create).
    /// Nil on old trades, and briefly nil locally until the server has set it.
    var loggedAt: Date?
    /// The day range the entry price was checked against, for price-checked trades.
    var priceCheck: TradePriceCheck?
    /// How the exit was checked ("price_checked" or "self_reported"); nil while open and on old trades.
    var exitProof: TradeProof?
    /// Server time the trade was closed in the app.
    var exitLoggedAt: Date?

    /// Only price-checked and verified trades count toward win rate, P&L and performance.
    var countsTowardStats: Bool { proof.countsTowardStats }

    /// The entry's proof, falling back to `proof` for trades logged before `entryProof` existed.
    var entryProofValue: TradeProof { entryProof ?? proof }

    /// A counted trade whose exit price wasn't checked against the market (closed on another day,
    /// or while quotes were unavailable). It still counts; the UI flags it "Exit not checked".
    var exitNotChecked: Bool {
        !isOpen && proof == .priceChecked && exitProof == .selfReported
    }

    /// +1 for long, -1 for short
    var sideSign: Double { side.sign }

    /// How long after `loggedAt` a price-checked trade can still be deleted (the rules allow 15 minutes).
    static let priceCheckedDeleteWindow: TimeInterval = 15 * 60

    /// When a price-checked trade stops being deletable, or nil when it can always be deleted.
    /// Based on the entry's proof. A small margin keeps the app from offering a delete the server
    /// would just refuse.
    var deleteDeadline: Date? {
        guard entryProofValue == .priceChecked else { return nil }
        // Not yet confirmed by the server: it was logged moments ago
        let logged = loggedAt ?? Date()
        return logged.addingTimeInterval(Trade.priceCheckedDeleteWindow - 30)
    }

    /// Imported trades are never deleted here; price-checked trades only shortly after logging.
    func canDelete(at now: Date = Date()) -> Bool {
        guard !isImported, proof != .verified else { return false }
        guard let deadline = deleteDeadline else { return true }
        return now < deadline
    }
    
    // MARK: - Computed Properties
    
    /// Realized P&L of a closed trade, signed by the side (a short gains when the price falls).
    var profitLoss: Double {
        guard let exitPrice = exitPrice else { return 0 }
        return Trade.profitLoss(side: side, entry: entryPrice, exit: exitPrice, quantity: quantity)
    }
    
    var profitLossPercentage: Double {
        guard let exitPrice = exitPrice, entryPrice > 0 else { return 0 }
        return Trade.returnPercent(side: side, entry: entryPrice, exit: exitPrice)
    }

    /// P&L for `quantity` at `exit`, signed by `side`. Shared by trades, the close preview and the risk plan.
    static func profitLoss(side: TradeSide, entry: Double, exit: Double, quantity: Double) -> Double {
        side.sign * (exit - entry) * quantity
    }

    /// Percent return from entry to exit, signed by `side`; 0 without a positive entry.
    static func returnPercent(side: TradeSide, entry: Double, exit: Double) -> Double {
        guard entry > 0 else { return 0 }
        return side.sign * (exit - entry) / entry * 100
    }
    
    /// What the position is worth: cost basis plus its P&L (for a short, the margin held plus
    /// the gain or loss on the borrowed shares).
    var currentValue: Double {
        totalInvested + (isOpen ? unrealizedPL : profitLoss)
    }
    
    /// Open position's P&L at the live price, signed by the side (0 without a live price).
    var unrealizedPL: Double {
        guard isOpen else { return 0 }
        guard let current = currentPrice, current > 0 else { return 0 }
        return Trade.profitLoss(side: side, entry: entryPrice, exit: current, quantity: quantity)
    }
    
    var unrealizedPLPercentage: Double {
        guard isOpen else { return 0 }
        guard let current = currentPrice, current > 0, entryPrice > 0 else { return 0 }
        return Trade.returnPercent(side: side, entry: entryPrice, exit: current)
    }
    
    var daysHeld: Int {
        let endDate = exitDate ?? Date()
        return Calendar.current.dateComponents([.day], from: entryDate, to: endDate).day ?? 0
    }
    
    var formattedEntryDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: entryDate)
    }
    
    var statusText: String {
        isOpen ? "OPEN" : (profitLoss >= 0 ? "PROFIT" : "LOSS")
    }
    
    var shareableContent: String {
        let performance = profitLoss >= 0 ? "📈 +\(profitLoss.asCurrency)" : "📉 \(profitLoss.asCurrency)"
        return "Just \(isOpen ? "opened" : "closed") my \(ticker) position! \(performance)"
    }
    
    var isRecentlyUpdated: Bool {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return entryDate > oneDayAgo
    }
    
    var totalInvested: Double {
        return entryPrice * quantity
    }
    
    var hasSignificantPriceMovement: Bool {
        guard isOpen, let current = currentPrice, entryPrice > 0 else { return false }
        let priceChangePercentage = abs((current - entryPrice) / entryPrice) * 100
        return priceChangePercentage >= 1.0
    }
    
    // MARK: - Risk Management Properties
    
    var riskAmount: Double {
        guard let stopLoss = stopLossPrice else { return totalInvested }
        return abs(entryPrice - stopLoss) * quantity
    }
    
    var potentialReward: Double {
        guard let takeProfit = takeProfitPrice else { return 0 }
        return abs(takeProfit - entryPrice) * quantity
    }
    
    var riskRewardRatio: Double {
        let risk = riskAmount
        let reward = potentialReward
        return risk > 0 ? reward / risk : 0
    }
    
    var isNearStopLoss: Bool {
        guard isOpen, let current = currentPrice, let stopLoss = stopLossPrice else { return false }
        let threshold = abs(entryPrice - stopLoss) * 0.1
        return abs(current - stopLoss) <= threshold
    }
    
    var isNearTakeProfit: Bool {
        guard isOpen, let current = currentPrice, let takeProfit = takeProfitPrice else { return false }
        let threshold = abs(takeProfit - entryPrice) * 0.1
        return abs(current - takeProfit) <= threshold
    }
    
    // MARK: - Initializers
    
    init(ticker: String, tradeType: TradeType, entryPrice: Double, quantity: Double, userId: UUID) {
        self.init(ticker: ticker, tradeType: tradeType, entryPrice: entryPrice, quantity: quantity, userId: userId.uuidString)
    }
    
    init(ticker: String, tradeType: TradeType, entryPrice: Double, quantity: Double, userId: String) {
        self.id = UUID().uuidString
        self.userId = userId
        self.ticker = ticker.uppercased()
        self.tradeType = tradeType
        self.entryPrice = entryPrice
        self.exitPrice = nil
        self.currentPrice = entryPrice
        self.quantity = quantity
        self.entryDate = Date()
        self.exitDate = nil
        self.notes = nil
        self.strategy = nil
        self.isOpen = true
        self.sharedCommunityIds = []
    }
    
    // MARK: - Trade Management Methods
    
    mutating func updateCurrentPrice(_ newPrice: Double) {
        guard isOpen else { return }
        self.currentPrice = newPrice
    }
    
    mutating func close(at exitPrice: Double, on exitDate: Date = Date()) {
        self.exitPrice = exitPrice
        self.exitDate = exitDate
        self.isOpen = false
        self.currentPrice = nil
    }
    
    mutating func setStopLoss(_ price: Double) {
        self.stopLossPrice = price
    }
    
    mutating func setTakeProfit(_ price: Double) {
        self.takeProfitPrice = price
    }
    
    mutating func addTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanTag.isEmpty && !tags.contains(cleanTag) {
            tags.append(cleanTag)
        }
    }
    
    // MARK: - Firebase Integration
    
    /// The data for creating the trade document (FirebaseServices.addTrade).
    /// The brokerage fields (`source`, `isVerified`, `externalId`, `brokerageConnectionId`) are left out
    /// on purpose: only the server writes them.
    /// Proof: `proof` and the immutable `entryProof` (equal on create), `loggedAt` (server time) and,
    /// for price-checked entries, `priceCheck`.
    /// A trade created already closed has an unchecked exit, so it's self-reported overall.
    /// Updates don't use this: see FirebaseServices.updateTrade / closeTrade, which never rewrite
    /// the fields the rules lock after create.
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "ticker": ticker,
            "tradeType": tradeType.rawValue,
            "entryPrice": entryPrice,
            "quantity": quantity,
            "entryDate": Timestamp(date: entryDate),
            "notes": notes as Any,
            "strategy": strategy as Any,
            "isOpen": isOpen,
            "sharedCommunityIds": sharedCommunityIds,
            "isPublic": isPublic,
            "side": side.rawValue,
            "tags": tags
        ]
        
        if let exitPrice = exitPrice {
            data["exitPrice"] = exitPrice
        }
        
        if let exitDate = exitDate {
            data["exitDate"] = Timestamp(date: exitDate)
        }
        
        if let stopLossPrice = stopLossPrice {
            data["stopLossPrice"] = stopLossPrice
        }
        
        if let takeProfitPrice = takeProfitPrice {
            data["takeProfitPrice"] = takeProfitPrice
        }
        
        if let sector = sector {
            data["sector"] = sector
        }

        // Proof. The rules only accept "price_checked" or "self_reported" from the app.
        var createProof: TradeProof = proof == .priceChecked ? .priceChecked : .selfReported
        if !isOpen {
            createProof = .selfReported
            data["exitProof"] = TradeProof.selfReported.rawValue
            data["exitLoggedAt"] = FieldValue.serverTimestamp()
        }
        data["proof"] = createProof.rawValue
        data["entryProof"] = createProof.rawValue
        data["loggedAt"] = FieldValue.serverTimestamp()
        if createProof == .priceChecked, let priceCheck {
            data["priceCheck"] = priceCheck.toFirestore()
        }
        
        return data
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> Trade {
        guard let userId = data["userId"] as? String,
              let ticker = data["ticker"] as? String,
              let tradeTypeString = data["tradeType"] as? String,
              let tradeType = TradeType(rawValue: tradeTypeString),
              let entryPrice = data["entryPrice"] as? Double,
              let quantity = (data["quantity"] as? NSNumber)?.doubleValue,
              let entryDateTimestamp = data["entryDate"] as? Timestamp,
              let isOpen = data["isOpen"] as? Bool else {
            throw NSError(domain: "FirestoreError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid data"])
        }
        
        var trade = Trade(ticker: ticker, tradeType: tradeType, entryPrice: entryPrice, quantity: quantity, userId: userId)
        trade.id = id
        trade.exitPrice = data["exitPrice"] as? Double
        trade.currentPrice = data["currentPrice"] as? Double
        trade.notes = data["notes"] as? String
        trade.strategy = data["strategy"] as? String
        trade.sharedCommunityIds = data["sharedCommunityIds"] as? [String] ?? []
        trade.entryDate = entryDateTimestamp.dateValue()
        trade.exitDate = (data["exitDate"] as? Timestamp)?.dateValue()
        trade.isOpen = isOpen
        trade.isPublic = data["isPublic"] as? Bool ?? false
        trade.side = (data["side"] as? String).flatMap(TradeSide.init(rawValue:)) ?? .long
        trade.stopLossPrice = data["stopLossPrice"] as? Double
        trade.takeProfitPrice = data["takeProfitPrice"] as? Double
        trade.sector = data["sector"] as? String
        trade.tags = data["tags"] as? [String] ?? []
        trade.source = data["source"] as? String
        trade.isVerified = data["isVerified"] as? Bool
        trade.externalId = data["externalId"] as? String
        trade.brokerageConnectionId = data["brokerageConnectionId"] as? String

        // Missing proof = self-reported. Brokerage imports written before proof existed count as verified.
        if let raw = data["proof"] as? String, let proof = TradeProof(rawValue: raw) {
            trade.proof = proof
        } else {
            trade.proof = (trade.isImported && trade.isVerified == true) ? .verified : .selfReported
        }
        trade.entryProof = (data["entryProof"] as? String).flatMap(TradeProof.init(rawValue:))
        // Read with serverTimestampBehavior .estimate (see `from(document:)`), so a just-logged
        // trade has its estimated time rather than nil
        trade.loggedAt = (data["loggedAt"] as? Timestamp)?.dateValue()
        trade.priceCheck = (data["priceCheck"] as? [String: Any]).flatMap(TradePriceCheck.fromFirestore)
        trade.exitProof = (data["exitProof"] as? String).flatMap(TradeProof.init(rawValue:))
        trade.exitLoggedAt = (data["exitLoggedAt"] as? Timestamp)?.dateValue()
        
        return trade
    }

    /// Decodes a trade document, estimating pending server timestamps (`loggedAt` right after logging).
    static func from(document: DocumentSnapshot) -> Trade? {
        guard let data = document.data(with: .estimate) else { return nil }
        return try? fromFirestore(data: data, id: document.documentID)
    }
}

// MARK: - Side

/// Long or short. Stored as `side` on trades ("long" / "short"); missing means long.
enum TradeSide: String, Codable, CaseIterable {
    case long
    case short

    var sign: Double { self == .long ? 1 : -1 }

    var displayName: String {
        switch self {
        case .long: return "Long"
        case .short: return "Short"
        }
    }

    /// "Buy" / "Sell short", for sentences and pickers
    var actionName: String {
        switch self {
        case .long: return "Buy"
        case .short: return "Sell short"
        }
    }

    /// Why a stop loss is on the wrong side of the entry, or nil when it's fine.
    func stopLossProblem(stop: Double, entry: Double) -> String? {
        switch self {
        case .long where stop >= entry: return "For a long, the stop loss should be below your entry."
        case .short where stop <= entry: return "For a short, the stop loss should be above your entry."
        default: return nil
        }
    }

    /// Why a take profit is on the wrong side of the entry, or nil when it's fine.
    func takeProfitProblem(target: Double, entry: Double) -> String? {
        switch self {
        case .long where target <= entry: return "For a long, the take profit should be above your entry."
        case .short where target >= entry: return "For a short, the take profit should be below your entry."
        default: return nil
        }
    }
}

// MARK: - Proof labels

/// How much a trade (or a trade-result post) can be trusted. Stored as `proof` on trades.
enum TradeProof: String, Codable, CaseIterable {
    /// Imported from a linked brokerage
    case verified = "verified"
    /// Logged as it happened, at a price inside the day's range from a live quote
    case priceChecked = "price_checked"
    /// Anything else (and any trade without a `proof` field)
    case selfReported = "self_reported"

    init(firestoreValue: Any?) {
        self = (firestoreValue as? String).flatMap(TradeProof.init(rawValue:)) ?? .selfReported
    }

    var countsTowardStats: Bool { self != .selfReported }

    var label: String {
        switch self {
        case .verified: return "Verified"
        case .priceChecked: return "Price checked"
        case .selfReported: return "Self-reported"
        }
    }

    var systemImage: String {
        switch self {
        case .verified: return "checkmark.seal.fill"
        case .priceChecked: return "checkmark.shield.fill"
        case .selfReported: return "questionmark.circle"
        }
    }

    /// Design-system colours that work in light and dark mode
    var tint: Color {
        switch self {
        case .verified: return .marketGreen
        case .priceChecked: return .goldText
        case .selfReported: return .secondary
        }
    }

    /// One line for detail screens and accessibility
    var explanation: String {
        switch self {
        case .verified: return "Imported from a linked brokerage."
        case .priceChecked: return "Logged as it happened, within 1% of the live market price."
        case .selfReported: return "Entered by the trader and not checked against market prices. Doesn't count toward win rate or P&L."
        }
    }
}

/// What a price was checked against: `priceCheck: { price, low, high, checkedAt }`.
/// `price` is the live quote at logging time and `low`...`high` the accepted band around it
/// (±1%, TradePriceCheckRules.tolerance). Older trades stored the day's low and high, without `price`.
struct TradePriceCheck: Codable, Equatable {
    var low: Double
    var high: Double
    var checkedAt: Date
    /// The live quote the band was built from (nil on older trades)
    var price: Double? = nil

    func toFirestore() -> [String: Any] {
        var data: [String: Any] = ["low": low, "high": high, "checkedAt": Timestamp(date: checkedAt)]
        if let price { data["price"] = price }
        return data
    }

    static func fromFirestore(_ data: [String: Any]) -> TradePriceCheck? {
        guard let low = (data["low"] as? NSNumber)?.doubleValue,
              let high = (data["high"] as? NSNumber)?.doubleValue else { return nil }
        let checkedAt = (data["checkedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
        return TradePriceCheck(low: low, high: high, checkedAt: checkedAt,
                               price: (data["price"] as? NSNumber)?.doubleValue)
    }
}

/// Win rate and P&L over a set of trades. Use `TradeStats(counted: trades)` for anything shown as
/// performance (only price-checked and verified trades), and `TradeStats(selfReported: trades)` for
/// the separately labelled self-reported totals.
struct TradeStats: Equatable {
    var closedCount = 0
    var winCount = 0
    var lossCount = 0
    var openCount = 0
    /// Sum of closed trades' P&L
    var realizedPL: Double = 0
    /// Sum of open stock positions' P&L at the live price (0 without one)
    var unrealizedPL: Double = 0
    /// Closed trades' P&L for trades closed today
    var closedTodayPL: Double = 0
    var bestTradeId: String?
    var bestTradePL: Double?

    var tradeCount: Int { closedCount + openCount }
    var hasClosedTrades: Bool { closedCount > 0 }
    /// 0–100; 0 without closed trades (check `hasClosedTrades` before showing it)
    var winRate: Double { closedCount > 0 ? Double(winCount) / Double(closedCount) * 100 : 0 }
    var totalPL: Double { realizedPL + unrealizedPL }

    init(trades: [Trade]) {
        let calendar = Calendar.current
        var best: Trade?
        for trade in trades {
            if trade.isOpen {
                openCount += 1
                unrealizedPL += trade.unrealizedPL
            } else {
                closedCount += 1
                let pl = trade.profitLoss
                realizedPL += pl
                if pl > 0 { winCount += 1 } else if pl < 0 { lossCount += 1 }
                if let exit = trade.exitDate, calendar.isDateInToday(exit) { closedTodayPL += pl }
                if best == nil || pl > best!.profitLoss { best = trade }
            }
        }
        bestTradeId = best?.id
        bestTradePL = best?.profitLoss
    }

    /// Only price-checked and verified trades
    init(counted trades: [Trade]) {
        self.init(trades: trades.filter(\.countsTowardStats))
    }

    /// Only self-reported trades
    init(selfReported trades: [Trade]) {
        self.init(trades: trades.filter { !$0.countsTowardStats })
    }

    /// The public track record: public, closed, price-checked or verified trades, realized P&L
    /// only (no unrealized P&L from possibly stale prices). The user's profile document
    /// (`totalProfitLoss`, `winRate`) is written from this, and other people's profiles show the
    /// same numbers computed from their public trades.
    static func publicRecord(_ trades: [Trade]) -> TradeStats {
        TradeStats(trades: trades.filter { $0.isPublic && !$0.isOpen && $0.countsTowardStats })
    }
}

extension Array where Element == Trade {
    /// Trades that count toward win rate, P&L and performance
    var countedForStats: [Trade] { filter(\.countsTowardStats) }
}

// MARK: - Keep Your Existing TradeType Enum
enum TradeType: String, CaseIterable, Codable {
    case stock = "stock"
    case option = "option"
    case crypto = "crypto"
    case forex = "forex"
    
    var displayName: String {
        switch self {
        case .stock: return "Stock"
        case .option: return "Option"
        case .crypto: return "Crypto"
        case .forex: return "Forex"
        }
    }
    
    var icon: String {
        switch self {
        case .stock: return "chart.line.uptrend.xyaxis"
        case .option: return "timer"
        case .crypto: return "bitcoinsign.circle"
        case .forex: return "dollarsign.circle"
        }
    }
    
    // Add color property to match enhanced TradeType
    var color: Color {
        switch self {
        case .stock: return .blue
        case .option: return .purple
        case .crypto: return .orange
        case .forex: return .green
        }
    }
    
    var description: String {
        switch self {
        case .stock: return "Equity shares"
        case .option: return "Call & Put contracts"
        case .crypto: return "Digital currency"
        case .forex: return "Currency pairs"
        }
    }
}
