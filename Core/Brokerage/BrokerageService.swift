// File: Core/Brokerage/BrokerageService.swift
// Read-only brokerage linking through SnapTrade. The brokerage Worker (brokerage-worker/,
// a Cloudflare Worker on the free plan) writes connections, holdings and imported trades;
// the app reads them from Firestore and calls the Worker to connect, sync and disconnect.
// See docs/backend-contracts.md, section 5, and docs/brokerage-worker-setup.md.

import Foundation
import FirebaseAuth
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
    /// Totals across the connection's accounts as of the last sync. Nil before the first sync
    /// that recorded them.
    var cashBalance: Double?
    var holdingsValue: Double?
    var totalValue: Double?
    /// SnapTrade is still pulling this connection's data, so an empty account may not be empty yet
    var initialSyncPending: Bool
    /// One value per day (the Worker records one each sync), oldest first
    var valueHistory: [AccountValuePoint]

    init(id: String, data: [String: Any]) {
        self.id = id
        brokerageName = (data["brokerageName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Brokerage"
        status = Status(rawValue: data["status"] as? String ?? "") ?? .connected
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        lastSyncAt = (data["lastSyncAt"] as? Timestamp)?.dateValue()
        cashBalance = (data["cashBalance"] as? NSNumber)?.doubleValue
        holdingsValue = (data["holdingsValue"] as? NSNumber)?.doubleValue
        totalValue = (data["totalValue"] as? NSNumber)?.doubleValue
        initialSyncPending = data["initialSyncPending"] as? Bool ?? false
        valueHistory = (data["valueHistory"] as? [[String: Any]] ?? []).compactMap { entry in
            guard let day = entry["date"] as? String, let date = AccountValuePoint.date(fromDay: day),
                  let value = (entry["value"] as? NSNumber)?.doubleValue, value.isFinite else { return nil }
            return AccountValuePoint(date: date, value: value)
        }
        .sorted { $0.date < $1.date }
    }
}

/// An account value at a point in time, for the Portfolio chart
struct AccountValuePoint: Identifiable, Equatable, Sendable {
    let date: Date
    let value: Double
    var id: Date { date }

    /// "2026-11-23" (a UTC day, as the Worker writes it) as noon UTC, so it lands on the same
    /// calendar day in every US time zone
    static func date(fromDay day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}

/// What the linked brokerages add up to, for the Portfolio's account value
struct LinkedAccountSummary: Equatable {
    var totalValue: Double
    var cash: Double
    var names: [String]
    var lastSyncAt: Date?
    var syncPending: Bool
    /// Daily total across the linked brokerages, oldest first
    var history: [AccountValuePoint]

    /// Nil until at least one connection has synced its totals
    init?(connections: [BrokerageConnection]) {
        let synced = connections.filter { $0.totalValue != nil }
        guard !synced.isEmpty else { return nil }
        totalValue = synced.reduce(0) { $0 + ($1.totalValue ?? 0) }
        cash = synced.reduce(0) { $0 + ($1.cashBalance ?? 0) }
        names = synced.map(\.brokerageName)
        lastSyncAt = synced.compactMap(\.lastSyncAt).min()
        syncPending = connections.contains(where: \.initialSyncPending)
        history = Self.combinedHistory(synced.map(\.valueHistory))
    }

    /// Adds up several brokerages day by day. A brokerage with no value recorded on a day
    /// counts at its most recent earlier value (or nothing, before its first).
    private static func combinedHistory(_ histories: [[AccountValuePoint]]) -> [AccountValuePoint] {
        guard histories.count > 1 else { return histories.first ?? [] }
        let days = Set(histories.flatMap { $0.map(\.date) }).sorted()
        return days.map { day in
            let total = histories.reduce(0.0) { sum, history in
                sum + (history.last(where: { $0.date <= day })?.value ?? 0)
            }
            return AccountValuePoint(date: day, value: total)
        }
    }

    /// "Robinhood", "Robinhood and Coinbase", "3 brokerages"
    var title: String {
        switch names.count {
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return "\(names.count) brokerages"
        }
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
        let response = try await BrokerageAPI.post("connect", as: CloudLinkResponse.self)
        guard let url = URL(string: response.url), url.scheme == "https" else {
            throw BrokerageAPIError.invalidResponse
        }
        return url
    }

    /// Pulls holdings and trades from every connected brokerage
    static func sync() async throws -> BrokerageSyncResult {
        try await BrokerageAPI.post("sync", as: BrokerageSyncResult.self)
    }

    static func disconnect(connectionId: String) async throws {
        _ = try await BrokerageAPI.post("disconnect", body: ["connectionId": connectionId], as: CloudOKResponse.self)
    }

    /// Account deletion: removes the SnapTrade user, its connections and the brokerage docs
    /// the app can't delete itself. Does nothing when brokerage linking is off.
    static func deleteLinkedData() async throws {
        guard AppConfig.brokerageLinkingEnabled else { return }
        _ = try await BrokerageAPI.post("delete-user", as: CloudOKResponse.self)
    }
}

// MARK: - Worker client

/// An error from the brokerage Worker, with a message that's safe to show.
enum BrokerageAPIError: LocalizedError {
    case notConfigured
    case signedOut
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Brokerage linking isn't available yet. Try again later."
        case .signedOut: return "Sign in again to continue."
        case .server(let message): return message
        case .invalidResponse: return "Something went wrong. Try again."
        }
    }
}

/// POSTs JSON to the brokerage Worker with the user's Firebase ID token.
/// Errors come back as `{ error: { message } }`.
enum BrokerageAPI {
    private struct ErrorBody: Decodable {
        struct Detail: Decodable { let message: String? }
        let error: Detail?
    }

    static func post<Response: Decodable>(
        _ path: String,
        body: [String: String] = [:],
        as type: Response.Type = Response.self
    ) async throws -> Response {
        guard let base = AppConfig.brokerageWorkerURL else { throw BrokerageAPIError.notConfigured }
        guard let user = Auth.auth().currentUser else { throw BrokerageAPIError.signedOut }
        let token = try await user.getIDToken()

        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        // Syncing a long history can take a while
        request.timeoutInterval = path == "sync" ? 120 : 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if status == 401 { throw BrokerageAPIError.signedOut }
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error?.message
            if let message, !message.isEmpty { throw BrokerageAPIError.server(message) }
            // No message: nothing is deployed at that address
            throw BrokerageAPIError.notConfigured
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw BrokerageAPIError.invalidResponse
        }
    }
}
