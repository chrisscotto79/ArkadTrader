// File: Core/Watchlist/PriceAlertSheet.swift
// "Set alert" for a watchlist symbol: above or below a target price.
// Creates users/{uid}/priceAlerts/{id}. In free mode PriceAlertChecker checks alerts while
// Arkad is open; with Cloud Functions deployed a server function checks them every few minutes
// and sends a push when one triggers.

import SwiftUI

struct PriceAlertSheet: View {
    let item: WatchlistItem
    @ObservedObject private var store = WatchlistStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var condition: PriceAlertCondition = .above
    @State private var priceText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var deletingId: String?
    @FocusState private var isFieldFocused: Bool

    private var quote: WatchlistQuote? { store.quotes[item.symbol] }
    private var existingAlerts: [PriceAlert] { store.activeAlerts(for: item.symbol) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    symbolHeader

                    if store.canCreateAlert {
                        form
                    } else {
                        limitReached
                    }

                    if !existingAlerts.isEmpty {
                        existingSection
                    }

                    howItWorks
                }
                .padding(DS.pageMargin)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Set alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if priceText.isEmpty, let quote {
                    priceText = quote.price.formatted(.number.precision(.fractionLength(2)).grouping(.never))
                }
            }
            .onChange(of: priceText) { _, _ in errorMessage = nil }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var symbolHeader: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: item.assetType.icon, tint: item.assetType.color, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.symbol)
                    .font(.title2.weight(.bold))
                Text(item.assetType.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let quote {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(quote.price.formatted(.currency(code: "USD")))
                        .arkadNumber(20)
                    Text("Current price")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text("Alert me when the price is")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                SegmentedPicker(options: PriceAlertCondition.allCases, selection: $condition) { $0.title }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text("Target price")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("$").foregroundStyle(.secondary)
                    TextField("0.00", text: $priceText)
                        .keyboardType(.decimalPad)
                        .focused($isFieldFocused)
                }
                .arkadNumber(22, weight: .semibold)
                .padding(.horizontal, DS.Spacing.m)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(Color.surfaceRaised)
                )
            }

            if let warning = noLiveQuoteWarning {
                Label(warning, systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let warning = alreadyCrossedWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.marketRed)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                save()
            } label: {
                HStack(spacing: DS.Spacing.s) {
                    if isSaving { ProgressView().tint(Color.onGold) }
                    Text(isSaving ? "Saving…" : saveTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(targetPrice == nil || isSaving)

            Text("\(store.activeAlerts.count) of \(WatchlistStore.maxActiveAlerts) active alerts used")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .cardStyle()
    }

    private var saveTitle: String {
        guard let targetPrice else { return "Create alert" }
        return "Alert me \(condition.title.lowercased()) \(targetPrice.formatted(.currency(code: "USD")))"
    }

    private var limitReached: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Label("Alert limit reached", systemImage: "bell.slash.fill")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Text("You can have up to \(WatchlistStore.maxActiveAlerts) active alerts. Delete one in Price alerts to add another.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Existing alerts for this symbol

    private var existingSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Active for \(item.symbol)", count: existingAlerts.count)
            VStack(spacing: 0) {
                ForEach(Array(existingAlerts.enumerated()), id: \.element.id) { index, alert in
                    if index > 0 {
                        Divider().overlay(Color.hairline).padding(.leading, DS.Spacing.l)
                    }
                    HStack(spacing: DS.Spacing.m) {
                        Image(systemName: alert.condition.systemImage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(alert.condition == .above ? Color.marketGreen : Color.marketRed)
                            .accessibilityHidden(true)
                        Text("\(alert.condition.title) \(alert.targetPrice.formatted(.currency(code: "USD")))")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        Spacer(minLength: 0)
                        if deletingId == alert.id {
                            ProgressView().controlSize(.small)
                        } else {
                            Button(role: .destructive) {
                                delete(alert)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.marketRed)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete alert")
                        }
                    }
                    .padding(.horizontal, DS.Spacing.l)
                    .frame(minHeight: 48)
                }
            }
            .cardStyle(padding: 0)
        }
    }

    // MARK: - How it works

    private var howItWorks: some View {
        Label {
            Text(howItWorksText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "clock.badge.checkmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var howItWorksText: String {
        if AppConfig.serverFunctionsEnabled {
            return "Alerts are checked every few minutes, while the market is open for stocks and around the clock for crypto, and arrive as notifications. Price can move past your target between checks. Turn on notifications for Arkad to get them."
        }
        return "Alerts are checked while Arkad is open: when you open it, and every 5 minutes after that. When one triggers it appears in your notifications, with a banner if you've turned notifications on. Price can move past your target between checks."
    }

    // MARK: - Logic

    /// Free mode checks alerts with stock quotes only.
    private var noLiveQuoteWarning: String? {
        guard !AppConfig.serverFunctionsEnabled, !item.hasLiveQuote else { return nil }
        return "Live prices are only available for stocks right now, so an alert on \(item.symbol) won't trigger yet."
    }

    private var targetPrice: Double? {
        let trimmed = priceText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        let value = formatter.number(from: trimmed)?.doubleValue
            ?? Double(trimmed.replacingOccurrences(of: ",", with: ""))
        guard let value, value > 0, value.isFinite else { return nil }
        return value
    }

    private var alreadyCrossedWarning: String? {
        guard let quote, let targetPrice else { return nil }
        switch condition {
        case .above where quote.price >= targetPrice:
            return "The price is already above this target, so the alert would trigger on the next check."
        case .below where quote.price <= targetPrice:
            return "The price is already below this target, so the alert would trigger on the next check."
        default:
            return nil
        }
    }

    private func save() {
        guard let targetPrice, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await store.createAlert(for: item, condition: condition, targetPrice: targetPrice)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
                if !AppConfig.serverFunctionsEnabled {
                    // Banners need permission; a first alert is the moment it clearly helps.
                    await PushNotificationManager.shared.requestAuthorizationIfNeeded()
                    await PriceAlertChecker.shared.checkNow()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func delete(_ alert: PriceAlert) {
        deletingId = alert.id
        Task {
            do {
                try await store.deleteAlert(alert)
            } catch {
                errorMessage = "Couldn't delete the alert. \(error.localizedDescription)"
            }
            deletingId = nil
        }
    }
}
