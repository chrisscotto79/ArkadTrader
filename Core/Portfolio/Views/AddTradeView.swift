// File: Core/Portfolio/Views/AddTradeView.swift
// Step-by-step flow for logging a stock, option, crypto or forex trade:
// Asset -> Details -> Plan & notes -> Review. The primary button stays pinned to the bottom.

import SwiftUI

struct AddTradeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss

    // Basic trade info
    @State private var ticker = ""
    @State private var tradeType: TradeType = .stock
    @State private var entryPrice = ""
    @State private var quantity = ""
    @State private var entryDate = Date()

    // Risk plan & stock extras
    @State private var stopLossPrice = ""
    @State private var takeProfitPrice = ""
    @State private var sector = ""

    // Option contract details
    @State private var optionType: TradeOptionType = .call
    @State private var strikePrice = ""
    @State private var expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)

    // Journal
    @State private var strategy = ""
    @State private var notes = ""
    /// Public trades appear on the user's profile and in followers' Following feed.
    @State private var isPublic = true

    // UI state
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var step: AddTradeStep = .asset
    @State private var movingForward = true

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    stepHeader
                    stepContent
                        .id(step)
                        .transition(stepTransition)
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        }
        .screenBackground()
        .interactiveDismissDisabled(hasEnteredDetails)
        .alert("Couldn't add trade", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var terms: AssetTerms { AssetTerms(tradeType) }

    // MARK: - Chrome

    private var topBar: some View {
        VStack(spacing: DS.Spacing.m) {
            HStack {
                IconButton(
                    systemName: step == .asset ? "xmark" : "chevron.left",
                    accessibilityLabel: step == .asset ? "Cancel" : "Back"
                ) {
                    if step == .asset {
                        dismiss()
                    } else {
                        previousStep()
                    }
                }
                Spacer()
                Text("Step \(step.rawValue) of \(AddTradeStep.allCases.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if step == .asset {
                    Color.clear.frame(width: 38, height: 38)
                } else {
                    IconButton(systemName: "xmark", accessibilityLabel: "Cancel") { dismiss() }
                }
            }
            progressBar
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.top, DS.Spacing.l)
        .padding(.bottom, DS.Spacing.m)
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(AddTradeStep.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color.arkadGold : Color.surfaceRaised)
                    .frame(height: 4)
            }
        }
        .animation(.snappy(duration: 0.3), value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step.rawValue) of \(AddTradeStep.allCases.count), \(step.shortName)")
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(step.title)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text(step.subtitle(for: tradeType))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .asset: assetStep
        case .details: detailsStep
        case .extras: extrasStep
        case .review: reviewStep
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        )
    }

    private var bottomBar: some View {
        Button {
            if step == .review {
                Task { await addTrade() }
            } else {
                nextStep()
            }
        } label: {
            HStack(spacing: DS.Spacing.s) {
                if isLoading {
                    ProgressView().tint(Color.onGold)
                }
                Text(step == .review ? "Add trade" : "Continue")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canProceed || isLoading)
        .padding(.horizontal, DS.pageMargin)
        .padding(.top, DS.Spacing.m)
        .padding(.bottom, DS.Spacing.s)
        .background(
            Color.appBackground
                .overlay(alignment: .top) { Divider().overlay(Color.hairline) }
                .ignoresSafeArea()
        )
    }

    // MARK: - Step 1: Asset

    private var assetStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.m),
                                GridItem(.flexible(), spacing: DS.Spacing.m)],
                      spacing: DS.Spacing.m) {
                ForEach(supportedTradeTypes, id: \.self) { type in
                    assetCard(type)
                }
            }

            Label("Stocks update with live prices. Options, crypto and forex are valued at your entry price until you close them.",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func assetCard(_ type: TradeType) -> some View {
        let isSelected = tradeType == type
        let cardTerms = AssetTerms(type)
        let shape = RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)

        return Button {
            selectType(type)
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                HStack(alignment: .top) {
                    IconWell(systemName: type.icon, tint: cardTerms.tint, size: 40)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.goldText : Color.secondary.opacity(0.35))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(cardTerms.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.l)
            .background(shape.fill(isSelected ? Color.goldTint : Color.surface))
            .overlay(shape.strokeBorder(isSelected ? Color.arkadGold : Color.hairline, lineWidth: isSelected ? 2 : 1))
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Step 2: Details

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            positionCard
            if tradeType == .option {
                contractCard
            }
            dateCard
            if hasEnteredDetails, let message = detailsValidationMessage {
                validationLabel(message)
            }
        }
    }

    private var positionCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            TradeInputField(
                title: terms.symbolTitle,
                text: $ticker,
                placeholder: terms.symbolPlaceholder,
                isSymbol: true
            )

            if tradeType == .option {
                VStack(alignment: .leading, spacing: 6) {
                    TradeFieldLabel(text: "Option type")
                    SegmentedPicker(options: TradeOptionType.allCases, selection: $optionType) { $0.displayName }
                }
            }

            HStack(alignment: .top, spacing: DS.Spacing.m) {
                TradeInputField(
                    title: terms.quantityTitle,
                    text: $quantity,
                    placeholder: terms.quantityPlaceholder,
                    keyboard: terms.quantityKeyboard
                )
                TradeInputField(
                    title: terms.entryPriceTitle,
                    text: $entryPrice,
                    placeholder: terms.pricePlaceholder,
                    keyboard: .decimalPad,
                    prefix: terms.pricePrefix
                )
            }

            if let helper = priceHelperText {
                Text(helper)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let cost = positionCost {
                Divider().overlay(Color.hairline)
                HStack {
                    Text("Position cost")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(cost.asCurrency)
                        .arkadNumber(17, weight: .semibold)
                }
            }
        }
        .cardStyle()
    }

    private var priceHelperText: String? {
        switch tradeType {
        case .option:
            return "Enter what one contract cost (quoted premium × 100, so 5.50 → 550). Use the same basis when you close the trade."
        case .forex:
            return "Rate for 1 unit of the base currency. P&L is shown in dollars, so it's exact for USD-quoted pairs like EUR/USD."
        case .crypto:
            return "Fractions are fine, like 0.25 BTC."
        case .stock:
            return nil
        }
    }

    private var contractCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            TradeInputField(
                title: "Strike price (optional)",
                text: $strikePrice,
                placeholder: "155.00",
                keyboard: .decimalPad,
                prefix: "$"
            )
            Divider().overlay(Color.hairline)
            DatePicker(selection: $expirationDate, displayedComponents: .date) {
                Label("Expires", systemImage: "timer")
                    .font(.subheadline)
            }
            .tint(Color.arkadGold)
        }
        .cardStyle()
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            DatePicker(selection: $entryDate, in: ...Date(), displayedComponents: .date) {
                Label("Entry date", systemImage: "calendar")
                    .font(.subheadline)
            }
            .tint(Color.arkadGold)

            if tradeType == .stock {
                Divider().overlay(Color.hairline)
                TradeInputField(
                    title: "Sector (optional)",
                    text: $sector,
                    placeholder: "Technology, Healthcare…"
                )
            }
        }
        .cardStyle()
    }

    private func validationLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.marketRed)
            .transition(.opacity)
    }

    // MARK: - Step 3: Plan & notes

    private var extrasStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            riskCard
            journalCard
            sharingCard
            if let message = extrasValidationMessage {
                validationLabel(message)
            }
        }
    }

    private var riskCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            TradeCardTitle(title: "Risk plan", detail: "Optional")
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                TradeInputField(
                    title: "Stop loss",
                    text: $stopLossPrice,
                    placeholder: entryPriceHint(-5),
                    keyboard: .decimalPad,
                    prefix: terms.pricePrefix
                )
                TradeInputField(
                    title: "Take profit",
                    text: $takeProfitPrice,
                    placeholder: entryPriceHint(10),
                    keyboard: .decimalPad,
                    prefix: terms.pricePrefix
                )
            }
            if tradeType == .option {
                Text("Use per-contract values, the same basis as your entry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let plan = riskPlan {
                Divider().overlay(Color.hairline)
                riskSummary(plan)
            }
        }
        .cardStyle()
    }

    private func riskSummary(_ plan: (risk: Double, reward: Double)) -> some View {
        let ratio = plan.risk > 0 ? plan.reward / plan.risk : 0
        return HStack(spacing: 0) {
            riskMetric("Risk", plan.risk.asCurrency, color: .marketRed)
            riskMetric("Reward", plan.reward.asCurrency, color: .marketGreen)
            riskMetric("Ratio", String(format: "1 : %.1f", ratio), color: .primary)
        }
    }

    private func riskMetric(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .arkadNumber(16, weight: .semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            TradeCardTitle(title: "Journal", detail: "Optional")
            TradeInputField(
                title: "Strategy",
                text: $strategy,
                placeholder: "Swing trade, breakout…"
            )
            TradeNotesField(title: "Notes", text: $notes, placeholder: "Why you took this trade, what you're watching…")
        }
        .cardStyle()
    }

    private var sharingCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Toggle(isOn: $isPublic) {
                Label("Show on my profile", systemImage: isPublic ? "eye" : "eye.slash")
                    .font(.subheadline.weight(.medium))
            }
            .tint(Color.arkadGold)

            Text("Public trades appear on your profile and in your followers' Following feed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    // MARK: - Step 4: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            reviewHero
            reviewDetails
        }
    }

    private var reviewHero: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(spacing: DS.Spacing.m) {
                AssetTickerBadge(symbol: displayTicker, type: tradeType, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTicker)
                        .font(.title3.weight(.bold))
                    Text(tradeType == .option ? "\(optionType.displayName) option" : tradeType.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Position cost")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text((positionCost ?? 0).asCurrency)
                    .arkadNumber(32)
                Text(positionSentence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    private var reviewDetails: some View {
        VStack(spacing: 0) {
            TradeInfoRow(title: "Entry date", value: entryDate.formatted(date: .abbreviated, time: .omitted))
            if tradeType == .option {
                if let strike = AssetTerms.parseNumber(strikePrice), strike > 0 {
                    TradeInfoRow(title: "Strike", value: AssetTerms(.stock).price(strike))
                }
                TradeInfoRow(title: "Expires", value: expirationDate.formatted(date: .abbreviated, time: .omitted))
            }
            if let stop = AssetTerms.parseNumber(stopLossPrice), stop > 0 {
                TradeInfoRow(title: "Stop loss", value: terms.price(stop))
            }
            if let target = AssetTerms.parseNumber(takeProfitPrice), target > 0 {
                TradeInfoRow(title: "Take profit", value: terms.price(target))
            }
            if tradeType == .stock && !trimmed(sector).isEmpty {
                TradeInfoRow(title: "Sector", value: trimmed(sector))
            }
            if !trimmed(strategy).isEmpty {
                TradeInfoRow(title: "Strategy", value: trimmed(strategy))
            }
            if !trimmed(notes).isEmpty {
                TradeInfoRow(title: "Notes", value: trimmed(notes))
            }
            TradeInfoRow(title: "Visibility", value: isPublic ? "On your profile" : "Only you", showsDivider: false)
        }
        .cardStyle(padding: 0)
    }

    private var positionSentence: String {
        let amount = parsedQuantity.map { terms.quantityText($0, symbol: displayTicker) } ?? "–"
        let price = parsedEntryPrice.map { terms.price($0) } ?? "–"
        return tradeType == .forex ? "\(amount) at \(price)" : "\(amount) at \(price) each"
    }
}

// MARK: - Steps

private enum AddTradeStep: Int, CaseIterable {
    case asset = 1, details, extras, review

    var shortName: String {
        switch self {
        case .asset: return "Asset"
        case .details: return "Details"
        case .extras: return "Plan & notes"
        case .review: return "Review"
        }
    }

    var title: String {
        switch self {
        case .asset: return "What are you trading?"
        case .details: return "Trade details"
        case .extras: return "Plan & notes"
        case .review: return "Review your trade"
        }
    }

    func subtitle(for type: TradeType) -> String {
        switch self {
        case .asset: return "Pick the type of asset. You can log any of them in your journal."
        case .details: return "What you bought, how much, and at what \(type == .forex ? "rate" : "price")."
        case .extras: return "Set exits and add context. Everything here is optional."
        case .review: return "Check the details, then add it to your portfolio."
        }
    }
}

// MARK: - Logic

extension AddTradeView {
    /// Every asset type can be logged; quantities may be fractional (except option contracts).
    private var supportedTradeTypes: [TradeType] { TradeType.allCases }

    private var canProceed: Bool {
        switch step {
        case .asset: return supportedTradeTypes.contains(tradeType)
        case .details: return detailsValidationMessage == nil
        case .extras, .review: return detailsValidationMessage == nil && extrasValidationMessage == nil
        }
    }

    private var parsedEntryPrice: Double? {
        guard let value = AssetTerms.parseNumber(entryPrice), value > 0 else { return nil }
        return value
    }

    private var parsedQuantity: Double? {
        terms.parseQuantity(quantity)
    }

    private var positionCost: Double? {
        guard let price = parsedEntryPrice, let amount = parsedQuantity else { return nil }
        return price * amount
    }

    private var hasEnteredDetails: Bool {
        !trimmed(ticker).isEmpty || !trimmed(quantity).isEmpty || !trimmed(entryPrice).isEmpty
    }

    /// Why the step-2 details can't be saved yet, or nil when they're valid.
    private var detailsValidationMessage: String? {
        if trimmed(ticker).isEmpty { return terms.missingSymbolMessage }
        if trimmed(quantity).isEmpty { return terms.missingQuantityMessage }
        if parsedQuantity == nil { return terms.invalidQuantityMessage }
        if trimmed(entryPrice).isEmpty { return terms.missingPriceMessage }
        if parsedEntryPrice == nil { return terms.invalidPriceMessage }
        if tradeType == .option && !trimmed(strikePrice).isEmpty && (AssetTerms.parseNumber(strikePrice) ?? 0) <= 0 {
            return "Strike price must be a number above 0."
        }
        return nil
    }

    /// Why the optional stop loss / take profit can't be saved, or nil.
    private var extrasValidationMessage: String? {
        if !trimmed(stopLossPrice).isEmpty && (AssetTerms.parseNumber(stopLossPrice) ?? 0) <= 0 {
            return "Stop loss must be a number above 0."
        }
        if !trimmed(takeProfitPrice).isEmpty && (AssetTerms.parseNumber(takeProfitPrice) ?? 0) <= 0 {
            return "Take profit must be a number above 0."
        }
        return nil
    }

    /// Total amount at risk and potential reward for the whole position.
    private var riskPlan: (risk: Double, reward: Double)? {
        guard let entry = parsedEntryPrice, let amount = parsedQuantity,
              let stop = AssetTerms.parseNumber(stopLossPrice), stop > 0,
              let target = AssetTerms.parseNumber(takeProfitPrice), target > 0 else { return nil }
        return (abs(entry - stop) * amount, abs(target - entry) * amount)
    }

    private var displayTicker: String {
        trimmed(ticker).uppercased()
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func entryPriceHint(_ percentage: Double) -> String {
        guard let price = parsedEntryPrice else { return "" }
        return AssetTerms.inputString((price * (1 + percentage / 100)).rounded(to: price < 1 ? 6 : 2))
    }

    private func selectType(_ type: TradeType) {
        guard type != tradeType else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.snappy(duration: 0.25)) {
            tradeType = type
            resetTradeSpecificFields()
        }
    }

    private func resetTradeSpecificFields() {
        quantity = ""
        entryPrice = ""
        stopLossPrice = ""
        takeProfitPrice = ""
        strikePrice = ""
    }

    private func nextStep() {
        guard let next = AddTradeStep(rawValue: step.rawValue + 1) else { return }
        hideKeyboard()
        movingForward = true
        withAnimation(.snappy(duration: 0.3)) { step = next }
    }

    private func previousStep() {
        guard let previous = AddTradeStep(rawValue: step.rawValue - 1) else { return }
        hideKeyboard()
        movingForward = false
        withAnimation(.snappy(duration: 0.3)) { step = previous }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    @MainActor
    private func addTrade() async {
        guard !isLoading else { return }
        guard let userId = authService.currentUser?.id else {
            alertMessage = "You need to be signed in to add a trade."
            showAlert = true
            return
        }
        if let problem = detailsValidationMessage ?? extrasValidationMessage {
            alertMessage = problem
            showAlert = true
            return
        }
        guard let price = parsedEntryPrice, let finalQuantity = parsedQuantity else {
            alertMessage = "Check the price and quantity and try again."
            showAlert = true
            return
        }

        isLoading = true

        var newTrade = Trade(
            ticker: displayTicker,
            tradeType: tradeType,
            entryPrice: price,
            quantity: finalQuantity,
            userId: userId
        )

        newTrade.entryDate = entryDate
        newTrade.isPublic = isPublic
        if !trimmed(strategy).isEmpty { newTrade.strategy = trimmed(strategy) }

        // Options keep their contract details in the notes
        var noteParts: [String] = []
        if tradeType == .option {
            var contractLine = optionType.displayName.uppercased()
            if let strike = AssetTerms.parseNumber(strikePrice), strike > 0 {
                contractLine += " · Strike \(AssetTerms(.stock).price(strike))"
            }
            contractLine += " · Expires \(formatDate(expirationDate))"
            noteParts.append(contractLine)
        }
        let trimmedNotes = trimmed(notes)
        if !trimmedNotes.isEmpty { noteParts.append(trimmedNotes) }
        if !noteParts.isEmpty { newTrade.notes = noteParts.joined(separator: "\n\n") }

        if let stopLoss = AssetTerms.parseNumber(stopLossPrice), stopLoss > 0 {
            newTrade.setStopLoss(stopLoss)
        }
        if let takeProfit = AssetTerms.parseNumber(takeProfitPrice), takeProfit > 0 {
            newTrade.setTakeProfit(takeProfit)
        }

        if tradeType == .stock && !trimmed(sector).isEmpty {
            newTrade.sector = trimmed(sector)
        }

        do {
            try await authService.addTrade(newTrade)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            portfolioViewModel.loadPortfolioData()
            isLoading = false
            dismiss()
        } catch {
            isLoading = false
            alertMessage = "Failed to add trade: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Form building blocks (shared with the trade edit/close sheet)

/// Small caption label above a form control
struct TradeFieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

/// Card title with an optional trailing hint ("Risk plan · Optional")
struct TradeCardTitle: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Labelled single-line input on a raised fill
struct TradeInputField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var prefix: String? = nil
    var isSymbol = false
    var isEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TradeFieldLabel(text: title)
            HStack(spacing: 4) {
                if let prefix {
                    Text(prefix)
                        .foregroundStyle(.secondary)
                }
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled(isSymbol || keyboard != .default)
                    .disabled(!isEnabled)
            }
            .font(.body)
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(Color.surfaceRaised)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var capitalization: TextInputAutocapitalization {
        if isSymbol { return .characters }
        return keyboard == .default ? .sentences : .never
    }
}

/// Labelled multi-line input on a raised fill
struct TradeNotesField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TradeFieldLabel(text: title)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(3...8)
                .font(.body)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(Color.surfaceRaised)
                )
        }
    }
}

/// Title / value row inside a card, with a hairline divider below
struct TradeInfoRow: View {
    let title: String
    let value: String
    var valueColor: Color = .primary
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.l) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: DS.Spacing.s)
                Text(value)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, 13)
            if showsDivider {
                Divider()
                    .overlay(Color.hairline)
                    .padding(.leading, DS.Spacing.l)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Supporting enums

enum TradeOptionType: CaseIterable {
    case call, put

    var displayName: String {
        switch self {
        case .call: return "Call"
        case .put: return "Put"
        }
    }

    var icon: String {
        switch self {
        case .call: return "arrow.up.circle.fill"
        case .put: return "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .call: return .marketGreen
        case .put: return .marketRed
        }
    }
}

#Preview {
    AddTradeView()
        .environmentObject(FirebaseAuthService.shared)
        .environmentObject(PortfolioViewModel())
}
