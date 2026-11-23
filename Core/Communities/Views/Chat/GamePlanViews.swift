// File: Core/Communities/Views/Chat/GamePlanViews.swift
// Game plans (`gamePlan` on a channel message): a leader's daily watchlist of up to 15 tickers,
// each with a bias and optional levels and note.
// - GamePlanCard: how it shows in chat
// - GamePlanSheet: the form opened from the composer's "+" menu

import SwiftUI

// MARK: - Card

struct GamePlanCard: View {
    let plan: GamePlan

    private func count(_ bias: GamePlan.Bias) -> Int {
        plan.tickers.filter { $0.bias == bias }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .center, spacing: DS.Spacing.m) {
                IconWell(systemName: "map.fill", tint: .goldText, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: DS.Spacing.s) {
                        Text("\(plan.tickers.count) ticker\(plan.tickers.count == 1 ? "" : "s")")
                        ForEach(GamePlan.Bias.allCases) { bias in
                            let n = count(bias)
                            if n > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: bias.icon).font(.system(size: 9, weight: .bold))
                                    Text("\(n)")
                                }
                                .foregroundStyle(bias.color)
                            }
                        }
                    }
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                ForEach(Array(plan.tickers.enumerated()), id: \.offset) { index, entry in
                    if index > 0 {
                        Rectangle().fill(Color.hairline).frame(height: 1)
                    }
                    row(entry)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous).fill(Color.surfaceRaised)
            )
        }
        .cardStyle(padding: DS.Spacing.l, radius: DS.Radius.l)
        .frame(maxWidth: 360)
        .accessibilityElement(children: .contain)
    }

    private func row(_ entry: GamePlan.Entry) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            Text("$\(entry.symbol)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if let levels = entry.levels, !levels.isEmpty {
                    Text(levels)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if (entry.levels ?? "").isEmpty && (entry.note ?? "").isEmpty {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: DS.Spacing.s)

            Tag(text: entry.bias.displayName, systemImage: entry.bias.icon, tint: entry.bias.color)
                .fixedSize()
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sheet

struct GamePlanSheet: View {
    let channelName: String
    let onPost: (GamePlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = GamePlan.defaultTitle()
    @State private var rows: [GamePlan.Entry] = [GamePlan.Entry(symbol: "", bias: .bullish)]

    private static func cleanSymbol(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: "$", with: "")
    }

    /// Rows with a symbol, cleaned up for posting
    private var filledRows: [GamePlan.Entry] {
        rows.compactMap { row in
            let symbol = Self.cleanSymbol(row.symbol)
            guard !symbol.isEmpty else { return nil }
            var entry = row
            entry.symbol = String(symbol.prefix(30))
            entry.levels = row.levels?.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.note = row.note?.trimmingCharacters(in: .whitespacesAndNewlines)
            return entry
        }
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var validationError: String? {
        if trimmedTitle.isEmpty { return "Give the plan a title" }
        if filledRows.isEmpty { return "Add at least one ticker" }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        formLabel("Title")
                        TextField("Game plan", text: $title)
                            .font(.body.weight(.semibold))
                            .cardStyle(padding: DS.Spacing.l)
                            .onChange(of: title) { _, newValue in
                                if newValue.count > ChatText.gamePlanTitleLimit {
                                    title = String(newValue.prefix(ChatText.gamePlanTitleLimit))
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        HStack {
                            formLabel("Tickers")
                            Spacer()
                            Text("\(rows.count) of \(GamePlan.maxTickers)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        ForEach($rows) { $row in
                            rowEditor($row)
                        }
                        if rows.count < GamePlan.maxTickers {
                            Button {
                                withAnimation(.snappy(duration: 0.2)) {
                                    rows.append(GamePlan.Entry(symbol: "", bias: .bullish))
                                }
                            } label: {
                                Label("Add ticker", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PillButtonStyle(kind: .outline))
                        }
                    }

                    if let validationError, rows.contains(where: { !$0.symbol.isEmpty }) || trimmedTitle.isEmpty {
                        Label(validationError, systemImage: "exclamationmark.triangle.fill")
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
            .navigationTitle("Game Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.goldText)
                }
            }
            .safeAreaInset(edge: .bottom) { postBar }
        }
        .presentationDragIndicator(.visible)
    }

    private func formLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .padding(.leading, DS.Spacing.xs)
    }

    private func rowEditor(_ row: Binding<GamePlan.Entry>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.s) {
                Text("$")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("Symbol", text: row.symbol)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                if rows.count > 1 {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            rows.removeAll { $0.id == row.wrappedValue.id }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove ticker")
                }
            }

            HStack(spacing: DS.Spacing.s) {
                ForEach(GamePlan.Bias.allCases) { bias in
                    let isSelected = row.wrappedValue.bias == bias
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        row.wrappedValue.bias = bias
                    } label: {
                        Label(bias.displayName, systemImage: bias.icon)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(isSelected ? bias.color : Color.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Capsule().fill(isSelected ? bias.color.opacity(0.16) : Color.surfaceRaised))
                            .overlay(Capsule().strokeBorder(isSelected ? bias.color.opacity(0.5) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            TextField("Levels (optional), e.g. 180 support / 192 breakout", text: optionalText(row.levels))
                .font(.subheadline.monospacedDigit())
                .padding(.horizontal, DS.Spacing.m)
                .frame(minHeight: 40)
                .background(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous).fill(Color.surfaceRaised))

            TextField("Note (optional)", text: optionalText(row.note), axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...3)
                .padding(.horizontal, DS.Spacing.m)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous).fill(Color.surfaceRaised))
        }
        .cardStyle(padding: DS.Spacing.l)
    }

    private func optionalText(_ binding: Binding<String?>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue ?? "" },
            set: { binding.wrappedValue = $0.isEmpty ? nil : String($0.prefix(200)) }
        )
    }

    private var postBar: some View {
        Button {
            guard validationError == nil else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onPost(GamePlan(title: trimmedTitle, tickers: filledRows))
            dismiss()
        } label: {
            Label("Post to #\(channelName)", systemImage: "map.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(validationError != nil)
        .padding(.horizontal, DS.pageMargin)
        .padding(.vertical, DS.Spacing.s)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
    }
}

#Preview {
    GamePlanCard(plan: GamePlan(title: "Game plan for Mon, Nov 23", tickers: [
        GamePlan.Entry(symbol: "AAPL", bias: .bullish, levels: "180 support / 192 breakout", note: "Watch the open"),
        GamePlan.Entry(symbol: "TSLA", bias: .bearish, levels: "Below 240", note: nil),
        GamePlan.Entry(symbol: "SPY", bias: .neutral, levels: nil, note: "CPI at 8:30")
    ]))
    .padding()
    .screenBackground()
}
