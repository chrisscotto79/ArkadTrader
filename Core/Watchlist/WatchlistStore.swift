// File: Core/Watchlist/WatchlistStore.swift
// The signed-in user's watchlist and price alerts, plus stock quotes for the list.
// Shared so Discover search results and the Watchlist screen agree on what's watched.
//
// Firestore (see docs/backend-contracts.md, section 6):
// - users/{uid}/watchlist/{symbol}: { symbol, assetType, addedAt }
// - users/{uid}/priceAlerts/{id}: { symbol, assetType, condition, targetPrice, isActive, createdAt, triggeredAt? }
// The app creates and deletes alerts; a scheduled function checks them and marks them triggered.

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class WatchlistStore: ObservableObject {
    static let shared = WatchlistStore()

    /// The server enforces the same limit.
    nonisolated static let maxActiveAlerts = 20

    @Published private(set) var items: [WatchlistItem] = []
    @Published private(set) var alerts: [PriceAlert] = []
    @Published private(set) var quotes: [String: WatchlistQuote] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var isLoadingQuotes = false
    @Published private(set) var lastQuoteUpdate: Date?
    /// Set when the list couldn't be loaded.
    @Published private(set) var loadError: String?

    private var loadedUserId: String?

    private init() {}

    // MARK: - Queries

    func contains(_ symbol: String) -> Bool {
        let normalized = WatchlistSymbol.normalize(symbol)
        return items.contains { $0.symbol == normalized }
    }

    var activeAlerts: [PriceAlert] {
        alerts.filter(\.isActive).sorted { $0.createdAt > $1.createdAt }
    }

    var triggeredAlerts: [PriceAlert] {
        alerts.filter { !$0.isActive }
            .sorted { ($0.triggeredAt ?? $0.createdAt) > ($1.triggeredAt ?? $1.createdAt) }
    }

    var canCreateAlert: Bool {
        activeAlerts.count < Self.maxActiveAlerts
    }

    func activeAlerts(for symbol: String) -> [PriceAlert] {
        activeAlerts.filter { $0.symbol == symbol }
    }

    // MARK: - Loading

    /// Loads the watchlist and alerts, then quotes. Call on appear and on pull to refresh.
    func load() async {
        guard let userId = currentUserId() else {
            loadError = WatchlistError.signedOut.errorDescription
            return
        }
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let userRef = userDocument(userId)
            let watchlistSnapshot = try await userRef.collection("watchlist").getDocuments()
            let alertsSnapshot = try await userRef.collection("priceAlerts").getDocuments()
            guard userId == loadedUserId else { return }

            items = watchlistSnapshot.documents
                .compactMap { Self.item(from: $0.documentID, data: $0.data()) }
                .sorted { $0.addedAt > $1.addedAt }
            alerts = alertsSnapshot.documents
                .compactMap { Self.alert(from: $0.documentID, data: $0.data()) }
            loadError = nil
            hasLoaded = true
        } catch {
            loadError = "Couldn't load your watchlist. Check your connection and try again."
            hasLoaded = true
            return
        }

        await refreshQuotes()
    }

    func refreshQuotes() async {
        let symbols = Set(items.filter(\.hasLiveQuote).map(\.symbol))
        guard !symbols.isEmpty, WatchlistQuotes.isConfigured else { return }
        isLoadingQuotes = true
        let fresh = await WatchlistQuotes.fetch(symbols: symbols)
        quotes.merge(fresh) { _, new in new }
        if !fresh.isEmpty { lastQuoteUpdate = Date() }
        isLoadingQuotes = false
    }

    private func reset(for userId: String?) {
        loadedUserId = userId
        items = []
        alerts = []
        quotes = [:]
        hasLoaded = false
        loadError = nil
        lastQuoteUpdate = nil
    }

    // MARK: - Watchlist

    enum WatchlistError: LocalizedError {
        case signedOut
        case invalidSymbol
        case alreadyWatching
        case alertLimitReached
        case invalidPrice

        var errorDescription: String? {
            switch self {
            case .signedOut: return "Sign in to use your watchlist."
            case .invalidSymbol: return "Enter a valid symbol, like AAPL, BTC or EURUSD."
            case .alreadyWatching: return "That symbol is already on your watchlist."
            case .alertLimitReached: return "You can have up to \(WatchlistStore.maxActiveAlerts) active alerts. Delete one to add another."
            case .invalidPrice: return "Enter a target price above zero."
            }
        }
    }

    func add(symbol rawSymbol: String, assetType: TradeType) async throws {
        guard let userId = currentUserId() else { throw WatchlistError.signedOut }
        let symbol = WatchlistSymbol.normalize(rawSymbol)
        guard WatchlistSymbol.isValid(symbol) else { throw WatchlistError.invalidSymbol }
        guard !contains(symbol) else { throw WatchlistError.alreadyWatching }

        let addedAt = Date()
        try await userDocument(userId).collection("watchlist").document(symbol).setData([
            "symbol": symbol,
            "assetType": assetType.rawValue,
            "addedAt": Timestamp(date: addedAt)
        ])

        guard userId == loadedUserId else { return }
        items.insert(WatchlistItem(symbol: symbol, assetType: assetType, addedAt: addedAt), at: 0)

        if assetType == .stock, WatchlistQuotes.isConfigured {
            let fresh = await WatchlistQuotes.fetch(symbols: [symbol])
            quotes.merge(fresh) { _, new in new }
        }
    }

    func remove(_ item: WatchlistItem) async throws {
        guard let userId = currentUserId() else { throw WatchlistError.signedOut }
        let previous = items
        items.removeAll { $0.symbol == item.symbol }
        do {
            try await userDocument(userId).collection("watchlist").document(item.symbol).delete()
            quotes[item.symbol] = nil
        } catch {
            items = previous
            throw error
        }
    }

    // MARK: - Alerts

    func createAlert(for item: WatchlistItem, condition: PriceAlertCondition, targetPrice: Double) async throws {
        guard let userId = currentUserId() else { throw WatchlistError.signedOut }
        guard targetPrice > 0, targetPrice.isFinite else { throw WatchlistError.invalidPrice }
        guard canCreateAlert else { throw WatchlistError.alertLimitReached }

        let reference = userDocument(userId).collection("priceAlerts").document()
        let createdAt = Date()
        try await reference.setData([
            "symbol": item.symbol,
            "assetType": item.assetType.rawValue,
            "condition": condition.rawValue,
            "targetPrice": targetPrice,
            "isActive": true,
            "createdAt": Timestamp(date: createdAt)
        ])

        alerts.append(PriceAlert(
            id: reference.documentID,
            symbol: item.symbol,
            assetType: item.assetType,
            condition: condition,
            targetPrice: targetPrice,
            isActive: true,
            createdAt: createdAt,
            triggeredAt: nil
        ))
    }

    func deleteAlert(_ alert: PriceAlert) async throws {
        guard let userId = currentUserId() else { throw WatchlistError.signedOut }
        let previous = alerts
        alerts.removeAll { $0.id == alert.id }
        do {
            try await userDocument(userId).collection("priceAlerts").document(alert.id).delete()
        } catch {
            alerts = previous
            throw error
        }
    }

    // MARK: - Helpers

    /// The signed-in user's id. Clears everything if a different user has signed in.
    private func currentUserId() -> String? {
        let userId = Auth.auth().currentUser?.uid
        if userId != loadedUserId { reset(for: userId) }
        return userId
    }

    private func userDocument(_ userId: String) -> DocumentReference {
        FirebaseServices.shared.db.collection("users").document(userId)
    }

    private static func item(from documentId: String, data: [String: Any]) -> WatchlistItem? {
        let symbol = (data["symbol"] as? String) ?? documentId
        guard !symbol.isEmpty else { return nil }
        let assetType = (data["assetType"] as? String).flatMap(TradeType.init(rawValue:)) ?? .stock
        let addedAt = (data["addedAt"] as? Timestamp)?.dateValue() ?? .distantPast
        return WatchlistItem(symbol: symbol, assetType: assetType, addedAt: addedAt)
    }

    private static func alert(from documentId: String, data: [String: Any]) -> PriceAlert? {
        guard let symbol = data["symbol"] as? String,
              let conditionRaw = data["condition"] as? String,
              let condition = PriceAlertCondition(rawValue: conditionRaw),
              let targetPrice = (data["targetPrice"] as? NSNumber)?.doubleValue else { return nil }
        return PriceAlert(
            id: documentId,
            symbol: symbol,
            assetType: (data["assetType"] as? String).flatMap(TradeType.init(rawValue:)) ?? .stock,
            condition: condition,
            targetPrice: targetPrice,
            isActive: data["isActive"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast,
            triggeredAt: (data["triggeredAt"] as? Timestamp)?.dateValue()
        )
    }
}
