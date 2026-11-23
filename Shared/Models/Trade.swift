// File: Shared/Models/Trade.swift
// Enhanced Trade Model - Compatible with Existing Code

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
    var proof: TradeProof = .selfReported
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

    /// How long after `loggedAt` a price-checked trade can still be deleted (the rules allow 15 minutes).
    static let priceCheckedDeleteWindow: TimeInterval = 15 * 60

    /// When a price-checked trade stops being deletable, or nil when it can always be deleted.
    /// A small margin keeps the app from offering a delete the server would just refuse.
    var deleteDeadline: Date? {
        guard proof == .priceChecked else { return nil }
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
    
    var profitLoss: Double {
        guard let exitPrice = exitPrice else { return 0 }
        return (exitPrice - entryPrice) * quantity
    }
    
    var profitLossPercentage: Double {
        guard let exitPrice = exitPrice else { return 0 }
        return ((exitPrice - entryPrice) / entryPrice) * 100
    }
    
    var currentValue: Double {
        if isOpen {
            let price = (currentPrice != nil && currentPrice! > 0) ? currentPrice! : entryPrice
            return price * quantity
        } else {
            let price = exitPrice ?? entryPrice
            return price * quantity
        }
    }
    
    var unrealizedPL: Double {
        guard isOpen else { return 0 }
        guard let current = currentPrice, current > 0 else { return 0 }
        return (current - entryPrice) * quantity
    }
    
    var unrealizedPLPercentage: Double {
        guard isOpen else { return 0 }
        guard let current = currentPrice, current > 0, entryPrice > 0 else { return 0 }
        return ((current - entryPrice) / entryPrice) * 100
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
        guard isOpen, let current = currentPrice else { return false }
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
    /// Proof: `proof`, `loggedAt` (server time) and, for price-checked entries, `priceCheck`.
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
            "tags": tags
        ]
        
        if let exitPrice = exitPrice {
            data["exitPrice"] = exitPrice
        }
        
        if let currentPrice = currentPrice {
            data["currentPrice"] = currentPrice
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
        trade.loggedAt = (data["loggedAt"] as? Timestamp)?.dateValue()
        trade.priceCheck = (data["priceCheck"] as? [String: Any]).flatMap(TradePriceCheck.fromFirestore)
        trade.exitProof = (data["exitProof"] as? String).flatMap(TradeProof.init(rawValue:))
        trade.exitLoggedAt = (data["exitLoggedAt"] as? Timestamp)?.dateValue()
        
        return trade
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
        case .priceChecked: return "Logged as it happened, at a price inside the day's market range."
        case .selfReported: return "Entered by the trader and not checked against market prices. Doesn't count toward win rate or P&L."
        }
    }
}

/// The day range a price was checked against: `priceCheck: { low, high, checkedAt }`.
struct TradePriceCheck: Codable, Equatable {
    /// Finnhub's day low and high (before the 0.5% widening for quote delay)
    var low: Double
    var high: Double
    var checkedAt: Date

    func toFirestore() -> [String: Any] {
        ["low": low, "high": high, "checkedAt": Timestamp(date: checkedAt)]
    }

    static func fromFirestore(_ data: [String: Any]) -> TradePriceCheck? {
        guard let low = (data["low"] as? NSNumber)?.doubleValue,
              let high = (data["high"] as? NSNumber)?.doubleValue else { return nil }
        let checkedAt = (data["checkedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
        return TradePriceCheck(low: low, high: high, checkedAt: checkedAt)
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
