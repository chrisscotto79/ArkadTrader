// File: Core/Communities/Views/Callouts/CalloutSheets.swift
// Forms for posting a trade callout and for tracking one in your portfolio.

import SwiftUI

// MARK: - Shared form pieces

/// Uppercase caption above a form card.
private struct CalloutFormLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .padding(.leading, DS.Spacing.xs)
    }
}

/// A labelled input row inside a form card: title on the left, field on the right.
private struct CalloutInputRow<Field: View>: View {
    let title: String
    @ViewBuilder var field: () -> Field

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            Text(title)
                .font(.body)
                .foregroundStyle(Color.primary)
            Spacer(minLength: DS.Spacing.s)
            field()
        }
        .padding(.horizontal, DS.Spacing.l)
        .frame(minHeight: 50)
    }
}

/// 1pt hairline between rows in a form card.
private struct CalloutRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(height: 1)
            .padding(.leading, DS.Spacing.l)
    }
}

/// A trailing, right-aligned decimal field with a "$" prefix.
private struct CalloutPriceField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 2) {
            Text("$").foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(maxWidth: 140)
        }
    }
}

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

    private var showsValidation: Bool { !entry.isEmpty || !ticker.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    tradeSection
                    levelsSection
                    notesSection
                    if let error = callout.validationError, showsValidation {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.marketRed)
                            .padding(.horizontal, DS.Spacing.xs)
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("New Callout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.goldText)
                }
            }
            .safeAreaInset(edge: .bottom) { postBar }
        }
    }

    // MARK: Sections

    private var tradeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            CalloutFormLabel(text: "Trade in #\(channelName)")
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                HStack(spacing: DS.Spacing.s) {
                    Text("$")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    TextField("Ticker", text: $ticker)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, DS.Spacing.l)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous).fill(Color.surfaceRaised)
                )

                SegmentedPicker(
                    options: TradeCallout.Direction.allCases,
                    selection: $direction,
                    title: { $0.displayName }
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.s) {
                        ForEach(TradeType.allCases, id: \.self) { type in
                            Chip(title: type.displayName, systemImage: type.icon, isSelected: assetType == type) {
                                withAnimation(.snappy(duration: 0.2)) { assetType = type }
                            }
                        }
                    }
                }
            }
            .cardStyle(padding: DS.Spacing.l)
        }
    }

    private var levelsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            CalloutFormLabel(text: "Levels")
            VStack(spacing: 0) {
                CalloutInputRow(title: "Entry") {
                    CalloutPriceField(placeholder: "0.00", text: $entry)
                }
                CalloutRowDivider()
                CalloutInputRow(title: "Stop loss") {
                    CalloutPriceField(placeholder: "Optional", text: $stop)
                }
                CalloutRowDivider()
                CalloutInputRow(title: "Target") {
                    CalloutPriceField(placeholder: "Optional", text: $target)
                }
                if let rr = callout.riskReward {
                    CalloutRowDivider()
                    CalloutInputRow(title: "Reward : Risk") {
                        Text(String(format: "%.2f", rr))
                            .arkadNumber(16)
                            .foregroundStyle(Color.goldText)
                    }
                }
            }
            .cardStyle(padding: 0)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            CalloutFormLabel(text: "Notes")
            TextField("Thesis, timeframe, sizing…", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .cardStyle(padding: DS.Spacing.l)
        }
    }

    private var postBar: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onPost(callout)
            dismiss()
        } label: {
            Label("Post callout", systemImage: "megaphone.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(callout.validationError != nil)
        .padding(.horizontal, DS.pageMargin)
        .padding(.top, DS.Spacing.s)
        .padding(.bottom, DS.Spacing.s)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
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
    private var canSave: Bool { entryValue > 0 && quantityValue > 0 && !isSaving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    summaryCard
                    fillSection
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.marketRed)
                            .padding(.horizontal, DS.Spacing.xs)
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Track Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.goldText)
                }
            }
            .safeAreaInset(edge: .bottom) { addBar }
        }
        .presentationDragIndicator(.visible)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.m) {
                IconWell(systemName: callout.direction.icon, tint: callout.direction.color, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("$\(callout.ticker)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Tag(text: callout.direction.displayName.uppercased(), tint: callout.direction.color)
                    }
                    Text("From \(communityName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: DS.Spacing.s) {
                levelPill(title: "Stop", price: callout.stopPrice, color: .marketRed)
                levelPill(title: "Target", price: callout.targetPrice, color: .marketGreen)
            }

            Text("The stop and target are saved with the trade.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle(padding: DS.Spacing.l)
    }

    private func levelPill(title: String, price: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(price.map(TradeCallout.formatPrice) ?? "—")
                .arkadNumber(15)
                .foregroundStyle(price == nil ? Color.secondary : color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous).fill(Color.surfaceRaised)
        )
    }

    private var fillSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            CalloutFormLabel(text: "Your fill")
            VStack(spacing: 0) {
                CalloutInputRow(title: "Entry price") {
                    CalloutPriceField(placeholder: "0.00", text: $entry)
                }
                CalloutRowDivider()
                CalloutInputRow(title: "Quantity") {
                    TextField("1", text: $quantity)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospacedDigit())
                        .frame(maxWidth: 140)
                }
                CalloutRowDivider()
                CalloutInputRow(title: "Position size") {
                    Text(TradeCallout.formatPrice(entryValue * quantityValue))
                        .arkadNumber(16)
                        .foregroundStyle(Color.primary)
                }
            }
            .cardStyle(padding: 0)

            if quantityValue > 0 {
                Text("\(quantityValue.quantityString) × \(TradeCallout.formatPrice(entryValue))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.leading, DS.Spacing.xs)
            }
        }
    }

    private var addBar: some View {
        Button(action: save) {
            if isSaving {
                ProgressView().tint(Color.onGold)
            } else {
                Label("Add to Portfolio", systemImage: "plus")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canSave)
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.s)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
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
