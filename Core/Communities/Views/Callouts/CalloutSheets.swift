// File: Core/Communities/Views/Callouts/CalloutSheets.swift
// Forms for posting a trade callout and for tracking one in your portfolio.

import SwiftUI

// MARK: - Create Callout

struct CreateCalloutSheet: View {
    let channelName: String
    let onPost: (TradeCallout) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ticker = ""
    @State private var assetType: TradeType = .stock
    @State private var direction: TradeCallout.Direction = .long
    @State private var entry = ""
    @State private var stop = ""
    @State private var target = ""
    @State private var note = ""

    private var callout: TradeCallout {
        TradeCallout(
            ticker: ticker.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: "$", with: ""),
            assetType: assetType,
            direction: direction,
            entryPrice: Double(entry) ?? 0,
            stopPrice: Double(stop),
            targetPrice: Double(target),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ticker (e.g. AAPL)", text: $ticker)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Picker("Asset", selection: $assetType) {
                        ForEach(TradeType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Picker("Direction", selection: $direction) {
                        ForEach(TradeCallout.Direction.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Levels") {
                    priceField("Entry price", text: $entry)
                    priceField("Stop loss (optional)", text: $stop)
                    priceField("Target (optional)", text: $target)
                    if let rr = callout.riskReward {
                        LabeledContent("Reward : Risk", value: String(format: "%.2f", rr))
                            .foregroundColor(.arkadGold)
                    }
                }

                Section("Notes") {
                    TextField("Thesis, timeframe, sizing…", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = callout.validationError, !entry.isEmpty || !ticker.isEmpty {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("New Callout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        onPost(callout)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(callout.validationError != nil)
                }
            }
        }
    }

    private func priceField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text("$").foregroundColor(.secondary)
            TextField(title, text: text)
                .keyboardType(.decimalPad)
        }
    }
}

// MARK: - Track Callout in Portfolio

struct TrackCalloutSheet: View {
    let callout: TradeCallout
    let communityName: String
    let onTrack: (_ entryPrice: Double, _ quantity: Double) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entry: String
    @State private var quantity = "1"
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(callout: TradeCallout, communityName: String, onTrack: @escaping (Double, Double) async throws -> Void) {
        self.callout = callout
        self.communityName = communityName
        self.onTrack = onTrack
        _entry = State(initialValue: String(format: "%.2f", callout.entryPrice))
    }

    private var entryValue: Double { Double(entry) ?? 0 }
    private var quantityValue: Double { Double(quantity.replacingOccurrences(of: ",", with: "")) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Ticker", value: "$\(callout.ticker)")
                    LabeledContent("Direction", value: callout.direction.displayName)
                    if let stop = callout.stopPrice { LabeledContent("Stop", value: stop.asCurrency) }
                    if let target = callout.targetPrice { LabeledContent("Target", value: target.asCurrency) }
                } footer: {
                    Text("From a callout in \(communityName). The stop and target are saved with the trade.")
                }

                Section("Your fill") {
                    HStack {
                        Text("Entry price")
                        Spacer()
                        TextField("0.00", text: $entry)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("1", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Position size", value: (entryValue * quantityValue).asCurrency)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundColor(.marketRed)
                    }
                }
            }
            .navigationTitle("Track Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Add") { save() }
                            .fontWeight(.semibold)
                            .disabled(entryValue <= 0 || quantityValue <= 0)
                    }
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await onTrack(entryValue, quantityValue)
                dismiss()
            } catch {
                errorMessage = "Couldn't add the trade: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}
