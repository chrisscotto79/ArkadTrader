// File: Core/Home/Views/Cards/TradeCardView.swift
// A followed trader's public trade in the Following feed.

import SwiftUI

// MARK: - Trade Card View
/// A followed trader's public trade in the Following feed.
struct TradeCardView: View {
    let trade: Trade
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var trader: User?
    @State private var showProfile = false

    private var traderName: String {
        trader?.username ?? ""
    }

    /// "@name opened AAPL" once the trader has loaded, "Opened AAPL" until then.
    private var title: String {
        let action = trade.isOpen ? "opened" : "closed"
        if let trader {
            return "@\(trader.username) \(action) \(trade.ticker)"
        }
        return "\(action.capitalized) \(trade.ticker)"
    }

    private var eventDate: Date {
        trade.isOpen ? trade.entryDate : (trade.exitDate ?? trade.entryDate)
    }

    private var quantityLabel: String {
        trade.tradeType == .option ? "Contracts" : "Shares"
    }

    private var isGain: Bool { trade.profitLoss >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            header
            if !trade.isOpen {
                resultRow
            }
            statsRow
            if let notes = trade.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardStyle()
        .task(id: trade.userId) {
            guard trader == nil else { return }
            trader = try? await authService.getUserById(userId: trade.userId)
        }
        .sheet(isPresented: $showProfile) {
            if let trader {
                OtherUserProfileView(user: trader)
                    .environmentObject(authService)
            }
        }
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.m) {
            Button {
                if trader != nil { showProfile = true }
            } label: {
                UserAvatar(username: traderName, imageURL: trader?.profileImageUrl, size: 42)
            }
            .buttonStyle(PressableStyle())
            .disabled(trader == nil)
            .accessibilityLabel(trader.map { "Open @\($0.username)'s profile" } ?? "Trader")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text("\(trade.tradeType.displayName) · \(eventDate.feedRelativeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Tag(
                text: trade.isOpen ? "Open" : "Closed",
                systemImage: trade.isOpen ? "circle.fill" : "checkmark",
                tint: trade.isOpen ? .goldText : .secondary
            )
        }
    }

    /// Closed trades lead with the result.
    private var resultRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
            Text(trade.profitLoss.asCurrencyWithSign)
                .arkadNumber(24)
                .foregroundStyle(isGain ? Color.marketGreen : Color.marketRed)
            ChangePill(
                text: String(format: "%+.1f%%", trade.profitLossPercentage),
                isPositive: isGain
            )
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat("Entry", trade.entryPrice.formatted(.currency(code: "USD")))
            if let exitPrice = trade.exitPrice, !trade.isOpen {
                divider
                stat("Exit", exitPrice.formatted(.currency(code: "USD")))
            }
            divider
            stat(quantityLabel, trade.quantity.quantityString)
        }
        .padding(.vertical, DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(Color.surfaceRaised)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(width: 1, height: 28)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .arkadNumber(15, weight: .semibold)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
