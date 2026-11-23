// File: Core/Watchlist/AddWatchlistSymbolSheet.swift
// Sheet for adding a symbol to the watchlist, with an asset-type picker.

import SwiftUI

struct AddWatchlistSymbolSheet: View {
    @ObservedObject private var store = WatchlistStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var assetType: TradeType
    @State private var symbolText: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool

    init(symbol: String = "", assetType: TradeType = .stock) {
        _symbolText = State(initialValue: symbol)
        _assetType = State(initialValue: assetType)
    }

    private var normalizedSymbol: String { WatchlistSymbol.normalize(symbolText) }

    private var canSave: Bool {
        WatchlistSymbol.isValid(normalizedSymbol) && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        Text("Type")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        SegmentedPicker(options: TradeType.allCases, selection: $assetType) { $0.displayName }
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        Text("Symbol")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField(placeholder, text: $symbolText)
                            .font(.title3.weight(.semibold))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($isFieldFocused)
                            .onSubmit { save() }
                            .padding(.horizontal, DS.Spacing.m)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                                    .fill(Color.surfaceRaised)
                            )
                        Text(hint)
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
                            Text(isSaving ? "Adding…" : "Add to watchlist")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                }
                .padding(DS.pageMargin)
            }
            .screenBackground()
            .navigationTitle("Add symbol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isFieldFocused = symbolText.isEmpty }
            .onChange(of: symbolText) { _, _ in errorMessage = nil }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var placeholder: String {
        switch assetType {
        case .stock: return "AAPL"
        case .option: return "SPY"
        case .crypto: return "BTC"
        case .forex: return "EURUSD"
        }
    }

    private var hint: String {
        switch assetType {
        case .stock: return "Enter a ticker. Stocks show a live price and the day's change."
        case .option: return "Enter the underlying ticker. Options don't show live prices yet."
        case .crypto: return "Enter a coin, like BTC or ETH. Crypto doesn't show live prices yet."
        case .forex: return "Enter a pair without the slash, like EURUSD. Forex doesn't show live prices yet."
        }
    }

    private func save() {
        guard canSave else {
            if !normalizedSymbol.isEmpty {
                errorMessage = WatchlistStore.WatchlistError.invalidSymbol.errorDescription
            }
            return
        }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await store.add(symbol: normalizedSymbol, assetType: assetType)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

#Preview {
    AddWatchlistSymbolSheet()
}
