// File: Core/Brokerage/LinkedAccountsView.swift
// Linked brokerages (SnapTrade, read-only): connect a brokerage, sync, and disconnect.
// Push it inside a NavigationStack (Settings, Portfolio).

import SwiftUI

@MainActor
final class LinkedAccountsViewModel: ObservableObject {
    @Published private(set) var connections: [BrokerageConnection] = []
    @Published private(set) var hasLoaded = false
    @Published private(set) var loadFailed = false
    @Published private(set) var isConnecting = false
    @Published private(set) var isSyncing = false
    @Published private(set) var disconnectingId: String?
    @Published var message: String?
    @Published var errorMessage: String?

    private let webAuth = WebAuthSession()

    var isBusy: Bool { isConnecting || isSyncing || disconnectingId != nil }

    func load() async {
        guard let userId = FirebaseAuthService.shared.currentUser?.id else { return }
        do {
            connections = try await BrokerageService.connections(userId: userId)
            loadFailed = false
        } catch {
            loadFailed = true
        }
        hasLoaded = true
    }

    /// Opens the SnapTrade portal. After `arkad://brokerage/connected`, syncs right away.
    func connect() async {
        guard !isBusy else { return }
        isConnecting = true
        do {
            let url = try await BrokerageService.connectLink()
            let callback = try await webAuth.open(url)
            isConnecting = false
            if let callback, callback.isArkadCallback(host: "brokerage", path: "connected") {
                await sync()
            } else {
                await load()
            }
        } catch {
            isConnecting = false
            errorMessage = CloudFunctions.friendlyMessage(for: error, feature: .brokerage)
        }
    }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        do {
            let result = try await BrokerageService.sync()
            message = Self.syncSummary(result)
        } catch {
            errorMessage = CloudFunctions.friendlyMessage(for: error, feature: .brokerage)
        }
        isSyncing = false
        await load()
    }

    func disconnect(_ connection: BrokerageConnection) async {
        guard !isBusy else { return }
        disconnectingId = connection.id
        do {
            try await BrokerageService.disconnect(connectionId: connection.id)
            connections.removeAll { $0.id == connection.id }
        } catch {
            errorMessage = CloudFunctions.friendlyMessage(for: error, feature: .brokerage)
        }
        disconnectingId = nil
        await load()
    }

    private static func syncSummary(_ result: BrokerageSyncResult) -> String {
        let trades = result.importedTrades ?? 0
        let holdings = result.holdings ?? 0
        let tradeText = trades == 1 ? "1 new trade" : "\(trades) new trades"
        let holdingText = holdings == 1 ? "1 holding" : "\(holdings) holdings"
        return "Synced \(tradeText) and \(holdingText)."
    }
}

struct LinkedAccountsView: View {
    @StateObject private var viewModel = LinkedAccountsViewModel()
    @State private var connectionToDisconnect: BrokerageConnection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                readOnlyNote
                connectionsSection
                actions
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .screenBackground()
        .navigationTitle("Linked brokerages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .confirmationDialog(
            "Disconnect \(connectionToDisconnect?.brokerageName ?? "brokerage")?",
            isPresented: Binding(get: { connectionToDisconnect != nil }, set: { if !$0 { connectionToDisconnect = nil } }),
            titleVisibility: .visible,
            presenting: connectionToDisconnect
        ) { connection in
            Button("Disconnect", role: .destructive) {
                Task { await viewModel.disconnect(connection) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Arkad will stop syncing this account. You can connect it again any time.")
        }
        .alert(
            "Linked brokerages",
            isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(
            "Sync complete",
            isPresented: Binding(get: { viewModel.message != nil }, set: { if !$0 { viewModel.message = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.message ?? "")
        }
    }

    // MARK: - Note

    private var readOnlyNote: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            IconWell(systemName: "lock.shield.fill", tint: .marketGreen, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text("Read-only")
                    .font(.subheadline.weight(.semibold))
                Text("Arkad can see your holdings and trades. It can never place trades or move money.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    // MARK: - Connections

    @ViewBuilder
    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title: "Connected", count: viewModel.hasLoaded ? viewModel.connections.count : nil)

            if !viewModel.hasLoaded {
                HStack(spacing: DS.Spacing.m) {
                    ProgressView()
                    Text("Loading…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            } else if viewModel.loadFailed {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load your brokerages",
                    message: "Check your connection and pull to refresh."
                )
                .cardStyle(padding: 0)
            } else if viewModel.connections.isEmpty {
                EmptyStateView(
                    systemImage: "building.columns.fill",
                    title: "No brokerages linked",
                    message: "Connect a brokerage to import your trades and holdings. Imported trades are marked Verified."
                )
                .cardStyle(padding: 0)
            } else {
                CommunityCardList(items: viewModel.connections, dividerInset: 68) { connection in
                    connectionRow(connection)
                }
            }
        }
    }

    private func connectionRow(_ connection: BrokerageConnection) -> some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(
                systemName: connection.status == .broken ? "exclamationmark.triangle.fill" : "building.columns.fill",
                tint: connection.status == .broken ? .marketRed : .goldText,
                size: 40
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.brokerageName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(statusLine(connection))
                    .font(.caption)
                    .foregroundStyle(connection.status == .broken ? Color.marketRed : .secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: DS.Spacing.s)
            if viewModel.disconnectingId == connection.id {
                ProgressView()
            } else {
                Button("Disconnect") {
                    connectionToDisconnect = connection
                }
                .buttonStyle(PillButtonStyle(kind: .outline))
                .disabled(viewModel.isBusy)
                .accessibilityLabel("Disconnect \(connection.brokerageName)")
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
    }

    private func statusLine(_ connection: BrokerageConnection) -> String {
        if connection.status == .broken {
            return "Connection lost. Connect it again to keep syncing."
        }
        guard let lastSync = connection.lastSyncAt else { return "Not synced yet" }
        return "Last synced \(lastSync.formatted(.relative(presentation: .named)))"
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: DS.Spacing.m) {
            Button {
                Task { await viewModel.connect() }
            } label: {
                HStack(spacing: DS.Spacing.s) {
                    if viewModel.isConnecting {
                        ProgressView().tint(Color.onGold)
                    }
                    Text(viewModel.isConnecting ? "Opening…" : "Connect a brokerage")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.isBusy)

            if !viewModel.connections.isEmpty {
                Button {
                    Task { await viewModel.sync() }
                } label: {
                    HStack(spacing: DS.Spacing.s) {
                        if viewModel.isSyncing {
                            ProgressView()
                        }
                        Text(viewModel.isSyncing ? "Syncing…" : "Sync now")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(viewModel.isBusy)
            }

            Text("Brokerage linking is provided by SnapTrade.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    NavigationStack {
        LinkedAccountsView()
    }
}
