// File: Core/Portfolio/Views/StartingCapitalSheet.swift
// Asks for the account's starting balance so account value and returns can be calculated.

import SwiftUI

struct StartingCapitalSheet: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    @State private var startingCapitalInput = ""
    @FocusState private var isInputFocused: Bool

    private let quickAmounts: [Double] = [1_000, 5_000, 10_000, 25_000, 50_000, 100_000]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    intro
                    amountCard
                    quickAmountChips
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.s)
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { actions }
            .screenBackground()
            .navigationTitle("Starting balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    IconButton(systemName: "xmark", accessibilityLabel: "Close", size: 32) { dismiss() }
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            IconWell(systemName: "banknote", size: 48)
            Text("Set your starting balance")
                .font(.title2.weight(.bold))
            Text("Arkad uses it to work out your account value and returns. You can deposit or withdraw later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Amount")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("$")
                    .arkadNumber(34)
                    .foregroundStyle(.secondary)
                TextField("0", text: $startingCapitalInput)
                    .keyboardType(.decimalPad)
                    .arkadNumber(34)
                    .focused($isInputFocused)
            }
        }
        .cardStyle()
    }

    private var quickAmountChips: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.s), count: 3), spacing: DS.Spacing.s) {
            ForEach(quickAmounts, id: \.self) { amount in
                Button(amount.asWholeCurrency) {
                    UISelectionFeedbackGenerator().selectionChanged()
                    startingCapitalInput = String(format: "%.0f", amount)
                }
                .buttonStyle(PillButtonStyle(kind: .neutral))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: DS.Spacing.xs) {
            Button("Set balance", action: setStartingCapital)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(parsedAmount == nil)
            Button("Skip for now") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(height: 40)
        }
        .padding(.horizontal, DS.pageMargin)
        .padding(.top, DS.Spacing.m)
        .padding(.bottom, DS.Spacing.xs)
        .background(
            Color.appBackground
                .overlay(alignment: .top) { Divider().overlay(Color.hairline) }
                .ignoresSafeArea()
        )
    }

    private var parsedAmount: Double? {
        guard let amount = AssetTerms.parseNumber(startingCapitalInput), amount > 0 else { return nil }
        return amount
    }

    private func setStartingCapital() {
        guard let amount = parsedAmount else { return }
        portfolioViewModel.setUserStartingCapital(amount)
        // Errors surface on the Portfolio screen's alert
        dismiss()
    }
}
