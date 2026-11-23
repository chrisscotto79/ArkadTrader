// File: Core/Payments/PaymentsService.swift
// Paid communities (Stripe Connect): reads the server-written docs and calls the payment functions.
// See docs/backend-contracts.md, section 4. The app never writes any of these docs.

import Foundation
import FirebaseFirestore

// MARK: - Models

/// `stripeAccounts/{uid}`: the owner's Stripe Connect account
struct StripeAccountStatus: Sendable, Equatable {
    var accountId: String?
    var chargesEnabled = false
    var payoutsEnabled = false
    var detailsSubmitted = false
    var updatedAt: Date?

    enum Stage: Sendable, Equatable {
        case notStarted
        case inReview
        case ready
    }

    /// No account yet, or onboarding not finished: not started. Submitted but not approved: in review.
    var stage: Stage {
        if chargesEnabled { return .ready }
        if detailsSubmitted { return .inReview }
        return .notStarted
    }

    /// True once the person has started onboarding (an account exists)
    var hasAccount: Bool { accountId != nil }

    static let none = StripeAccountStatus()

    init() {}

    init(data: [String: Any]) {
        accountId = data["accountId"] as? String
        chargesEnabled = data["chargesEnabled"] as? Bool ?? false
        payoutsEnabled = data["payoutsEnabled"] as? Bool ?? false
        detailsSubmitted = data["detailsSubmitted"] as? Bool ?? false
        updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }
}

/// `communities/{cid}/private/revenue`
struct CommunityRevenue: Sendable, Equatable {
    var activeSubscribers = 0
    var trialingSubscribers = 0
    var mrr = 0.0
    var lifetimeGross = 0.0
    var lifetimeArkadFees = 0.0
    var lifetimeNet = 0.0
    var updatedAt: Date?

    init(data: [String: Any]) {
        activeSubscribers = (data["activeSubscribers"] as? NSNumber)?.intValue ?? 0
        trialingSubscribers = (data["trialingSubscribers"] as? NSNumber)?.intValue ?? 0
        mrr = (data["mrr"] as? NSNumber)?.doubleValue ?? 0
        lifetimeGross = (data["lifetimeGross"] as? NSNumber)?.doubleValue ?? 0
        lifetimeArkadFees = (data["lifetimeArkadFees"] as? NSNumber)?.doubleValue ?? 0
        lifetimeNet = (data["lifetimeNet"] as? NSNumber)?.doubleValue ?? 0
        updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }
}

/// The subscription fields on `communities/{cid}/members/{uid}`
struct MemberSubscription: Sendable, Equatable {
    enum Status: String, Sendable {
        case active
        case trialing
        case pastDue = "past_due"
        case canceled
    }

    var status: Status
    var currentPeriodEnd: Date?

    init?(data: [String: Any]) {
        guard let raw = data["subscriptionStatus"] as? String, let status = Status(rawValue: raw) else { return nil }
        self.status = status
        self.currentPeriodEnd = (data["currentPeriodEnd"] as? Timestamp)?.dateValue()
    }

    /// "Renews Mar 3", "Trial ends Mar 3", …
    var summary: String {
        let date = currentPeriodEnd.map { $0.formatted(.dateTime.month(.abbreviated).day()) }
        switch status {
        case .active:
            return date.map { "Subscribed · renews \($0)" } ?? "Subscribed"
        case .trialing:
            return date.map { "Free trial · ends \($0)" } ?? "Free trial"
        case .pastDue:
            return "Payment past due. Update your card in Manage subscription."
        case .canceled:
            return date.map { "Canceled · access until \($0)" } ?? "Canceled"
        }
    }
}

// MARK: - Service

enum PaymentsService {
    private static var db: Firestore { Firestore.firestore() }

    // MARK: Reads

    /// The current user's Stripe account, or `.none` if they haven't started payout setup.
    static func stripeAccount(userId: String) async throws -> StripeAccountStatus {
        let snapshot = try await db.collection("stripeAccounts").document(userId).getDocument()
        guard let data = snapshot.data() else { return .none }
        return StripeAccountStatus(data: data)
    }

    /// Revenue for a community the current user owns, or nil if nothing has been recorded yet.
    static func revenue(communityId: String) async throws -> CommunityRevenue? {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("private").document("revenue")
            .getDocument()
        guard let data = snapshot.data() else { return nil }
        return CommunityRevenue(data: data)
    }

    /// Waits for the webhook to create the member doc after checkout. Returns true once it exists.
    static func waitForMembership(communityId: String, userId: String, attempts: Int = 15) async -> Bool {
        let ref = db.collection("communities").document(communityId)
            .collection("members").document(userId)
        for attempt in 0..<attempts {
            if let snapshot = try? await ref.getDocument(source: .server), snapshot.exists {
                return true
            }
            if attempt < attempts - 1 {
                try? await Task.sleep(for: .seconds(2))
            }
        }
        return false
    }

    // MARK: Callable functions

    static func createConnectOnboardingLink() async throws -> URL {
        try await CloudFunctions.callForURL("createConnectOnboardingLink")
    }

    static func getConnectDashboardLink() async throws -> URL {
        try await CloudFunctions.callForURL("getConnectDashboardLink")
    }

    static func createCheckoutSession(communityId: String) async throws -> URL {
        try await CloudFunctions.callForURL("createCheckoutSession", data: ["communityId": communityId])
    }

    static func createBillingPortalSession() async throws -> URL {
        try await CloudFunctions.callForURL("createBillingPortalSession")
    }

    /// Makes a community free (`isPaid: false`) or paid at `priceMonthly` with a `trialDays` trial.
    static func setCommunityPrice(communityId: String, isPaid: Bool, priceMonthly: Double?, trialDays: Int) async throws {
        var data: [String: any Sendable] = [
            "communityId": communityId,
            "isPaid": isPaid
        ]
        if isPaid, let priceMonthly {
            data["priceMonthly"] = priceMonthly
            data["trialDays"] = trialDays
        }
        _ = try await CloudFunctions.call("setCommunityPrice", data: data, as: CloudOKResponse.self)
    }
}
