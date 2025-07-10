// File: Shared/Models/Trade.swift
// Fixed Trade Model with Current Price for Real-time Updates

import Foundation
import FirebaseFirestore

struct Trade: Identifiable, Codable {
    var id: String
    var userId: String
    var ticker: String
    var tradeType: TradeType
    var entryPrice: Double
    var exitPrice: Double?
    var currentPrice: Double? // New property for real-time price tracking
    var quantity: Int
    var entryDate: Date
    var exitDate: Date?
    var notes: String?
    var strategy: String?
    var isOpen: Bool
    var sharedCommunityIds: [String]
    
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
            // For open trades, use currentPrice if available, otherwise entryPrice
            let price = currentPrice ?? entryPrice
            return price * Double(quantity)
        } else {
            // For closed trades, use exitPrice
            return (exitPrice ?? entryPrice) * Double(quantity)
        }
    }
    
    var unrealizedPL: Double {
        guard isOpen, let current = currentPrice else { return 0 }
        return (current - entryPrice) * Double(quantity)
    }
    
    var unrealizedPLPercentage: Double {
        guard isOpen, let current = currentPrice else { return 0 }
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
        self.currentPrice = entryPrice // Initialize with entry price
        self.quantity = quantity
        self.entryDate = Date()
        self.exitDate = nil
        self.notes = nil
        self.strategy = nil
        self.isOpen = true
        self.sharedCommunityIds = []
    }

    // MARK: - Firebase Integration

    func toFirestore() -> [String: Any] {
        let data: [String: Any?] = [
            "userId": userId,
            "ticker": ticker,
            "tradeType": tradeType.rawValue,
            "entryPrice": entryPrice,
            "exitPrice": exitPrice,
            "currentPrice": currentPrice,
            "quantity": quantity,
            "entryDate": Timestamp(date: entryDate),
            "exitDate": exitDate.map { Timestamp(date: $0) },
            "notes": notes,
            "strategy": strategy,
            "isOpen": isOpen,
            "sharedCommunityIds": sharedCommunityIds
        ]
        return data.compactMapValues { $0 }
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
            throw FirestoreError.invalidData
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

        return trade
    }
    
    // MARK: - Helper Methods
    
    mutating func updateCurrentPrice(_ newPrice: Double) {
        guard isOpen else { return } // Only update price for open trades
        self.currentPrice = newPrice
    }
    
    mutating func close(at exitPrice: Double, on exitDate: Date = Date()) {
        self.exitPrice = exitPrice
        self.exitDate = exitDate
        self.isOpen = false
        self.currentPrice = nil // Clear current price when trade is closed
    }
}

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
    
}
