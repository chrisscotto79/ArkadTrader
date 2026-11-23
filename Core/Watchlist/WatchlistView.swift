// File: Core/Watchlist/WatchlistView.swift
// The user's watchlist: symbols with the current price and day change (stocks), swipe to
// remove or set an alert, and a link to price alerts. Pushed from Discover; it has no
// NavigationStack of its own.

import SwiftUI

struct WatchlistView: View {
    @ObservedObject private var store = WatchlistStore.shared
    @State private var showAddSheet = false
    @State private var alertItem: WatchlistItem?
    @State private var actionError: String?
    @State private var showAlerts = false

    var body: some View {
        content
            .screenBackground()
            .navigationTitle("Watchlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add symbol")
                }
            }
            .task { await store.load() }
            .navigationDestination(isPresented: $showAlerts) {
                PriceAlertsView()
            }
            .sheet(isPresented: $showAddSheet) {
                AddWatchlistSymbolSheet()
            }
            .sheet(item: $alertItem) { item in
                PriceAlertSheet(item: item)
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )) {
                Button("OK", role: .cancel) { actionError = nil }
            } message: {
                Text(actionError ?? "")
            }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if !store.hasLoaded && store.loadError == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = store.loadError, store.items.isEmpty {
            ScrollView {
                EmptyStateView(
                    systemImage: "wifi.exclamationmark",
                    title: "Watchlist unavailable",
                    message: error,
                    actionTitle: "Try again"
                ) {
                    Task { await store.load() }
                }
            }
        } else if store.hasLoaded && store.items.isEmpty {
            ScrollView {
                VStack(spacing: DS.Spacing.l) {
                    EmptyStateView(
                        systemImage: "star",
                        title: "Your watchlist is empty",
                        message: "Add stocks, crypto or forex pairs to keep an eye on them and set price alerts.",
                        actionTitle: "Add a symbol"
                    ) {
                        showAddSheet = true
                    }
                    if !store.alerts.isEmpty {
                        alertsLink
                            .padding(.horizontal, DS.pageMargin)
                    }
                }
            }
            .refreshable { await store.load() }
        } else {
            list
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            Section {
                alertsLink
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(store.items) { item in
                    Button {
                        alertItem = item
                    } label: {
                        WatchlistRow(
                            item: item,
                            quote: store.quotes[item.symbol],
                            alertCount: store.activeAlerts(for: item.symbol).count,
                            isLoadingQuote: store.isLoadingQuotes
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.surface)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            remove(item)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        Button {
                            alertItem = item
                        } label: {
                            Label("Set alert", systemImage: "bell")
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button {
                            alertItem = item
                        } label: {
                            Label("Set alert", systemImage: "bell")
                        }
                        Button(role: .destructive) {
                            remove(item)
                        } label: {
                            Label("Remove from watchlist", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("\(store.items.count) symbol\(store.items.count == 1 ? "" : "s")")
            } footer: {
                Text(quotesFooter)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await store.load() }
    }

    private var quotesFooter: String {
        guard WatchlistQuotes.isConfigured else {
            return "Live prices aren't available right now. Swipe a row to set an alert or remove it."
        }
        if store.quotesUnavailable {
            return "Live prices are unavailable right now. Pull to refresh in a minute. Swipe a row to set an alert or remove it."
        }
        var text = "Prices are for stocks only, from Finnhub, and may be delayed. Swipe a row to set an alert or remove it."
        if let updated = store.lastQuoteUpdate {
            text += " Updated \(updated.formatted(date: .omitted, time: .shortened))."
        }
        return text
    }

    private var alertsLink: some View {
        Button {
            showAlerts = true
        } label: {
            HStack(spacing: DS.Spacing.m) {
                IconWell(systemName: "bell.badge.fill", tint: .orange, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Price alerts")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(alertsSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .cardStyle(padding: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private var alertsSummary: String {
        let active = store.activeAlerts.count
        let triggered = store.triggeredAlerts.count
        if active == 0 && triggered == 0 { return "Get notified when a price crosses your target" }
        var parts = ["\(active) of \(WatchlistStore.maxActiveAlerts) active"]
        if triggered > 0 { parts.append("\(triggered) triggered") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func remove(_ item: WatchlistItem) {
        Task {
            do {
                try await store.remove(item)
            } catch {
                actionError = "Couldn't remove \(item.symbol). \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Row

struct WatchlistRow: View {
    let item: WatchlistItem
    let quote: WatchlistQuote?
    var alertCount: Int = 0
    var isLoadingQuote = false

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: item.assetType.icon, tint: item.assetType.color, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.symbol)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    if alertCount > 0 {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("\(alertCount) active alert\(alertCount == 1 ? "" : "s")")
                    }
                }
                Text(item.assetType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: DS.Spacing.s)

            trailing
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var trailing: some View {
        if let quote {
            VStack(alignment: .trailing, spacing: 4) {
                Text(quote.price.formatted(.currency(code: "USD")))
                    .arkadNumber(16, weight: .semibold)
                    .foregroundStyle(Color.primary)
                if let percent = quote.changePercent {
                    ChangePill(
                        text: "\(percent >= 0 ? "+" : "")\(percent.formatted(.number.precision(.fractionLength(2))))%",
                        isPositive: percent >= 0
                    )
                }
            }
        } else if item.hasLiveQuote && isLoadingQuote {
            ProgressView().controlSize(.small)
        } else {
            Text(item.hasLiveQuote ? "No price" : "No live price")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    NavigationStack {
        WatchlistView()
    }
}
