//
//  Trade.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Shared/Models/Trade.swift

import Foundation

struct Trade: Identifiable, Codable {
    let id: UUID
    var ticker: String
    var tradeType: TradeType
    var entryPrice: Double
    var exitPrice: Double?
    var quantity: Int
    var entryDate: Date
    var exitDate: Date?
    var notes: String?
    var strategy: String?
    var isOpen: Bool
    var userId: UUID
    
    var profitLoss: Double {
        guard let exitPrice = exitPrice else { return 0 }
        return (exitPrice - entryPrice) * Double(quantity)
    }
    
    var profitLossPercentage: Double {
        guard let exitPrice = exitPrice else { return 0 }
        return ((exitPrice - entryPrice) / entryPrice) * 100
    }
    
    var currentValue: Double {
        if let exitPrice = exitPrice {
            return exitPrice * Double(quantity)
        }
        return entryPrice * Double(quantity)
    }
    
    init(ticker: String, tradeType: TradeType, entryPrice: Double, quantity: Int, userId: UUID) {
        self.id = UUID()
        self.ticker = ticker.uppercased()
        self.tradeType = tradeType
        self.entryPrice = entryPrice
        self.exitPrice = nil
        self.quantity = quantity
        self.entryDate = Date()
        self.exitDate = nil
        self.notes = nil
        self.strategy = nil
        self.isOpen = true
        self.userId = userId
    }
}

enum TradeType: String, CaseIterable, Codable {
    case stock = "stock"
    case option = "option"
    
    var displayName: String {
        switch self {
        case .stock: return "Stock"
        case .option: return "Option"
        }
    }
}
