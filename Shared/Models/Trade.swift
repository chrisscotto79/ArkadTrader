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
    var quantity: Int
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
    
    // MARK: - Computed Properties
    
    var profitLoss: Double {
        guard let exitPrice = exitPrice else { return 0 }
        return (exitPrice - entryPrice) * Double(quantity)
    }
    
    var profitLossPercentage: Double {
        guard let exitPrice = exitPrice else { return 0 }
        return ((exitPrice - entryPrice) / entryPrice) * 100
    }
    
    var currentValue: Double {
        if isOpen {
            let price = (currentPrice != nil && currentPrice! > 0) ? currentPrice! : entryPrice
            return price * Double(quantity)
        } else {
            let price = exitPrice ?? entryPrice
            return price * Double(quantity)
        }
    }
    
    var unrealizedPL: Double {
        guard isOpen else { return 0 }
        guard let current = currentPrice, current > 0 else { return 0 }
        return (current - entryPrice) * Double(quantity)
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
        return entryPrice * Double(quantity)
    }
    
    var hasSignificantPriceMovement: Bool {
        guard isOpen, let current = currentPrice else { return false }
        let priceChangePercentage = abs((current - entryPrice) / entryPrice) * 100
        return priceChangePercentage >= 1.0
    }
    
    // MARK: - Risk Management Properties
    
    var riskAmount: Double {
        guard let stopLoss = stopLossPrice else { return totalInvested }
        return abs(entryPrice - stopLoss) * Double(quantity)
    }
    
    var potentialReward: Double {
        guard let takeProfit = takeProfitPrice else { return 0 }
        return abs(takeProfit - entryPrice) * Double(quantity)
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
    
    init(ticker: String, tradeType: TradeType, entryPrice: Double, quantity: Int, userId: UUID) {
        self.init(ticker: ticker, tradeType: tradeType, entryPrice: entryPrice, quantity: quantity, userId: userId.uuidString)
    }
    
    init(ticker: String, tradeType: TradeType, entryPrice: Double, quantity: Int, userId: String) {
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
        
        return data
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> Trade {
        guard let userId = data["userId"] as? String,
              let ticker = data["ticker"] as? String,
              let tradeTypeString = data["tradeType"] as? String,
              let tradeType = TradeType(rawValue: tradeTypeString),
              let entryPrice = data["entryPrice"] as? Double,
              let quantity = data["quantity"] as? Int,
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
        
        return trade
    }
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
