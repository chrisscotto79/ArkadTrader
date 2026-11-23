// File: Core/Learn/PositionSizeCalculatorView.swift
// Position-size calculator: account size, risk %, entry and stop give the number of shares
// and the dollars at risk. Works for longs (stop below entry) and shorts (stop above).

import SwiftUI

struct PositionSizeCalculatorView: View {
    @State private var accountText = ""
    @State private var riskText = "1"
    @State private var entryText = ""
    @State private var stopText = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case account, risk, entry, stop }

    private let riskPresets: [Double] = [0.5, 1, 2]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                Text("Work out how many shares to buy so that, if your stop is hit, you lose only the amount you chose.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                inputsCard
                resultCard
                LearnDisclaimer()
            }
            .padding(.horizontal, DS.pageMargin)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationTitle("Position size")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }

    // MARK: - Inputs

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            numberField("Account size", prefix: "$", placeholder: "10,000", text: $accountText, field: .account)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                numberField("Risk per trade", suffix: "%", placeholder: "1", text: $riskText, field: .risk)
                HStack(spacing: DS.Spacing.s) {
                    ForEach(riskPresets, id: \.self) { preset in
                        Chip(title: "\(preset.formatted(.number.precision(.fractionLength(0...1))))%", isSelected: riskPercent == preset) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            riskText = preset.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
                        }
                    }
                }
            }

            HStack(spacing: DS.Spacing.m) {
                numberField("Entry price", prefix: "$", placeholder: "50.00", text: $entryText, field: .entry)
                numberField("Stop price", prefix: "$", placeholder: "48.00", text: $stopText, field: .stop)
            }
        }
        .cardStyle()
    }

    private func numberField(
        _ title: String,
        prefix: String? = nil,
        suffix: String? = nil,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                if let prefix {
                    Text(prefix).foregroundStyle(.secondary)
                }
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: field)
                if let suffix {
                    Text(suffix).foregroundStyle(.secondary)
                }
            }
            .arkadNumber(17, weight: .semibold)
            .padding(.horizontal, DS.Spacing.m)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                    .fill(Color.surfaceRaised)
            )
            .onTapGesture { focusedField = field }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Result

    @ViewBuilder
    private var resultCard: some View {
        if let result {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.isShort ? "Shares to short" : "Shares to buy")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(result.wholeShares.formatted())
                            .arkadNumber(40)
                            .foregroundStyle(Color.primary)
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 0)
                    Tag(text: result.isShort ? "Short" : "Long",
                        systemImage: result.isShort ? "arrow.down.right" : "arrow.up.right",
                        tint: result.isShort ? .marketRed : .marketGreen)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.m), GridItem(.flexible())], spacing: DS.Spacing.m) {
                    resultTile("Dollars at risk", value: currency(result.dollarsAtRisk))
                    resultTile("Risk per share", value: currency(result.riskPerShare))
                    resultTile("Position value", value: currency(result.positionValue))
                    resultTile("Share of account", value: "\(result.percentOfAccount.formatted(.number.precision(.fractionLength(0...1))))%")
                }

                if result.wholeShares == 0 {
                    note("Your risk amount is smaller than the risk on one share. Use a closer stop, a fractional share, or skip the trade.", systemImage: "exclamationmark.triangle.fill", tint: .warning)
                }
                if result.positionValue > result.account {
                    note("This position is bigger than your account, so it would need margin. Many traders reduce size instead.", systemImage: "exclamationmark.triangle.fill", tint: .warning)
                }
                if result.riskPercent > 2 {
                    note("You're risking more than 2% of your account on one trade. Many traders stay at 1–2% or less.", systemImage: "info.circle.fill", tint: .goldText)
                }
                note("Gaps and slippage can make a real loss bigger than planned.", systemImage: "info.circle", tint: .secondary)
            }
            .cardStyle()
            .animation(.snappy(duration: 0.2), value: result)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("Your result", systemImage: "plusminus.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(missingInputMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    private func resultTile(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .arkadNumber(17)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                .fill(Color.surfaceRaised)
        )
    }

    private func note(_ text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
        }
    }

    // MARK: - Math

    private struct Result: Equatable {
        let account: Double
        let riskPercent: Double
        let riskPerShare: Double
        let wholeShares: Int
        let dollarsAtRisk: Double
        let positionValue: Double
        let percentOfAccount: Double
        let isShort: Bool
    }

    private var riskPercent: Double? { Self.parse(riskText) }

    private var result: Result? {
        guard let account = Self.parse(accountText), account > 0,
              let riskPercent, riskPercent > 0, riskPercent <= 100,
              let entry = Self.parse(entryText), entry > 0,
              let stop = Self.parse(stopText), stop > 0, stop != entry else { return nil }

        let riskPerShare = abs(entry - stop)
        let budget = account * riskPercent / 100
        let shares = Int((budget / riskPerShare).rounded(.down))
        let positionValue = Double(shares) * entry

        return Result(
            account: account,
            riskPercent: riskPercent,
            riskPerShare: riskPerShare,
            wholeShares: shares,
            dollarsAtRisk: Double(shares) * riskPerShare,
            positionValue: positionValue,
            percentOfAccount: positionValue / account * 100,
            isShort: stop > entry
        )
    }

    private var missingInputMessage: String {
        if let entry = Self.parse(entryText), let stop = Self.parse(stopText), entry == stop {
            return "Your stop needs to be different from your entry."
        }
        return "Enter your account size, risk, entry and stop to see how many shares to buy."
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }

    /// Accepts "10,000", "10000", "48.5" and the user's local decimal separator.
    private static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        if let number = formatter.number(from: trimmed) {
            return number.doubleValue
        }
        return Double(trimmed.replacingOccurrences(of: ",", with: ""))
    }
}

#Preview {
    NavigationStack {
        PositionSizeCalculatorView()
    }
}
