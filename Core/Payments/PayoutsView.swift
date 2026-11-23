// File: Core/Payments/PayoutsView.swift
// Payout setup for community owners (Stripe Connect Express). Reads stripeAccounts/{uid};
// the buttons call createConnectOnboardingLink and getConnectDashboardLink.
// Push it inside a NavigationStack (Settings) or wrap it in one when presenting it as a sheet.

import SwiftUI

@MainActor
final class PayoutsViewModel: ObservableObject {
    @Published private(set) var status: StripeAccountStatus?
    @Published private(set) var isLoading = false
    @Published private(set) var isOpeningLink = false
    @Published var errorMessage: String?

    private let webAuth = WebAuthSession()

    func load() async {
        guard let userId = FirebaseAuthService.shared.currentUser?.id else {
            errorMessage = "Sign in to set up payouts."
            return
        }
        isLoading = true
        do {
            status = try await PaymentsService.stripeAccount(userId: userId)
        } catch {
            errorMessage = "Couldn't load your payout status. Pull to refresh."
        }
        isLoading = false
    }

    func startOnboarding() async {
        await openLink { try await PaymentsService.createConnectOnboardingLink() }
    }

    func openDashboard() async {
        await openLink { try await PaymentsService.getConnectDashboardLink() }
    }

    /// Opens a Stripe page, then reloads the status when the person comes back
    private func openLink(_ makeURL: () async throws -> URL) async {
        guard !isOpeningLink else { return }
        isOpeningLink = true
        defer { isOpeningLink = false }
        do {
            let url = try await makeURL()
            _ = try await webAuth.open(url)
        } catch {
            errorMessage = CloudFunctions.friendlyMessage(for: error)
        }
        await load()
    }
}

struct PayoutsView: View {
    @StateObject private var viewModel = PayoutsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                statusCard
                actions
                feeCard
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .screenBackground()
        .navigationTitle("Payouts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.load() }
            }
        }
        .alert(
            "Payouts",
            isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Status

    private var statusCard: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            IconWell(systemName: statusIcon, tint: statusTint, size: 44)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .redacted(reason: viewModel.status == nil && viewModel.isLoading ? .placeholder : [])
    }

    private var stage: StripeAccountStatus.Stage? { viewModel.status?.stage }

    private var statusTitle: String {
        switch stage {
        case .ready: return "Ready for payments"
        case .inReview: return "In review"
        case .notStarted: return viewModel.status?.hasAccount == true ? "Setup not finished" : "Not set up"
        case nil: return "Checking status"
        }
    }

    private var statusMessage: String {
        switch stage {
        case .ready:
            return viewModel.status?.payoutsEnabled == true
                ? "You can run paid communities. Stripe sends your earnings to your bank."
                : "You can run paid communities. Stripe is still enabling payouts to your bank."
        case .inReview:
            return "Stripe is checking your details. This usually takes a few minutes, sometimes a day or two."
        case .notStarted:
            return "Set up payouts with Stripe to charge for your community. It takes a few minutes."
        case nil:
            return "Loading your payout status…"
        }
    }

    private var statusIcon: String {
        switch stage {
        case .ready: return "checkmark.seal.fill"
        case .inReview: return "hourglass"
        case .notStarted, nil: return "banknote"
        }
    }

    private var statusTint: Color {
        switch stage {
        case .ready: return .marketGreen
        case .inReview: return .warning
        case .notStarted, nil: return .goldText
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: DS.Spacing.m) {
            if stage != .ready {
                Button {
                    Task { await viewModel.startOnboarding() }
                } label: {
                    HStack(spacing: DS.Spacing.s) {
                        if viewModel.isOpeningLink {
                            ProgressView().tint(Color.onGold)
                        }
                        Text(onboardingTitle)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isOpeningLink || viewModel.status == nil)
            }

            if viewModel.status?.hasAccount == true {
                Button {
                    Task { await viewModel.openDashboard() }
                } label: {
                    Label("Open Stripe dashboard", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(viewModel.isOpeningLink)
            }
        }
    }

    private var onboardingTitle: String {
        switch stage {
        case .inReview: return "Update details"
        case .notStarted where viewModel.status?.hasAccount == true: return "Continue setup"
        default: return "Set up payouts"
        }
    }

    // MARK: - Fees

    private var feeCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Text("How fees work")
                .font(.headline)
            feeRow(icon: "person.2.fill", text: "Members pay your monthly price through Stripe.")
            feeRow(icon: "percent", text: "Arkad keeps \(CommunityPricing.feePercentText) of each payment. The rest goes to you.")
            feeRow(icon: "creditcard.fill", text: CommunityPricing.processingFeeNote)
            feeRow(icon: "building.columns.fill", text: "Stripe pays out to your bank. Arkad never sees your bank details.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func feeRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.goldText)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// PayoutsView in its own NavigationStack with a Done button, for presenting as a sheet
struct PayoutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PayoutsView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.goldText)
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        PayoutsView()
    }
}
