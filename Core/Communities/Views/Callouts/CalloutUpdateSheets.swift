// File: Core/Communities/Views/Callouts/CalloutUpdateSheets.swift
// The author's follow-ups on an open callout, and the timeline everyone can open from the card:
// - CalloutUpdateSheet: Trim (percent, optional price), Add (percent and price), Move stop,
//   Move target and Note. Posting goes through CalloutFollowUps.
// - CalloutTimelineSheet: the callout, each update in order, and the result once closed.

import SwiftUI

// MARK: - Update sheet

struct CalloutUpdateSheet: View {
    let callout: TradeCallout
    let parentMessageId: String
    /// Posts the update; the sheet closes when it returns. `referencePrice` is the live price checked against.
    let onPost: (_ update: CalloutUpdate, _ referencePrice: Double?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: CalloutUpdate.Kind = .trim
    @State private var percentText = "50"
    @State private var priceText = ""
    @State private var note = ""
    @State private var liveQuote: LiveQuote = .loading
    @State private var isSaving = false
    @State private var errorMessage: String?

    private enum LiveQuote: Equatable {
        case loading
        case live(Double)
        case unavailable
    }

    private var livePrice: Double? {
        if case .live(let price) = liveQuote { return price }
        return nil
    }

    /// The price new levels are checked against: the live quote, else the last stored price.
    private var referencePrice: Double? { livePrice ?? callout.lastPrice }

    /// Accepts "182.4", "$182.40" and "182,4".
    private static func number(_ text: String) -> Double? {
        var cleaned = text.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.contains(",") && !cleaned.contains(".") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }
        guard let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    private static func editable(_ price: Double) -> String {
        String(format: abs(price) < 1 ? "%.4f" : "%.2f", price)
    }

    private var update: CalloutUpdate {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return CalloutUpdate(
            parentMessageId: parentMessageId,
            kind: kind,
            price: kind == .note || priceText.isEmpty ? nil : Self.number(priceText),
            percent: kind.usesPercent ? Self.number(percentText) : nil,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
    }

    private var validationError: String? {
        if kind != .note, !priceText.isEmpty, Self.number(priceText) == nil { return "Enter a valid price" }
        return CalloutFollowUps.fieldError(for: update)
            ?? CalloutFollowUps.levelError(for: update, on: callout, referencePrice: referencePrice)
    }

    private var canPost: Bool { validationError == nil && !isSaving && liveQuote != .loading }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    summaryCard
                    kindPicker
                    detailsSection
                    noteSection
                    previewSection
                    if let validationError, showsValidation {
                        errorLabel(validationError)
                    }
                    if let errorMessage {
                        errorLabel(errorMessage)
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Update Callout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.goldText)
                }
            }
            .safeAreaInset(edge: .bottom) { postBar }
            .task { await loadLiveQuote() }
            .onChange(of: kind) { _, newKind in prefill(for: newKind) }
        }
        .presentationDragIndicator(.visible)
    }

    /// Errors show once the author has typed something, or for the level checks.
    private var showsValidation: Bool {
        switch kind {
        case .note: return !note.isEmpty
        case .moveStop, .moveTarget: return !priceText.isEmpty
        case .trim, .add: return !percentText.isEmpty || !priceText.isEmpty
        }
    }

    private func errorLabel(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.marketRed)
            .padding(.horizontal, DS.Spacing.xs)
    }

    // MARK: Live price

    private func loadLiveQuote() async {
        guard CalloutQuotes.canQuote(callout) else {
            liveQuote = .unavailable
            return
        }
        let quote = await CalloutQuotes.shared.postingQuote(for: CalloutQuotes.symbol(for: callout))
        guard !Task.isCancelled else { return }
        liveQuote = quote.map { LiveQuote.live($0.price) } ?? .unavailable
        if (kind == .trim || kind == .add), priceText.isEmpty, let price = livePrice {
            priceText = Self.editable(price)
        }
    }

    private func prefill(for kind: CalloutUpdate.Kind) {
        errorMessage = nil
        switch kind {
        case .trim:
            percentText = "50"
            priceText = livePrice.map(Self.editable) ?? ""
        case .add:
            percentText = "25"
            priceText = livePrice.map(Self.editable) ?? ""
        case .moveStop, .moveTarget:
            priceText = ""
        case .note:
            priceText = ""
        }
    }

    // MARK: Sections

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
                    Text("Entry \(TradeCallout.formatPrice(callout.entryPrice))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                currentPriceView
            }
            HStack(spacing: DS.Spacing.s) {
                levelPill(title: "Stop", price: callout.stopPrice, color: .marketRed)
                levelPill(title: "Target", price: callout.targetPrice, color: .marketGreen)
            }
        }
        .cardStyle(padding: DS.Spacing.l)
    }

    @ViewBuilder
    private var currentPriceView: some View {
        switch liveQuote {
        case .loading:
            ProgressView()
        case .live(let price):
            VStack(alignment: .trailing, spacing: 1) {
                Text(TradeCallout.formatPrice(price))
                    .arkadNumber(15, weight: .semibold)
                Text(TradeCallout.formatPercent(callout.percentMove(to: price)))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(TraderStats.color(for: callout.percentMove(to: price)))
            }
        case .unavailable:
            if let last = callout.lastPrice {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(TradeCallout.formatPrice(last))
                        .arkadNumber(15, weight: .semibold)
                    Text("last price")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
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

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            CalloutFormLabel(text: "Update")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.s) {
                    ForEach(CalloutUpdate.Kind.allCases) { option in
                        Chip(title: option.displayName, systemImage: option.icon, isSelected: kind == option) {
                            withAnimation(.snappy(duration: 0.2)) { kind = option }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        switch kind {
        case .trim, .add:
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                CalloutFormLabel(text: kind == .trim ? "Trim" : "Add")
                VStack(spacing: 0) {
                    CalloutInputRow(title: "Share of position") {
                        HStack(spacing: 2) {
                            TextField("50", text: $percentText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.body.monospacedDigit())
                                .frame(maxWidth: 80)
                            Text("%").foregroundStyle(.secondary)
                        }
                    }
                    quickPercents
                    CalloutRowDivider()
                    CalloutInputRow(title: kind == .trim ? "Price (optional)" : "Price") {
                        CalloutPriceField(placeholder: "0.00", text: $priceText)
                    }
                    if let livePrice {
                        CalloutRowDivider()
                        priceButton(title: "Use current price", price: livePrice)
                    }
                }
                .cardStyle(padding: 0)
            }
        case .moveStop, .moveTarget:
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                CalloutFormLabel(text: kind == .moveStop ? "New stop" : "New target")
                VStack(spacing: 0) {
                    CalloutInputRow(title: kind == .moveStop ? "Stop" : "Target") {
                        CalloutPriceField(placeholder: "0.00", text: $priceText)
                    }
                    if kind == .moveStop {
                        CalloutRowDivider()
                        priceButton(title: "Breakeven (entry)", price: callout.entryPrice)
                    }
                }
                .cardStyle(padding: 0)
                Text(kind == .moveStop
                     ? "The new stop replaces the old one on the callout. Price checks close it there from now on."
                     : "The new target replaces the old one on the callout. Price checks close it there from now on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.Spacing.xs)
            }
        case .note:
            EmptyView()
        }
    }

    private var quickPercents: some View {
        let options: [Double] = kind == .trim ? [25, 33, 50, 75, 100] : [10, 25, 50, 100]
        return HStack(spacing: DS.Spacing.s) {
            ForEach(options, id: \.self) { value in
                let isSelected = Self.number(percentText) == value
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    percentText = CalloutUpdate.formatShare(value).replacingOccurrences(of: "%", with: "")
                } label: {
                    Text(CalloutUpdate.formatShare(value))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(isSelected ? Color.inverseText : Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(Capsule().fill(isSelected ? Color.inverseFill : Color.surfaceRaised))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.bottom, DS.Spacing.m)
    }

    private func priceButton(title: String, price: Double) -> some View {
        Button {
            priceText = Self.editable(price)
        } label: {
            HStack {
                Text(title)
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
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            CalloutFormLabel(text: kind == .note ? "Note" : "Note (optional)")
            TextField(kind == .note ? "What's changed, what you're watching…" : "Why, what's next…",
                      text: $note, axis: .vertical)
                .lineLimit(kind == .note ? 3...8 : 2...5)
                .cardStyle(padding: DS.Spacing.l)
                .onChange(of: note) { _, newValue in
                    if newValue.count > 1000 { note = String(newValue.prefix(1000)) }
                }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            CalloutFormLabel(text: "Posts as")
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                IconWell(systemName: kind.icon, tint: kind.tint, size: 30)
                Text(update.summary(ticker: callout.ticker))
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .cardStyle(padding: DS.Spacing.m, radius: DS.Radius.m)
            if kind.notifiesMembers {
                Label("Members are notified.", systemImage: "bell")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.xs)
            }
        }
    }

    private var postBar: some View {
        Button(action: post) {
            if isSaving {
                ProgressView().tint(Color.onGold)
            } else {
                Label("Post update", systemImage: kind.icon)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canPost)
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.s)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
    }

    private func post() {
        guard canPost else { return }
        let pending = update
        let reference = referencePrice
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await onPost(pending, reference)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                errorMessage = "Couldn't post the update: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

// MARK: - Timeline sheet

/// Everything that happened to one callout, oldest first: posted, each update, and the result.
/// Starts from the updates already loaded in the channel and adds any found by a one-time query.
struct CalloutTimelineSheet: View {
    let callout: TradeCallout
    let parentMessageId: String
    let communityId: String
    let channelId: String
    let postedAt: Date
    let authorUsername: String

    @Environment(\.dismiss) private var dismiss
    @State private var updates: [CommunityMessage]
    @State private var isLoading = true

    init(callout: TradeCallout, parentMessageId: String, communityId: String, channelId: String,
         postedAt: Date, authorUsername: String, updates: [CommunityMessage]) {
        self.callout = callout
        self.parentMessageId = parentMessageId
        self.communityId = communityId
        self.channelId = channelId
        self.postedAt = postedAt
        self.authorUsername = authorUsername
        _updates = State(initialValue: updates.sorted { $0.createdAt < $1.createdAt })
    }

    private struct Item: Identifiable {
        let id: String
        let icon: String
        let tint: Color
        let title: String
        let detail: String?
        let date: Date?
    }

    private var items: [Item] {
        var list: [Item] = []
        var levels: [String] = []
        if let stop = callout.stopPrice { levels.append("Stop \(TradeCallout.formatPrice(stop))") }
        if let target = callout.targetPrice { levels.append("Target \(TradeCallout.formatPrice(target))") }
        // Stops and targets are stored as they are now, so say so once one has moved.
        let levelsMoved = updates.contains { message in
            let kind = message.calloutUpdate?.kind
            return kind == .moveStop || kind == .moveTarget
        }
        var postedLines: [String] = []
        if !levels.isEmpty {
            postedLines.append((levelsMoved ? "Now: " : "") + levels.joined(separator: " · "))
        }
        if let note = callout.note, !note.isEmpty { postedLines.append(note) }
        list.append(Item(
            id: "posted",
            icon: "megaphone.fill",
            tint: callout.direction.color,
            title: "\(callout.direction.displayName) $\(callout.ticker) at \(TradeCallout.formatPrice(callout.entryPrice))",
            detail: postedLines.isEmpty ? nil : postedLines.joined(separator: "\n"),
            date: callout.postedAt ?? postedAt
        ))
        for message in updates {
            guard let update = message.calloutUpdate else { continue }
            list.append(Item(
                id: message.id,
                icon: update.kind.icon,
                tint: update.kind.tint,
                title: update.kind == .note ? "Note" : update.headline(ticker: callout.ticker),
                detail: update.note,
                date: message.createdAt
            ))
        }
        if !callout.isOpen {
            let result = callout.finalPercent
            var title = callout.status.displayName
            if let result { title += ": \(TradeCallout.formatPercent(result))" }
            list.append(Item(
                id: "result",
                icon: callout.status.icon,
                tint: result.map(TraderStats.color(for:)) ?? .secondary,
                title: title,
                detail: callout.exitPrice.map { "Exit \(TradeCallout.formatPrice($0))" },
                date: callout.closedAt
            ))
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    header
                    VStack(alignment: .leading, spacing: 0) {
                        let all = items
                        ForEach(Array(all.enumerated()), id: \.element.id) { index, item in
                            row(item, isLast: index == all.count - 1)
                        }
                    }
                    .cardStyle(padding: DS.Spacing.l)
                    if isLoading {
                        HStack(spacing: DS.Spacing.s) {
                            ProgressView()
                            Text("Checking for more updates…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, DS.Spacing.xs)
                    }
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.vertical, DS.Spacing.l)
            }
            .screenBackground()
            .navigationTitle("Callout Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color.goldText)
                }
            }
            .task { await loadAll() }
        }
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.m) {
            IconWell(systemName: callout.direction.icon, tint: callout.direction.color, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("$\(callout.ticker)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Tag(text: callout.direction.displayName.uppercased(), tint: callout.direction.color)
                }
                Text("Callout by \(authorUsername)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Tag(text: callout.status.displayName, systemImage: callout.status.icon, tint: callout.status.color)
        }
        .cardStyle(padding: DS.Spacing.l)
    }

    private func row(_ item: Item, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            VStack(spacing: 0) {
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.tint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(item.tint.opacity(0.14)))
                if !isLast {
                    Rectangle()
                        .fill(Color.hairline)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 2)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let date = item.date {
                    Text(TradeCallout.formatTime(date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, isLast ? 0 : DS.Spacing.l)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// One-time read, in case some updates aren't in the loaded messages.
    private func loadAll() async {
        defer { isLoading = false }
        guard let fetched = try? await FirebaseServices.shared.getCalloutUpdates(
            communityId: communityId, channelId: channelId, parentMessageId: parentMessageId
        ) else { return }
        var byId = Dictionary(updates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for message in fetched where !BlockStore.shared.isBlocked(message.authorId) {
            byId[message.id] = message
        }
        updates = byId.values.sorted { $0.createdAt < $1.createdAt }
    }
}
