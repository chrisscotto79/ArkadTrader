// File: Core/Brokerage/BrokerageService.swift
// Read-only brokerage linking through SnapTrade. The server writes connections, holdings and
// imported trades; the app reads them and calls the snaptrade* functions.
// See docs/backend-contracts.md, section 5.

import Foundation
import FirebaseFirestore

// MARK: - Models

/// `users/{uid}/brokerageConnections/{connectionId}`
struct BrokerageConnection: Identifiable, Sendable, Equatable {
    enum Status: String, Sendable {
        case connected
        case broken
    }

    let id: String
    var brokerageName: String
    var status: Status
    var createdAt: Date?
    var lastSyncAt: Date?

    init(id: String, data: [String: Any]) {
        self.id = id
        brokerageName = (data["brokerageName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Brokerage"
        status = Status(rawValue: data["status"] as? String ?? "") ?? .connected
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        lastSyncAt = (data["lastSyncAt"] as? Timestamp)?.dateValue()
    }
}

/// `users/{uid}/brokerageHoldings/{id}`
struct BrokerageHolding: Identifiable, Sendable, Equatable {
    let id: String
    var symbol: String
    var assetType: TradeType
    var quantity: Double
    var averagePrice: Double
    var currentPrice: Double
    var marketValue: Double
    var connectionId: String
    var brokerageName: String
    var updatedAt: Date?

    init(id: String, data: [String: Any]) {
        self.id = id
        symbol = (data["symbol"] as? String ?? "").uppercased()
        assetType = TradeType(rawValue: data["assetType"] as? String ?? "") ?? .stock
        quantity = (data["quantity"] as? NSNumber)?.doubleValue ?? 0
        averagePrice = (data["averagePrice"] as? NSNumber)?.doubleValue ?? 0
        currentPrice = (data["currentPrice"] as? NSNumber)?.doubleValue ?? 0
        marketValue = (data["marketValue"] as? NSNumber)?.doubleValue ?? currentPrice * quantity
        connectionId = data["connectionId"] as? String ?? ""
        brokerageName = data["brokerageName"] as? String ?? ""
        updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }

    var costBasis: Double { averagePrice * quantity }

    var unrealizedPL: Double { marketValue - costBasis }

    var unrealizedPLPercent: Double {
        costBasis > 0 ? unrealizedPL / costBasis * 100 : 0
    }

    /// True when the brokerage sent enough to show a gain or loss
    var hasCostBasis: Bool { averagePrice > 0 && quantity > 0 }
}

/// `{ importedTrades, holdings }` from snaptradeSync
struct BrokerageSyncResult: Decodable, Sendable {
    let importedTrades: Int?
    let holdings: Int?
}

// MARK: - Service

enum BrokerageService {
    private static var db: Firestore { Firestore.firestore() }

    static func connections(userId: String) async throws -> [BrokerageConnection] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("brokerageConnections")
            .getDocuments()
        return snapshot.documents
            .map { BrokerageConnection(id: $0.documentID, data: $0.data()) }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    static func holdings(userId: String) async throws -> [BrokerageHolding] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("brokerageHoldings")
            .getDocuments()
        return snapshot.documents
            .map { BrokerageHolding(id: $0.documentID, data: $0.data()) }
            .filter { !$0.symbol.isEmpty && $0.quantity != 0 }
            .sorted { $0.marketValue > $1.marketValue }
    }

    /// SnapTrade connection portal URL; it redirects to `arkad://brokerage/connected`
    static func connectLink() async throws -> URL {
        try await CloudFunctions.callForURL("snaptradeConnectLink")
    }

    /// Pulls holdings and trades from every connected brokerage
    static func sync() async throws -> BrokerageSyncResult {
        try await CloudFunctions.call("snaptradeSync", as: BrokerageSyncResult.self)
    }

    static func disconnect(connectionId: String) async throws {
        _ = try await CloudFunctions.call(
            "snaptradeDisconnect",
            data: ["connectionId": connectionId],
            as: CloudOKResponse.self
        )
    }
}
