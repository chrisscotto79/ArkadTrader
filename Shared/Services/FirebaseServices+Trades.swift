// File: Shared/Services/FirebaseServices+Trades.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

extension FirebaseServices {
    // MARK: - Trade Management
    
    /// Creates the trade. `Trade.toFirestore()` adds `proof`, `loggedAt` (server time) and, for a
    /// price-checked entry, `priceCheck { low, high, checkedAt }`, which the rules require.
    func addTrade(_ trade: Trade) async throws {
        try await db.collection("trades").document(trade.id).setData(trade.toFirestore())
    }
    
    /// Saves only the fields that may change after logging (firestore.rules lock ticker, tradeType,
    /// entryPrice, quantity, entryDate, proof, loggedAt and priceCheck, and a closed trade's exit).
    /// Locked fields are never rewritten, so a Date round trip can't count as a change.
    /// Closing goes through `closeTrade`.
    func updateTrade(_ trade: Trade) async throws {
        var data: [String: Any] = [
            "notes": trade.notes.map { $0 as Any } ?? NSNull(),
            "strategy": trade.strategy.map { $0 as Any } ?? NSNull(),
            "tags": trade.tags,
            "isPublic": trade.isPublic,
            "sharedCommunityIds": trade.sharedCommunityIds
        ]
        data["stopLossPrice"] = trade.stopLossPrice.map { $0 as Any } ?? FieldValue.delete()
        data["takeProfitPrice"] = trade.takeProfitPrice.map { $0 as Any } ?? FieldValue.delete()
        if let sector = trade.sector { data["sector"] = sector }
        if trade.isOpen, let currentPrice = trade.currentPrice { data["currentPrice"] = currentPrice }
        try await db.collection("trades").document(trade.id).updateData(data)
    }

    /// Closes an open trade: the exit, its proof and the overall proof in one write.
    /// Writes `isOpen: false`, `exitPrice`, `exitDate`, `exitProof`, `exitLoggedAt` (server time,
    /// which the rules require for a price-checked exit) and `proof` when it drops to self-reported.
    func closeTrade(_ trade: Trade) async throws {
        guard let exitPrice = trade.exitPrice, let exitDate = trade.exitDate else {
            throw NSError(domain: "TradeClose", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "The exit price and date are missing."])
        }
        var data: [String: Any] = [
            "isOpen": false,
            "exitPrice": exitPrice,
            "exitDate": Timestamp(date: exitDate),
            "exitProof": (trade.exitProof == .priceChecked ? TradeProof.priceChecked : .selfReported).rawValue,
            "exitLoggedAt": FieldValue.serverTimestamp(),
            "proof": trade.proof.rawValue,
            "currentPrice": FieldValue.delete()
        ]
        data["notes"] = trade.notes.map { $0 as Any } ?? NSNull()
        try await db.collection("trades").document(trade.id).updateData(data)
    }
    
    func deleteTrade(tradeId: String) async throws {
        try await db.collection("trades").document(tradeId).delete()
    }

    /// The raw trade document, for copying a trade-result snapshot with the exact stored types.
    func getTradeData(tradeId: String) async throws -> [String: Any]? {
        try await db.collection("trades").document(tradeId).getDocument().data()
    }
    
    // Add this method to your FirebaseServices.swift file
    // This goes in the "Trade Management" section

    func getUserTradesSimple(userId: String) async throws -> [Trade] {
        print("🔍 FirebaseServices: Getting trades for user \(userId) with simple query")
        
        let snapshot = try await db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            // Remove the .order(by:) to avoid index requirement
            .getDocuments()
        
        let trades = snapshot.documents.compactMap { document in
            try? Trade.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        // Sort in memory instead of in the query
        let sortedTrades = trades.sorted { $0.entryDate > $1.entryDate }
        
        print("✅ FirebaseServices: Found \(sortedTrades.count) trades for user")
        return sortedTrades
    }
    
    func listenToUserTrades(userId: String, completion: @escaping ([Trade]) -> Void) {
        let listener = db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .order(by: "entryDate", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching trades: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let trades = documents.compactMap { document in
                    try? Trade.fromFirestore(data: document.data(), id: document.documentID)
                }
                
                completion(trades)
            }
        
        listeners.append(listener)
    }
    
    func getTradeById(tradeId: String) async throws -> Trade? {
        let document = try await db.collection("trades").document(tradeId).getDocument()
        guard let data = document.data() else { return nil }
        return try Trade.fromFirestore(data: data, id: tradeId)
    }
    
    func copyTrade(tradeId: String, userId: String) async throws {
        guard let originalTrade = try await getTradeById(tradeId: tradeId) else {
            throw FirestoreError.documentNotFound
        }
        
        var copiedTrade = Trade(
            ticker: originalTrade.ticker,
            tradeType: originalTrade.tradeType,
            entryPrice: originalTrade.entryPrice,
            quantity: originalTrade.quantity,
            userId: userId
        )
        
        copiedTrade.notes = originalTrade.notes
        copiedTrade.strategy = originalTrade.strategy
        
        try await addTrade(copiedTrade)
    }
    
    
    func searchTrades(query: String, limit: Int = 20) async throws -> [Trade] {
        guard !query.isEmpty else { return [] }
        
        let searchQuery = query.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Search by ticker symbol
        let snapshot = try await db.collection("trades")
            .whereField("ticker", isGreaterThanOrEqualTo: searchQuery)
            .whereField("ticker", isLessThan: searchQuery + "\u{f8ff}")
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Trade.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
}
