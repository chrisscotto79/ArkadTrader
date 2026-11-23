// File: Core/Communities/Views/Callouts/CalloutSheets.swift
// Forms for posting a trade callout, tracking one in your portfolio, and closing your own.

import SwiftUI

// MARK: - Shared form pieces (also used by CalloutUpdateSheets.swift)

/// Uppercase caption above a form card.
struct CalloutFormLabel: View {
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
struct CalloutInputRow<Field: View>: View {
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
struct CalloutRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(height: 1)
            .padding(.leading, DS.Spacing.l)
    }
}

/// A trailing, right-aligned decimal field with a "$" prefix.
struct CalloutPriceField: View {
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
    @State private var liveQuote: LiveQuote = .idle
    /// The entry the form filled in from the live price, so a newer quote can replace it
    /// unless the author typed their own.
    @State private var autoFilledEntry: String?

    /// The live price the entry is checked against (anti-fake, docs/backend-contracts.md).
    private enum LiveQuote: Equatable {
        case idle
        case loading
        case live(Double)
        case unavailable
    }

    private var normalizedTicker: String {
        ticker.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: "$", with: "")
    }

    private var livePrice: Double? {
        if case .live(let price) = liveQuote { return price }
        return nil
    }

    private var callout: TradeCallout {
        var callout = TradeCallout(
            ticker: normalizedTicker,
            assetType: assetType,
            direction: direction,
            entryPrice: TradeCallout.parsePrice(entry) ?? 0,
            stopPrice: TradeCallout.parsePrice(stop),
            targetPrice: TradeCallout.parsePrice(target),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if let livePrice {
            callout.priceCheck = .live
            callout.quoteAtPost = livePrice
        } else {
            callout.priceCheck = .unchecked
        }
        return callout
    }

    /// The form's blocking problem, if any: the levels first, then the entry's distance from the live price.
    private var validationError: String? {
        if let error = callout.validationError { return error }
        if !stop.isEmpty, TradeCallout.parsePrice(stop) == nil { return "Enter a valid stop price" }
        if !target.isEmpty, TradeCallout.parsePrice(target) == nil { return "Enter a valid target price" }
        if let livePrice, let entryValue = TradeCallout.parsePrice(entry) {
            return TradeCallout.entryCheckError(entry: entryValue, livePrice: livePrice, direction: direction)
        }
        return nil
    }

    private var canPost: Bool { validationError == nil && liveQuote != .loading }

    private var showsValidation: Bool { !entry.isEmpty || !ticker.isEmpty }

    private var quoteKey: String { "\(normalizedTicker)|\(assetType.rawValue)" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    tradeSection
                    levelsSection
                    notesSection
                    if let error = validationError, showsValidation {
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
            .task(id: quoteKey) { await loadLiveQuote() }
        }
    }

    // MARK: Live price

    /// Fetches the current price once the ticker settles. Without one the callout can still
    /// be posted, marked as not price-checked (it won't count toward the track record).
    private func loadLiveQuote() async {
        let symbol = WatchlistSymbol.normalize(normalizedTicker)
        guard !symbol.isEmpty, CalloutQuotes.canQuote(assetType: assetType) else {
            liveQuote = symbol.isEmpty ? .idle : .unavailable
            return
        }
        liveQuote = .loading
        try? await Task.sleep(for: .milliseconds(600))  // wait for typing to stop
        guard !Task.isCancelled else { return }
        let quote = await CalloutQuotes.shared.postingQuote(for: symbol)
        guard !Task.isCancelled else { return }
        liveQuote = quote.map { LiveQuote.live($0.price) } ?? LiveQuote.unavailable
        // Start the entry at the live price, unless the author already typed one.
        if let price = quote?.price, entry.isEmpty || entry == autoFilledEntry {
            let text = TradeCallout.editablePrice(price)
            entry = text
            autoFilledEntry = text
        }
    }

    @ViewBuilder
    private var livePriceRow: some View {
        switch liveQuote {
        case .idle:
            EmptyView()
        case .loading:
            CalloutRowDivider()
            HStack(spacing: DS.Spacing.s) {
                ProgressView()
                Text("Checking the current price…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.l)
            .frame(minHeight: 50)
        case .live(let price):
            CalloutRowDivider()
            Button {
                entry = TradeCallout.editablePrice(price)
                autoFilledEntry = entry
            } label: {
                HStack {
                    Text("Use current price")
                        .foregroundStyle(Color.goldText)
                    Spacer(minLength: DS.Spacing.s)
                    Text(TradeCallout.formatPrice(price))
                        .arkadNumber(15, weight: .semibold)
                        .foregroundStyle(Color.primary)
                }
                .padding(.horizontal, DS.Spacing.l)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
        case .unavailable:
            CalloutRowDivider()
            Label("\(assetType == .option ? "Option premiums can't be checked against a live price." : "No live price for this ticker.") The callout will be marked as not price-checked and won't count toward your record.",
                  systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.m)
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
                livePriceRow
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
            guard canPost else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onPost(callout)
            dismiss()
        } label: {
            Label("Post callout", systemImage: "megaphone.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canPost)
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
        _entry = State(initialValue: TradeCallout.editablePrice(callout.entryPrice))
    }

    private var entryValue: Double { TradeCallout.parsePrice(entry) ?? 0 }
    private var quantityValue: Double { AssetTerms.parseNumber(quantity).flatMap { $0.isFinite ? $0 : nil } ?? 0 }
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

// MARK: - Close Callout

/// The author closes an open callout at an exit price. The result counts toward their record.
/// With a live quote the exit must pass TradeCallout.exitCheckError (at most 0.25% better than
/// the quote, at most 2% worse); without one the author can close at any price, but the close is
/// marked `exitCheck: "unchecked"` and doesn't count toward the record.
struct CloseCalloutSheet: View {
    let callout: TradeCallout
    let onClose: (_ exitPrice: Double, _ exitCheck: TradeCallout.PriceCheck) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var exitText: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var liveQuote: LiveQuote = .loading
    /// The prefilled exit, replaced by the live price when it arrives (unless the author typed one)
    private let initialExitText: String

    private enum LiveQuote: Equatable {
        case loading
        case live(Double)
        case unavailable
    }

    init(callout: TradeCallout, onClose: @escaping (Double, TradeCallout.PriceCheck) async throws -> Void) {
        self.callout = callout
        self.onClose = onClose
        let initial = callout.lastPrice.map(TradeCallout.editablePrice) ?? ""
        self.initialExitText = initial
        _exitText = State(initialValue: initial)
    }

    private var livePrice: Double? {
        if case .live(let price) = liveQuote { return price }
        return nil
    }

    private var exitCheck: TradeCallout.PriceCheck { livePrice == nil ? .unchecked : .live }

    /// Blocks closing when the exit is too far from the live price.
    private var exitError: String? {
        guard let livePrice, let exitValue else { return nil }
        return TradeCallout.exitCheckError(exit: exitValue, livePrice: livePrice, direction: callout.direction)
    }

    private func loadLiveQuote() async {
        guard CalloutQuotes.canQuote(callout) else {
            liveQuote = .unavailable
            return
        }
        let quote = await CalloutQuotes.shared.postingQuote(for: CalloutQuotes.symbol(for: callout))
        guard !Task.isCancelled else { return }
        if let quote {
            liveQuote = .live(quote.price)
            if exitText == initialExitText { exitText = TradeCallout.editablePrice(quote.price) }
        } else {
            liveQuote = .unavailable
        }
    }

    /// Accepts "182.4", "$182.40", and "182,4" where the decimal separator is a comma.
    private var exitValue: Double? {
        guard let value = TradeCallout.parsePrice(exitText), value > 0 else { return nil }
        return value
    }

    private var resultPercent: Double? {
        exitValue.map { CalloutTrackingService.resultPercent(for: callout, exitPrice: $0) }
    }

    private var canSave: Bool { exitValue != nil && exitError == nil && liveQuote != .loading && !isSaving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    summaryCard
                    exitSection
                    resultCard
                    if let exitError {
                        Label(exitError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.marketRed)
                            .padding(.horizontal, DS.Spacing.xs)
                    }
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
            .navigationTitle("Close Callout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.goldText)
                }
            }
            .safeAreaInset(edge: .bottom) { closeBar }
            .task { await loadLiveQuote() }
        }
        .presentationDragIndicator(.visible)
    }

    private var summaryCard: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: callout.direction.icon, tint: callout.direction.color, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("$\(callout.ticker)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Tag(text: callout.direction.displayName.uppercased(), tint: callout.direction.color)
                }
                Text("Entry \(TradeCallout.formatPrice(callout.entryPrice))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: DS.Spacing.l)
    }

    private var exitSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            CalloutFormLabel(text: "Exit")
            VStack(spacing: 0) {
                CalloutInputRow(title: "Exit price") {
                    CalloutPriceField(placeholder: "0.00", text: $exitText)
                }
                livePriceRows
            }
            .cardStyle(padding: 0)
        }
    }

    @ViewBuilder
    private var livePriceRows: some View {
        switch liveQuote {
        case .loading:
            CalloutRowDivider()
            HStack(spacing: DS.Spacing.s) {
                ProgressView()
                Text("Checking the current price…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.l)
            .frame(minHeight: 50)
        case .live(let price):
            CalloutRowDivider()
            priceButton(title: "Use current price", price: price, detail: nil)
        case .unavailable:
            if let lastPrice = callout.lastPrice {
                CalloutRowDivider()
                priceButton(title: "Use last price", price: lastPrice,
                            detail: callout.lastPriceAt.map { "as of \(TradeCallout.formatTime($0))" })
            }
            CalloutRowDivider()
            Label("No live price right now. You can close at any price, but this close won't count toward your record.",
                  systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.m)
        }
    }

    private func priceButton(title: String, price: Double, detail: String?) -> some View {
        Button {
            exitText = TradeCallout.editablePrice(price)
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(Color.goldText)
                Spacer(minLength: DS.Spacing.s)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(TradeCallout.formatPrice(price))
                        .arkadNumber(15, weight: .semibold)
                        .foregroundStyle(Color.primary)
                    if let detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Result")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(resultPercent.map(TradeCallout.formatPercent) ?? "—")
                .arkadNumber(32)
                .foregroundStyle(resultPercent.map(TraderStats.color(for:)) ?? .secondary)
            if let exitValue {
                Text("\(callout.direction.displayName) from \(TradeCallout.formatPrice(callout.entryPrice)) to \(TradeCallout.formatPrice(exitValue))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(exitCheck == .live && callout.isPriceChecked
                 ? "Closing is final. The result counts toward your callout record."
                 : "Closing is final. This result won't count toward your callout record.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: DS.Spacing.l)
    }

    private var closeBar: some View {
        Button(action: save) {
            if isSaving {
                ProgressView().tint(Color.onGold)
            } else {
                Label("Close callout", systemImage: "flag.checkered")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canSave)
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.s)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
    }

    private func save() {
        guard let exitValue else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await onClose(exitValue, exitCheck)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                errorMessage = "Couldn't close the callout: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}
