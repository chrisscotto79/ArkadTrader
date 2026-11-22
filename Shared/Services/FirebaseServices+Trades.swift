// File: Shared/Services/FirebaseServices+Trades.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

extension FirebaseServices {
    // MARK: - Trade Management
    
    func addTrade(_ trade: Trade) async throws {
        try await db.collection("trades").document(trade.id).setData(trade.toFirestore())
    }
    
    func updateTrade(_ trade: Trade) async throws {
        try await db.collection("trades").document(trade.id).setData(trade.toFirestore(), merge: true)
    }
    
    func deleteTrade(tradeId: String) async throws {
        try await db.collection("trades").document(tradeId).delete()
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
