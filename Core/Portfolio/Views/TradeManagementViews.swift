// File: Core/Portfolio/Views/TradeManagementViews.swift
// Trade detail sheet: see a trade, edit its journal, close it, or delete it.
// Trades imported from a linked brokerage are read-only.
// Proof labels (docs/backend-contracts.md, section 0): the entry (symbol, type, price, size, date)
// is locked once logged, and the exit once closed. Closing checks the exit against today's range;
// a price-checked trade stays price-checked only if its exit is too. A price-checked trade can be
// deleted only within 15 minutes of logging. "Share to community" opens ShareTradeToCommunitySheet.

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
    @State private var showShareToCommunity = false

    // Edit state (journal and plan only; the entry is locked)
    @State private var strategy: String
    @State private var notes: String
    @State private var stopLossPrice: String
    @State private var takeProfitPrice: String

    // Close state
    @State private var exitPrice = ""
    @State private var exitDate = Date()
    @State private var closingNotes = ""
    @StateObject private var priceChecker = TradePriceChecker()

    init(trade: Trade) {
        _current = State(initialValue: trade)
        _strategy = State(initialValue: trade.strategy ?? "")
        _notes = State(initialValue: trade.notes ?? "")
        _stopLossPrice = State(initialValue: trade.stopLossPrice.map(AssetTerms.inputString) ?? "")
        _takeProfitPrice = State(initialValue: trade.takeProfitPrice.map(AssetTerms.inputString) ?? "")
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
        .onChange(of: selectedAction) { _, action in
            if action == .close { loadExitQuote() }
        }
        .sheet(isPresented: $showShareToCommunity) {
            ShareTradeToCommunitySheet(trade: current)
                .environmentObject(FirebaseAuthService.shared)
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
            .disabled(isLoading || !isActionValid || (selectedAction == .close && exitOutcome.isChecking))
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
            proofCard
            Button {
                showShareToCommunity = true
            } label: {
                Label("Share to community", systemImage: "person.3")
            }
            .buttonStyle(SecondaryButtonStyle())
            if current.isImported {
                importedNote
            } else {
                deleteSection
            }
        }
    }

    /// The trade's proof label and what it means
    private var proofCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack {
                Text("Proof label")
                    .font(.headline)
                Spacer()
                TradeProofBadge(proof: current.proof)
            }
            Text(current.proof.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let check = current.priceCheck {
                Text("Entry checked against the day's range \(terms.price(check.low))–\(terms.price(check.high)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !current.isOpen, let exitProof = current.exitProof {
                Text(exitProof == .priceChecked
                     ? "Exit price-checked when it was closed."
                     : "Exit self-reported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Price-checked trades can be deleted only within 15 minutes of logging, so losing trades
    /// can't be removed later.
    private var deleteSection: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let canDelete = current.canDelete(at: context.date)
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                if canDelete {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete trade", systemImage: "trash")
                            .foregroundStyle(Color.marketRed)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                if let note = deleteNote(at: context.date, canDelete: canDelete) {
                    Label(note, systemImage: canDelete ? "clock" : "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func deleteNote(at now: Date, canDelete: Bool) -> String? {
        guard let deadline = current.deleteDeadline else { return nil }
        if canDelete {
            let minutes = max(1, Int((deadline.timeIntervalSince(now) / 60).rounded(.up)))
            return "You can delete this price-checked trade for \(minutes) more minute\(minutes == 1 ? "" : "s")."
        }
        return "Price-checked trades can only be deleted within 15 minutes of logging, so results can't be removed later."
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

    private var editContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            lockedEntryCard
            if current.isOpen {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    TradeCardTitle(title: "Risk plan", detail: "Optional")
                    HStack(alignment: .top, spacing: DS.Spacing.m) {
                        TradeInputField(
                            title: "Stop loss",
                            text: $stopLossPrice,
                            placeholder: "",
                            keyboard: .decimalPad,
                            prefix: terms.pricePrefix
                        )
                        TradeInputField(
                            title: "Take profit",
                            text: $takeProfitPrice,
                            placeholder: "",
                            keyboard: .decimalPad,
                            prefix: terms.pricePrefix
                        )
                    }
                }
                .cardStyle()
            }
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

    /// The entry (and exit, once closed) can't be edited, so the label means something.
    private var lockedEntryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(current.isOpen ? "Entry locked" : "Entry and exit locked")
                    .font(.subheadline.weight(.semibold))
            }
            Text("\(current.ticker) · \(current.tradeType.displayName) · \(terms.quantityText(current.quantity, symbol: current.ticker)) at \(terms.price(current.entryPrice)) on \(formatDate(current.entryDate))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(current.isOpen
                 ? "The symbol, size, entry price and date can't change after logging. If something's wrong, delete the trade and log it again\(current.proof == .priceChecked ? " (price-checked trades only within 15 minutes)" : "")."
                 : "A closed trade's entry and exit can't change. You can still edit the strategy and notes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var editValidationMessage: String? {
        guard current.isOpen else { return nil }
        if !stopLossPrice.trimmingCharacters(in: .whitespaces).isEmpty && (AssetTerms.parseNumber(stopLossPrice) ?? 0) <= 0 {
            return "Stop loss must be a number above 0."
        }
        if !takeProfitPrice.trimmingCharacters(in: .whitespaces).isEmpty && (AssetTerms.parseNumber(takeProfitPrice) ?? 0) <= 0 {
            return "Take profit must be a number above 0."
        }
        return nil
    }

    // MARK: - Close

    private var closeContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                TradeInputField(
                    title: terms.exitPriceTitle,
                    text: $exitPrice,
                    placeholder: exitLivePrice.map { AssetTerms.inputString(roundedPrice($0)) } ?? terms.pricePlaceholder,
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

            TradeProofCheckCard(
                outcome: exitOutcome,
                message: exitProofMessage,
                currentPriceText: priceChecker.quote.map { terms.price($0.current) },
                showsUseCurrentPrice: canUseCurrentExitPrice,
                onUseCurrentPrice: { if let quote = priceChecker.quote { setExitPrice(quote.current) } }
            )

            Label("Closing is final: the exit price and date can't be changed afterwards.", systemImage: "lock")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Exit proof

    /// The exit's own check (date today, price inside today's range)
    private var exitOutcome: PriceCheckOutcome {
        priceChecker.outcome(price: parsedExitPrice, date: exitDate, type: current.tradeType)
    }

    /// The label the whole trade ends up with after closing
    private var proofAfterClose: TradeProof {
        if current.proof == .priceChecked && exitOutcome.proof != .priceChecked { return .selfReported }
        return current.proof
    }

    private var exitProofMessage: String {
        let exitLine = TradePriceCheckRules.message(
            for: exitOutcome, price: parsedExitPrice, side: "exit", ticker: current.ticker, type: current.tradeType
        )
        guard !exitOutcome.isChecking, parsedExitPrice != nil else { return exitLine }
        switch (current.proof, proofAfterClose) {
        case (.priceChecked, .priceChecked):
            return exitLine + " The trade stays price-checked."
        case (.priceChecked, _):
            return exitLine + " The trade will become self-reported and stop counting toward your stats."
        case (.selfReported, _):
            return exitLine + " The entry was self-reported, so the trade stays self-reported."
        default:
            return exitLine
        }
    }

    private var canUseCurrentExitPrice: Bool {
        guard let quote = priceChecker.quote, Calendar.current.isDateInToday(exitDate) else { return false }
        return parsedExitPrice.map { abs($0 - quote.current) > 0.000_001 } ?? true
    }

    /// Today's quote for the exit check, or the portfolio's live price for stocks
    private var exitLivePrice: Double? {
        priceChecker.quote?.current ?? livePrice
    }

    private func loadExitQuote() {
        guard current.isOpen, !current.isImported else { return }
        priceChecker.load(ticker: current.ticker, type: current.tradeType, debounce: false)
    }

    private var quickCloseChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                if let live = exitLivePrice {
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
        let trimmedStrategy = strategy.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedTrade.strategy = trimmedStrategy.isEmpty ? nil : trimmedStrategy
        updatedTrade.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        if current.isOpen {
            updatedTrade.stopLossPrice = AssetTerms.parseNumber(stopLossPrice).flatMap { $0 > 0 ? $0 : nil }
            updatedTrade.takeProfitPrice = AssetTerms.parseNumber(takeProfitPrice).flatMap { $0 > 0 ? $0 : nil }
        }

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

        // Check the exit with a quote at most two minutes old; if the label changed since the
        // user last saw it, show the new one instead of closing.
        let shownProof = exitOutcome.proof
        let outcome = await priceChecker.outcomeForSaving(
            ticker: current.ticker, price: price, date: exitDate, type: current.tradeType
        )
        if outcome.proof != shownProof {
            present(
                "Proof label changed",
                TradePriceCheckRules.message(for: outcome, price: price, side: "exit",
                                             ticker: current.ticker, type: current.tradeType)
                    + " Check it, then tap Close position again."
            )
            return
        }

        var notesAfterClose = current.notes
        let closing = closingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !closing.isEmpty {
            let existing = (current.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            notesAfterClose = existing.isEmpty ? "Closing notes: \(closing)" : "\(existing)\n\nClosing notes: \(closing)"
        }

        do {
            let closedTrade = try await portfolioViewModel.closeTrade(
                current, exitPrice: price, exitDate: exitDate, exitOutcome: outcome, notes: notesAfterClose
            )
            current = closedTrade
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let profit = closedTrade.profitLoss
            let result = profit >= 0
                ? "You closed \(closedTrade.ticker) with a profit of \(profit.asCurrency)."
                : "You closed \(closedTrade.ticker) with a loss of \(abs(profit).asCurrency)."
            let label = closedTrade.proof == .priceChecked
                ? " It's price-checked and counts toward your stats."
                : " It's self-reported, so it doesn't count toward your stats."
            present("Position closed", result + label, thenDismiss: true)
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
            present("Couldn't delete trade", error.localizedDescription)
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
                        TradeProofBadge(proof: trade.proof, compact: true)
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
