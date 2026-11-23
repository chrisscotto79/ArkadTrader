// File: Core/Watchlist/PriceAlertChecker.swift
// Free mode (docs/backend-contracts.md, section 0): checks the signed-in user's active price
// alerts against Finnhub quotes while Arkad is open: on launch, on returning to the foreground,
// then every 5 minutes. With Cloud Functions deployed the server does this and the checker
// does nothing.
//
// When an alert triggers it:
// - sets `isActive = false`, `triggeredAt` and `triggeredPrice` on users/{uid}/priceAlerts/{id};
// - creates a `price_alert` inbox notification for the user (data: route "watchlist", symbol);
// - shows a local notification, if allowed, whose tap opens the watchlist.
//
// The app's scene-phase hook calls `start()` when the scene becomes active and `stop()` when
// it goes to the background.

import Foundation
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

@MainActor
final class PriceAlertChecker {
    static let shared = PriceAlertChecker()

    /// How often to check while the app is in the foreground
    static let checkInterval: Duration = .seconds(5 * 60)
    /// Checks closer together than this are skipped
    static let minimumGap: TimeInterval = 60

    private var loopTask: Task<Void, Never>?
    private var isChecking = false
    private var lastCheckAt: Date?

    private init() {}

    // MARK: - Foreground loop

    /// Checks now, then every 5 minutes until `stop()`. Safe to call repeatedly.
    func start() {
        guard !AppConfig.serverFunctionsEnabled else { return }
        if loopTask != nil {
            Task { await checkNow() }
            return
        }
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkNow()
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    /// Stops checking and forgets the last check. Call on sign-out.
    func reset() {
        stop()
        lastCheckAt = nil
    }

    // MARK: - Checking

    /// Checks every active stock alert once. Does nothing if a check ran in the last minute,
    /// unless `force` (a new alert was just saved). Quotes come from QuoteClient, which reuses
    /// prices up to 30 seconds old, so forcing doesn't spend extra Finnhub calls.
    func checkNow(force: Bool = false) async {
        guard !AppConfig.serverFunctionsEnabled,
              !isChecking,
              WatchlistQuotes.isConfigured,
              let userId = Auth.auth().currentUser?.uid else { return }
        if !force, let lastCheckAt, Date().timeIntervalSince(lastCheckAt) < Self.minimumGap { return }

        isChecking = true
        lastCheckAt = Date()
        defer { isChecking = false }

        let alertsRef = FirebaseServices.shared.db
            .collection("users").document(userId).collection("priceAlerts")
        guard let snapshot = try? await alertsRef.whereField("isActive", isEqualTo: true).getDocuments() else {
            return
        }
        let alerts = snapshot.documents
            .compactMap { WatchlistStore.alert(from: $0.documentID, data: $0.data()) }
            .filter { $0.isActive && $0.canTrigger }
        guard !alerts.isEmpty else { return }

        // One quote per symbol
        let quotes = await WatchlistQuotes.fetch(symbols: Set(alerts.map(\.symbol)))
        guard Auth.auth().currentUser?.uid == userId else { return }
        WatchlistStore.shared.mergeQuotes(quotes)

        for alert in alerts {
            guard let price = quotes[alert.symbol]?.price, alert.isMet(by: price) else { continue }
            await trigger(alert, price: price, userId: userId, reference: alertsRef.document(alert.id))
        }
    }

    private func trigger(_ alert: PriceAlert, price: Double, userId: String, reference: DocumentReference) async {
        let triggeredAt = Date()
        do {
            try await reference.updateData([
                "isActive": false,
                "triggeredAt": Timestamp(date: triggeredAt),
                "triggeredPrice": price
            ])
        } catch {
            // Not marked, so don't notify; the next check tries again.
            return
        }
        guard Auth.auth().currentUser?.uid == userId else { return }
        WatchlistStore.shared.markTriggered(alertId: alert.id, at: triggeredAt, price: price)

        let title = Self.title(for: alert)
        let body = Self.body(for: alert, price: price)
        let data = ["route": "watchlist", "symbol": alert.symbol]

        await FirebaseServices.shared.createNotification(
            to: userId,
            type: "price_alert",
            title: title,
            body: body,
            data: data
        )
        await showLocalNotification(id: alert.id, title: title, body: body, userInfo: data)
    }

    // MARK: - Local notification

    private func showLocalNotification(id: String, title: String, body: String, userInfo: [String: String]) async {
        let wantsPriceAlerts = FirebaseAuthService.shared.currentUser?
            .isNotificationEnabled(NotificationPreference.priceAlerts.rawValue) ?? true
        guard wantsPriceAlerts else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        // nil trigger: deliver now. AppDelegate shows it as a banner while the app is open
        // and routes the tap through DeepLink(payload:).
        let request = UNNotificationRequest(identifier: "price-alert-\(id)", content: content, trigger: nil)
        try? await center.add(request)
    }

    // MARK: - Text

    private static func title(for alert: PriceAlert) -> String {
        let target = alert.targetPrice.formatted(.currency(code: "USD"))
        switch alert.condition {
        case .above: return "\(alert.symbol) rose above \(target)"
        case .below: return "\(alert.symbol) fell below \(target)"
        }
    }

    private static func body(for alert: PriceAlert, price: Double) -> String {
        "\(alert.symbol) is at \(price.formatted(.currency(code: "USD"))). This alert is now off."
    }
}
