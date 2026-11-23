// File: Core/Payments/CommunitySubscriptionController.swift
// Subscribing to a paid community (Stripe Checkout) and managing the subscription (billing portal).
// Joining a paid community only happens through checkout; the webhook creates the member doc.

import Foundation

@MainActor
final class CommunitySubscriptionController: ObservableObject {
    enum Phase: Equatable {
        case idle
        case openingCheckout
        /// Back from checkout, waiting for the webhook to add the membership
        case confirming
        /// Membership is in place
        case joined
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isOpeningPortal = false
    @Published var errorMessage: String?
    /// Shown when checkout succeeded but the membership hasn't appeared yet
    @Published var pendingMessage: String?

    private let webAuth = WebAuthSession()

    var isBusy: Bool { phase == .openingCheckout || phase == .confirming }

    /// Opens Stripe Checkout. On `arkad://checkout/success` it waits briefly for the member doc.
    /// Cancelling checkout does nothing.
    func subscribe(to community: Community) async {
        guard !isBusy else { return }
        guard let userId = FirebaseAuthService.shared.currentUser?.id else {
            errorMessage = "Sign in to subscribe."
            return
        }

        phase = .openingCheckout
        do {
            if try await FirebaseServices.shared.isUserBanned(communityId: community.id, userId: userId) {
                errorMessage = CommunityJoinError.banned.errorDescription
                phase = .idle
                return
            }

            let url = try await PaymentsService.createCheckoutSession(communityId: community.id)
            let callback = try await webAuth.open(url)

            guard let callback, callback.isArkadCallback(host: "checkout", path: "success") else {
                phase = .idle
                return
            }

            phase = .confirming
            let joined = await PaymentsService.waitForMembership(communityId: community.id, userId: userId)
            if joined {
                phase = .joined
            } else {
                phase = .idle
                pendingMessage = "Your payment went through. Your membership can take a minute to show up. Pull to refresh in a moment."
            }
        } catch {
            phase = .idle
            errorMessage = CloudFunctions.friendlyMessage(for: error)
        }
    }

    /// Opens Stripe's billing portal so a subscriber can update their card or cancel.
    /// Returns when the person comes back (`arkad://billing/done`) or closes the page.
    func manageSubscription() async {
        guard !isOpeningPortal else { return }
        isOpeningPortal = true
        defer { isOpeningPortal = false }
        do {
            let url = try await PaymentsService.createBillingPortalSession()
            _ = try await webAuth.open(url)
        } catch {
            errorMessage = CloudFunctions.friendlyMessage(for: error)
        }
    }

    /// Clears a finished subscribe so the welcome isn't shown twice
    func acknowledgeJoined() {
        if phase == .joined { phase = .idle }
    }
}
