// File: Core/Communities/Views/Leaderboard/LeaderboardRow.swift
// Shared pieces for community and global leaderboards: the row, the category chips and the timeframe picker.

import SwiftUI

extension LeaderboardCategory {
    var shortName: String {
        switch self {
        case .consistencyMasters: return "Win Rate"
        case .profitKings: return "P&L"
        case .volumeTraders: return "Most Active"
        case .riskMasters: return "Profit Factor"
        }
    }

    /// The headline number for an entry on this board
    func primaryValue(for entry: CommunityLeaderboardEntry) -> String {
        switch self {
        case .consistencyMasters: return String(format: "%.0f%%", entry.winRate)
        case .profitKings: return entry.totalProfitLoss.asSignedCurrency
        case .volumeTraders: return "\(entry.totalTrades)"
        case .riskMasters: return entry.profitFactor >= 99 ? "∞" : String(format: "%.2f", entry.profitFactor)
        }
    }

    var primaryLabel: String {
        switch self {
        case .consistencyMasters: return "win rate"
        case .profitKings: return "realized"
        case .volumeTraders: return "trades"
        case .riskMasters: return "profit factor"
        }
    }
}

extension Double {
    /// "+$1,234" / "-$56"
    var asSignedCurrency: String {
        let formatted = abs(self).formatted(.currency(code: "USD").precision(.fractionLength(0)))
        return (self < 0 ? "-" : "+") + formatted
    }
}

struct LeaderboardRow: View {
    let entry: CommunityLeaderboardEntry
    let category: LeaderboardCategory
    var isCurrentUser = false

    var body: some View {
        HStack(spacing: 12) {
            RankBadge(rank: entry.rank)

            UserAvatar(username: entry.username, imageURL: entry.profileImageUrl, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(entry.username)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if entry.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    if isCurrentUser {
                        Text("You")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.arkadGold))
                    }
                }
                Text(secondaryLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(category.primaryValue(for: entry))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundColor(primaryColor)
                Text(category.primaryLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isCurrentUser ? Color.arkadGold.opacity(0.1) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isCurrentUser ? Color.arkadGold.opacity(0.5) : .clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.username), \(category.primaryValue(for: entry)) \(category.primaryLabel)")
    }

    /// Supporting stats that aren't already the headline number
    private var secondaryLine: String {
        let trades = "\(entry.totalTrades) trade\(entry.totalTrades == 1 ? "" : "s")"
        let winRate = String(format: "%.0f%% wins", entry.winRate)
        let pnl = entry.totalProfitLoss.asSignedCurrency
        switch category {
        case .consistencyMasters: return "\(trades) · \(pnl)"
        case .profitKings: return "\(trades) · \(winRate)"
        case .volumeTraders: return "\(winRate) · \(pnl)"
        case .riskMasters: return "\(trades) · \(pnl)"
        }
    }

    private var primaryColor: Color {
        switch category {
        case .profitKings: return entry.totalProfitLoss >= 0 ? .marketGreen : .marketRed
        default: return .primary
        }
    }
}

struct RankBadge: View {
    let rank: Int

    var body: some View {
        Group {
            if let color = medalColor {
                Circle()
                    .fill(color.gradient)
                    .overlay(
                        Text("\(rank)")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.white)
                    )
            } else {
                Text("\(rank)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 28, height: 28)
    }

    private var medalColor: Color? {
        switch rank {
        case 1: return .arkadGold
        case 2: return Color(white: 0.65)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.25)
        default: return nil
        }
    }
}

struct LeaderboardFilterBar: View {
    @Binding var category: LeaderboardCategory
    @Binding var timeframe: LeaderboardTimeframe
    var horizontalPadding: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LeaderboardCategory.allCases, id: \.self) { item in
                        Button {
                            category = item
                        } label: {
                            Label(item.shortName, systemImage: item.icon)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(category == item ? Color.arkadGold : Color(.secondarySystemGroupedBackground))
                                )
                                .foregroundColor(category == item ? .black : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }

            Picker("Timeframe", selection: $timeframe) {
                ForEach(LeaderboardTimeframe.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, horizontalPadding)

            Text(category.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, horizontalPadding)
        }
    }
}
