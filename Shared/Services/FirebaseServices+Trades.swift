// File: Shared/Services/FirebaseServices+Trades.swift
// trades/{id}. The rules let anyone but the owner read a trade only when isPublic == true, so every
// query for someone else's trades filters on it.

import Foundation
import FirebaseAuth
import FirebaseFirestore

extension FirebaseServices {
    // MARK: - Trade Management

    /// Creates the trade. `Trade.toFirestore()` adds `proof`, `entryProof` (the same value,
    /// immutable), `side`, `loggedAt` (server time) and, for a price-checked entry,
    /// `priceCheck { price, low, high, checkedAt }`.
    func addTrade(_ trade: Trade) async throws {
        try await db.collection("trades").document(trade.id).setData(trade.toFirestore())
    }

    /// Saves only the fields that may change after logging (firestore.rules lock ticker, tradeType,
    /// side, entryPrice, quantity, entryDate, proof, entryProof, loggedAt and priceCheck, and a
    /// closed trade's exit). Locked fields are never rewritten, so a Date round trip can't count as
    /// a change. Closing goes through `closeTrade`.
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
        try await db.collection("trades").document(trade.id).updateData(data)
    }

    /// Closes an open trade in one write: `isOpen: false`, `exitPrice`, `exitDate`, `exitProof`
    /// ("price_checked" only for an exit checked against the live price and dated now),
    /// `exitLoggedAt` (server time), `notes`, and deletes `currentPrice`.
    /// `proof` is never written here: closing doesn't change the trade's label.
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

    /// A user's trades, newest first. Your own: all of them. Anyone else's: public ones only
    /// (the rules refuse the query otherwise). Equality filters only, so no composite index.
    func getUserTradesSimple(userId: String) async throws -> [Trade] {
        var query: Query = db.collection("trades").whereField("userId", isEqualTo: userId)
        if userId != Auth.auth().currentUser?.uid {
            query = query.whereField("isPublic", isEqualTo: true)
        }
        let snapshot = try await query.getDocuments()
        return snapshot.documents
            .compactMap(Trade.from(document:))
            .sorted { $0.entryDate > $1.entryDate }
    }

    /// Live updates of the signed-in user's own trades, newest first. The caller owns the returned
    /// registration and must remove it (PortfolioViewModel keeps exactly one).
    /// Errors (permissions, offline with no cache) are passed on instead of being dropped.
    func listenToUserTrades(userId: String,
                            onChange: @escaping (Result<[Trade], Error>) -> Void) -> ListenerRegistration {
        db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .order(by: "entryDate", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    onChange(.failure(error ?? NSError(
                        domain: "Trades", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Couldn't load your trades."])))
                    return
                }
                onChange(.success(documents.compactMap(Trade.from(document:))))
            }
    }

    func getTradeById(tradeId: String) async throws -> Trade? {
        let document = try await db.collection("trades").document(tradeId).getDocument()
        return Trade.from(document: document)
    }

    /// Public trades whose ticker starts with `query`.
    /// Needs a composite index: trades (isPublic ASC, ticker ASC).
    func searchTrades(query: String, limit: Int = 20) async throws -> [Trade] {
        let searchQuery = query.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }

        let snapshot = try await db.collection("trades")
            .whereField("isPublic", isEqualTo: true)
            .whereField("ticker", isGreaterThanOrEqualTo: searchQuery)
            .whereField("ticker", isLessThan: searchQuery + "\u{f8ff}")
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap(Trade.from(document:))
    }
}
