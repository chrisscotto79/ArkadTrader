// File: Core/Portfolio/Views/TradeManagementViews.swift
// Trade detail sheet: see a trade, edit it, close it, or delete it.
// Trades imported from a linked brokerage are read-only.

import SwiftUI

struct TradeActionsSheet: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss

    /// The trade as last saved from this sheet (updates after edits/closing)
    @State private var current: Trade
    @State private var selectedAction: TradeAction = .view

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var dismissAfterAlert = false
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false

    // Edit state
    @State private var ticker: String
    @State private var tradeType: TradeType
    @State private var entryPrice: String
    @State private var quantity: String
    @State private var strategy: String
    @State private var notes: String
    @State private var entryDate: Date

    // Close state
    @State private var exitPrice = ""
    @State private var exitDate = Date()
    @State private var closingNotes = ""

    init(trade: Trade) {
        _current = State(initialValue: trade)
        _ticker = State(initialValue: trade.ticker)
        _tradeType = State(initialValue: trade.tradeType)
        _entryPrice = State(initialValue: AssetTerms.inputString(trade.entryPrice))
        _quantity = State(initialValue: AssetTerms.inputString(trade.quantity))
        _strategy = State(initialValue: trade.strategy ?? "")
        _notes = State(initialValue: trade.notes ?? "")
        _entryDate = State(initialValue: trade.entryDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.l) {
                    TradeHeroCard(trade: current)
                    if availableActions.count > 1 {
                        SegmentedPicker(options: availableActions, selection: $selectedAction) { $0.title }
                    }
                    content
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xl)
                .animation(.snappy(duration: 0.25), value: selectedAction)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .screenBackground()
            .navigationTitle(current.ticker)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.goldText)
                }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if dismissAfterAlert { dismiss() }
            }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("Delete this trade?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete trade", role: .destructive) {
                Task { await deleteTrade() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will be removed from your portfolio and stats. This can't be undone.")
        }
    }

    private var availableActions: [TradeAction] {
        TradeAction.allCases.filter { $0.isAvailable(for: current) }
    }

    private var terms: AssetTerms { AssetTerms(current.tradeType) }

    @ViewBuilder
    private var content: some View {
        switch selectedAction {
        case .view: detailsContent
        case .edit: editContent
        case .close: closeContent
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if let title = bottomButtonTitle {
            Button {
                if selectedAction == .view {
                    selectedAction = .close
                } else {
                    Task { await performAction() }
                }
            } label: {
                HStack(spacing: DS.Spacing.s) {
                    if isLoading {
                        ProgressView().tint(Color.onGold)
                    }
                    Text(title)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoading || !isActionValid)
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.m)
            .padding(.bottom, DS.Spacing.s)
            .background(
                Color.appBackground
                    .overlay(alignment: .top) { Divider().overlay(Color.hairline) }
                    .ignoresSafeArea()
            )
        }
    }

    private var bottomButtonTitle: String? {
        switch selectedAction {
        case .view: return current.isOpen && !current.isImported ? "Close position" : nil
        case .edit: return "Save changes"
        case .close: return "Close position"
        }
    }

    // MARK: - Details

    private var detailsContent: some View {
        VStack(spacing: DS.Spacing.l) {
            detailsCard
            if let tradeNotes = current.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !tradeNotes.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    TradeCardTitle(title: "Notes")
                    Text(tradeNotes)
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            if current.isImported {
                importedNote
            } else {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete trade", systemImage: "trash")
                        .foregroundStyle(Color.marketRed)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    /// Imported trades come from the brokerage, so they can't be edited, closed or deleted here
    private var importedNote: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            IconWell(systemName: "checkmark.seal.fill", tint: .marketGreen, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Imported from your brokerage")
                    .font(.subheadline.weight(.semibold))
                Text("Verified trades sync automatically and can't be edited in Arkad.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            TradeInfoRow(title: "Asset", value: current.tradeType.displayName)
            TradeInfoRow(title: terms.quantityTitle, value: terms.quantityText(current.quantity, symbol: current.ticker))
            TradeInfoRow(title: terms.entryPriceTitle, value: terms.price(current.entryPrice))
            TradeInfoRow(title: "Cost basis", value: current.totalInvested.asCurrency)
            if current.isOpen, let live = livePrice {
                TradeInfoRow(title: "Current price", value: terms.price(live))
            }
            if !current.isOpen, let exit = current.exitPrice {
                TradeInfoRow(title: terms.exitPriceTitle, value: terms.price(exit))
            }
            TradeInfoRow(title: "Entry date", value: formatDate(current.entryDate))
            if !current.isOpen, let exit = current.exitDate {
                TradeInfoRow(title: "Exit date", value: formatDate(exit))
                TradeInfoRow(title: "Held", value: formatHoldTime(from: current.entryDate, to: exit))
            }
            if let stop = current.stopLossPrice {
                TradeInfoRow(title: "Stop loss", value: terms.price(stop))
            }
            if let target = current.takeProfitPrice {
                TradeInfoRow(title: "Take profit", value: terms.price(target))
            }
            if let sector = current.sector, !sector.isEmpty {
                TradeInfoRow(title: "Sector", value: sector)
            }
            if let strategy = current.strategy, !strategy.isEmpty {
                TradeInfoRow(title: "Strategy", value: strategy)
            }
            TradeInfoRow(title: "Visibility", value: current.isPublic ? "On your profile" : "Only you", showsDivider: false)
        }
        .cardStyle(padding: 0)
    }

    /// Live market price, only for stocks with a quote that differs from entry
    private var livePrice: Double? {
        guard terms.usesLiveQuotes, let price = current.currentPrice, price > 0, price != current.entryPrice else { return nil }
        return price
    }

    // MARK: - Edit

    private var editTerms: AssetTerms { AssetTerms(tradeType) }

    private var editContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            if !current.isOpen {
                Label("This trade is closed, so only the strategy and notes can be changed.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            editPositionCard
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                TradeInputField(title: "Strategy", text: $strategy, placeholder: "Swing trade, breakout…")
                TradeNotesField(title: "Notes", text: $notes, placeholder: "Add notes about this trade…")
            }
            .cardStyle()
            if let message = editValidationMessage {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.marketRed)
            }
        }
    }

    private var editPositionCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            TradeInputField(
                title: editTerms.symbolTitle,
                text: $ticker,
                placeholder: editTerms.symbolPlaceholder,
                isSymbol: true,
                isEnabled: current.isOpen
            )

            VStack(alignment: .leading, spacing: 6) {
                TradeFieldLabel(text: "Asset")
                if current.isOpen {
                    SegmentedPicker(options: TradeType.allCases, selection: $tradeType) { $0.displayName }
                } else {
                    Text(tradeType.displayName)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: DS.Spacing.m) {
                TradeInputField(
                    title: editTerms.quantityTitle,
                    text: $quantity,
                    placeholder: editTerms.quantityPlaceholder,
                    keyboard: editTerms.quantityKeyboard,
                    isEnabled: current.isOpen
                )
                TradeInputField(
                    title: editTerms.entryPriceTitle,
                    text: $entryPrice,
                    placeholder: editTerms.pricePlaceholder,
                    keyboard: .decimalPad,
                    prefix: editTerms.pricePrefix,
                    isEnabled: current.isOpen
                )
            }

            Divider().overlay(Color.hairline)

            if current.isOpen {
                DatePicker(selection: $entryDate, in: ...Date(), displayedComponents: .date) {
                    Label("Entry date", systemImage: "calendar")
                        .font(.subheadline)
                }
                .tint(Color.arkadGold)
            } else {
                HStack {
                    Label("Entry date", systemImage: "calendar")
                        .font(.subheadline)
                    Spacer()
                    Text(formatDate(current.entryDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if current.isOpen, let price = editedEntryPrice, let amount = editedQuantity {
                HStack {
                    Text("Position cost")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text((price * amount).asCurrency)
                        .arkadNumber(17, weight: .semibold)
                }
            }
        }
        .cardStyle()
    }

    private var editedEntryPrice: Double? {
        guard let value = AssetTerms.parseNumber(entryPrice), value > 0 else { return nil }
        return value
    }

    private var editedQuantity: Double? {
        editTerms.parseQuantity(quantity)
    }

    private var editValidationMessage: String? {
        guard current.isOpen else { return nil }
        if ticker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return editTerms.missingSymbolMessage }
        if quantity.trimmingCharacters(in: .whitespaces).isEmpty { return editTerms.missingQuantityMessage }
        if editedQuantity == nil { return editTerms.invalidQuantityMessage }
        if entryPrice.trimmingCharacters(in: .whitespaces).isEmpty { return editTerms.missingPriceMessage }
        if editedEntryPrice == nil { return editTerms.invalidPriceMessage }
        return nil
    }

    // MARK: - Close

    private var closeContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                TradeInputField(
                    title: terms.exitPriceTitle,
                    text: $exitPrice,
                    placeholder: livePrice.map { AssetTerms.inputString(roundedPrice($0)) } ?? terms.pricePlaceholder,
                    keyboard: .decimalPad,
                    prefix: terms.pricePrefix
                )
                quickCloseChips
                Divider().overlay(Color.hairline)
                DatePicker(selection: $exitDate, in: exitDateRange, displayedComponents: .date) {
                    Label("Exit date", systemImage: "calendar")
                        .font(.subheadline)
                }
                .tint(Color.arkadGold)
                TradeNotesField(title: "Closing notes (optional)", text: $closingNotes, placeholder: "What happened, what you learned…")
            }
            .cardStyle()

            if let price = parsedExitPrice {
                ProjectedPLCard(trade: current, exitPrice: price)
                    .transition(.opacity)
            }
        }
    }

    private var quickCloseChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                if let live = livePrice {
                    Chip(title: "Live price", systemImage: "dot.radiowaves.left.and.right", isSelected: false) {
                        setExitPrice(live)
                    }
                }
                Chip(title: "Break even", isSelected: false) { setExitPrice(current.entryPrice) }
                Chip(title: "+5%", isSelected: false) { setExitPrice(current.entryPrice * 1.05) }
                Chip(title: "+10%", isSelected: false) { setExitPrice(current.entryPrice * 1.10) }
                Chip(title: "−5%", isSelected: false) { setExitPrice(current.entryPrice * 0.95) }
            }
        }
        .scrollClipDisabled()
    }

    private var exitDateRange: ClosedRange<Date> {
        let now = Date()
        return min(current.entryDate, now)...now
    }

    private var parsedExitPrice: Double? {
        guard let value = AssetTerms.parseNumber(exitPrice), value > 0 else { return nil }
        return value
    }

    private func roundedPrice(_ value: Double) -> Double {
        let places = current.tradeType == .forex ? 5 : (abs(value) < 1 ? 6 : 2)
        return value.rounded(to: places)
    }

    private func setExitPrice(_ value: Double) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.snappy(duration: 0.2)) {
            exitPrice = AssetTerms.inputString(roundedPrice(value))
        }
    }

    // MARK: - Actions

    private var isActionValid: Bool {
        switch selectedAction {
        case .view: return current.isOpen
        case .edit: return editValidationMessage == nil
        case .close: return parsedExitPrice != nil
        }
    }

    @MainActor
    private func performAction() async {
        guard !isLoading else { return }
        isLoading = true
        switch selectedAction {
        case .view: break
        case .edit: await saveTradeEdits()
        case .close: await closePosition()
        }
        isLoading = false
    }

    @MainActor
    private func saveTradeEdits() async {
        var updatedTrade = current
        if current.isOpen {
            guard let price = editedEntryPrice, let amount = editedQuantity else { return }
            let newTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            // A different symbol or asset type makes any stored live price meaningless
            if newTicker != current.ticker || tradeType != current.tradeType {
                updatedTrade.currentPrice = nil
            }
            updatedTrade.ticker = newTicker
            updatedTrade.tradeType = tradeType
            updatedTrade.entryPrice = price
            updatedTrade.quantity = amount
            updatedTrade.entryDate = entryDate
        }
        let trimmedStrategy = strategy.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedTrade.strategy = trimmedStrategy.isEmpty ? nil : trimmedStrategy
        updatedTrade.notes = trimmedNotes.isEmpty ? nil : trimmedNotes

        do {
            try await portfolioViewModel.updateTrade(updatedTrade)
            current = updatedTrade
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            selectedAction = .view
        } catch {
            present("Couldn't save changes", "Failed to update trade: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func closePosition() async {
        guard let price = parsedExitPrice else { return }

        var closedTrade = current
        closedTrade.close(at: price, on: exitDate)

        let closing = closingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !closing.isEmpty {
            let existing = (current.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            closedTrade.notes = existing.isEmpty ? "Closing notes: \(closing)" : "\(existing)\n\nClosing notes: \(closing)"
        }

        do {
            try await portfolioViewModel.updateTrade(closedTrade)
            current = closedTrade
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let profit = closedTrade.profitLoss
            present(
                "Position closed",
                profit >= 0
                    ? "You closed \(closedTrade.ticker) with a profit of \(profit.asCurrency)."
                    : "You closed \(closedTrade.ticker) with a loss of \(abs(profit).asCurrency).",
                thenDismiss: true
            )
        } catch {
            present("Couldn't close position", "Failed to close trade: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func deleteTrade() async {
        do {
            try await portfolioViewModel.deleteTrade(current)
            dismiss()
        } catch {
            present("Couldn't delete trade", "Failed to delete trade: \(error.localizedDescription)")
        }
    }

    private func present(_ title: String, _ message: String, thenDismiss: Bool = false) {
        alertTitle = title
        alertMessage = message
        dismissAfterAlert = thenDismiss
        showAlert = true
    }

    // MARK: - Formatting

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func formatHoldTime(from startDate: Date, to endDate: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        switch days {
        case ..<1: return "Same day"
        case 1: return "1 day"
        default: return "\(days) days"
        }
    }
}

// MARK: - Hero

/// Top card of the trade sheet: symbol, status and the headline number
private struct TradeHeroCard: View {
    let trade: Trade

    private var terms: AssetTerms { AssetTerms(trade.tradeType) }

    private var livePrice: Double? {
        guard terms.usesLiveQuotes, let price = trade.currentPrice, price > 0, price != trade.entryPrice else { return nil }
        return price
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(spacing: DS.Spacing.m) {
                AssetTickerBadge(symbol: trade.ticker, type: trade.tradeType, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(trade.ticker)
                            .font(.title3.weight(.bold))
                            .lineLimit(1)
                        if trade.isVerified == true {
                            VerifiedTradeBadge()
                        }
                    }
                    Text("\(trade.tradeType.displayName) · \(terms.quantityText(trade.quantity, symbol: trade.ticker))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: DS.Spacing.s)
                Tag(
                    text: trade.isOpen ? "Open" : "Closed",
                    systemImage: trade.isOpen ? "clock" : "checkmark",
                    tint: trade.isOpen ? .goldText : .secondary
                )
            }
            headline
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 20)
    }

    @ViewBuilder
    private var headline: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            if trade.isOpen {
                Text(livePrice == nil ? "Value at cost" : "Market value")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(trade.currentValue.asCurrency)
                    .arkadNumber(34)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if livePrice != nil {
                    HStack(spacing: DS.Spacing.s) {
                        ChangePill(
                            text: "\(trade.unrealizedPL.asCurrencyWithSign) (\(String(format: "%+.1f%%", trade.unrealizedPLPercentage)))",
                            isPositive: trade.unrealizedPL >= 0
                        )
                        Text("unrealized")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(terms.usesLiveQuotes
                         ? "Live price unavailable right now, so this is valued at your entry price."
                         : "\(trade.tradeType.displayName) positions are valued at your entry price. P&L is locked in when you close.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Realized P&L")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(trade.profitLoss.asCurrencyWithSign)
                    .arkadNumber(34)
                    .foregroundStyle(trade.profitLoss >= 0 ? Color.marketGreen : Color.marketRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                ChangePill(
                    text: String(format: "%+.1f%%", trade.profitLossPercentage),
                    isPositive: trade.profitLoss >= 0
                )
            }
        }
    }
}

// MARK: - Supporting views and types

enum TradeAction: CaseIterable {
    case view, edit, close

    var title: String {
        switch self {
        case .view: return "Details"
        case .edit: return "Edit"
        case .close: return "Close"
        }
    }

    var icon: String {
        switch self {
        case .view: return "doc.text"
        case .edit: return "pencil"
        case .close: return "xmark.circle"
        }
    }

    func isAvailable(for trade: Trade) -> Bool {
        switch self {
        case .view:
            return true
        case .edit:
            return !trade.isImported
        case .close:
            return trade.isOpen && !trade.isImported
        }
    }
}

/// What the trade would make or lose if closed at `exitPrice`
struct ProjectedPLCard: View {
    let trade: Trade
    let exitPrice: Double

    private var projectedPL: Double {
        (exitPrice - trade.entryPrice) * trade.quantity
    }

    private var returnPercentage: Double {
        let cost = trade.entryPrice * trade.quantity
        return cost > 0 ? projectedPL / cost * 100 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("If you close at \(AssetTerms(trade.tradeType).price(exitPrice))")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: DS.Spacing.m) {
                Text(projectedPL.asCurrencyWithSign)
                    .arkadNumber(28)
                    .foregroundStyle(projectedPL >= 0 ? Color.marketGreen : Color.marketRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                ChangePill(text: String(format: "%+.2f%%", returnPercentage), isPositive: projectedPL >= 0)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .animation(.snappy, value: exitPrice)
    }
}
