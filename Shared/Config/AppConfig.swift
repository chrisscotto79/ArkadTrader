// File: Shared/Config/AppConfig.swift
// Reads app secrets from App/Secrets.plist, which is kept out of git.
// Copy App/Secrets.example.plist to App/Secrets.plist and fill in your keys.

import Foundation

enum AppConfig {
    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            print("⚠️ AppConfig: Secrets.plist not found; API features that need keys are disabled")
            return [:]
        }
        return plist
    }()

    /// Finnhub API key for market news. Empty when not configured.
    static var finnhubAPIKey: String {
        secrets["FinnhubAPIKey"] as? String ?? ""
    }

    // MARK: - Free mode
    //
    // Arkad currently runs on Firebase's free (Spark) plan with no Cloud Functions or
    // Stripe. These switches turn the server-backed features back on once the backend in
    // functions/ is deployed (see docs/backend-setup.md).

    /// Paid communities, payouts, subscriptions and the revenue dashboard.
    static let paidCommunitiesEnabled = false

    /// The Cloudflare Worker that does read-only brokerage linking through SnapTrade
    /// (brokerage-worker/, docs/brokerage-worker-setup.md). Read from `BrokerageWorkerURL`
    /// in Secrets.plist, like `https://arkad-brokerage.<you>.workers.dev`. Nil when not set.
    static let brokerageWorkerURL: URL? = {
        let raw = (secrets["BrokerageWorkerURL"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), url.scheme == "https", url.host?.isEmpty == false,
              !raw.contains("YOUR_") else { return nil }
        return url
    }()

    /// Read-only brokerage linking (Robinhood, Coinbase and others through SnapTrade).
    /// On once `BrokerageWorkerURL` is set in Secrets.plist.
    static var brokerageLinkingEnabled: Bool { brokerageWorkerURL != nil }

    /// Cloud Functions are deployed. When false, the app does the work itself:
    /// it computes track records, creates inbox notifications, checks price alerts
    /// while open and cleans up on account deletion. There is no remote push.
    static let serverFunctionsEnabled = false

    /// Photos attached to posts and chat messages. They need Cloud Storage (Blaze plan).
    /// Profile and community photos work without it (stored in Firestore).
    static let mediaUploadsEnabled = false

    /// Arkad's cut of each paid community subscription, in percent. Must match
    /// `PLATFORM_FEE_PERCENT` in functions/src/config.ts.
    static let platformFeePercent = 10

    /// Web copies of the legal documents (Firebase Hosting). The app also shows them in-app.
    static let termsURL = URL(string: "https://arkad-ios-app.web.app/terms")!
    static let privacyURL = URL(string: "https://arkad-ios-app.web.app/privacy")!
}
