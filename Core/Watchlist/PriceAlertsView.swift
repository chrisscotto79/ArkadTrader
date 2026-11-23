// File: Core/Watchlist/PriceAlertsView.swift
// Active and triggered price alerts. Swipe to delete. Alerts are created from a watchlist row.

import SwiftUI

struct PriceAlertsView: View {
    @ObservedObject private var store = WatchlistStore.shared
    @State private var actionError: String?

    var body: some View {
        content
            .screenBackground()
            .navigationTitle("Price alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .task { await store.load() }
            .alert("Couldn't delete alert", isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )) {
                Button("OK", role: .cancel) { actionError = nil }
            } message: {
                Text(actionError ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if !store.hasLoaded && store.loadError == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = store.loadError, store.alerts.isEmpty {
            ScrollView {
                EmptyStateView(
                    systemImage: "wifi.exclamationmark",
                    title: "Alerts unavailable",
                    message: error,
                    actionTitle: "Try again"
                ) {
                    Task { await store.load() }
                }
            }
        } else if store.alerts.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    EmptyStateView(
                        systemImage: "bell",
                        title: "No price alerts",
                        message: "Open your watchlist and tap a symbol to get notified when its price crosses a target."
                    )
                    infoNote
                        .padding(.horizontal, DS.pageMargin)
                }
            }
            .refreshable { await store.load() }
        } else {
            list
        }
    }

    private var list: some View {
        List {
            Section {
                if store.activeAlerts.isEmpty {
                    Text("No active alerts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.surface)
                } else {
                    ForEach(store.activeAlerts) { alert in
                        alertRow(alert)
                    }
                }
            } header: {
                Text("Active · \(store.activeAlerts.count) of \(WatchlistStore.maxActiveAlerts)")
            } footer: {
                if !store.canCreateAlert {
                    Text("You've reached the limit of \(WatchlistStore.maxActiveAlerts) active alerts. Delete one to add another.")
                }
            }

            if !store.triggeredAlerts.isEmpty {
                Section("Triggered") {
                    ForEach(store.triggeredAlerts) { alert in
                        alertRow(alert)
                    }
                }
            }

            Section {
                infoNote
                    .listRowInsets(EdgeInsets(top: DS.Spacing.s, leading: 0, bottom: DS.Spacing.s, trailing: 0))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await store.load() }
    }

    private func alertRow(_ alert: PriceAlert) -> some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(
                systemName: alert.isActive ? "bell.fill" : "bell.badge.fill",
                tint: alert.isActive ? .orange : .secondary,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(alert.symbol)
                        .font(.headline)
                    Image(systemName: alert.condition.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(alert.condition == .above ? Color.marketGreen : Color.marketRed)
                        .accessibilityHidden(true)
                    Text("\(alert.condition.title) \(alert.targetPrice.formatted(.currency(code: "USD")))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                Text(caption(for: alert))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .listRowBackground(Color.surface)
        .accessibilityElement(children: .combine)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(alert)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                delete(alert)
            } label: {
                Label("Delete alert", systemImage: "trash")
            }
        }
    }

    private func caption(for alert: PriceAlert) -> String {
        if alert.isActive {
            if let quote = store.quotes[alert.symbol] {
                return "Now \(quote.price.formatted(.currency(code: "USD"))) · \(alert.assetType.displayName)"
            }
            return "Waiting · \(alert.assetType.displayName)"
        }
        if let triggeredAt = alert.triggeredAt {
            return "Triggered \(triggeredAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return "No longer active"
    }

    private var infoNote: some View {
        Label {
            Text("Alerts are checked every few minutes, while the market is open for stocks and around the clock for crypto, and arrive as notifications. Price can move past your target between checks.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "clock.badge.checkmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func delete(_ alert: PriceAlert) {
        Task {
            do {
                try await store.deleteAlert(alert)
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        PriceAlertsView()
    }
}
