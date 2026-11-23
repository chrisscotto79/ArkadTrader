// File: Core/Communities/Views/Leaderboard/LeaderboardRow.swift
// Shared pieces for community and global leaderboards: the ranked list with a top-three podium,
// the row, the rank badge and the category / timeframe filters.

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

    /// Colour of the headline number (P&L is green or red, everything else neutral)
    func primaryColor(for entry: CommunityLeaderboardEntry) -> Color {
        switch self {
        case .profitKings:
            if entry.totalProfitLoss > 0 { return .marketGreen }
            if entry.totalProfitLoss < 0 { return .marketRed }
            return .primary
        default:
            return .primary
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

// MARK: - Ranked list

/// Top three on a podium card, everyone else in a card list below.
struct LeaderboardRankingList: View {
    let entries: [CommunityLeaderboardEntry]
    let category: LeaderboardCategory
    let currentUserId: String?
    let onSelect: (CommunityLeaderboardEntry) -> Void

    private var showsPodium: Bool { entries.count >= 3 }
    private var listEntries: [CommunityLeaderboardEntry] {
        showsPodium ? Array(entries.dropFirst(3)) : entries
    }

    var body: some View {
        VStack(spacing: DS.Spacing.m) {
            if showsPodium {
                LeaderboardPodium(
                    entries: Array(entries.prefix(3)),
                    category: category,
                    currentUserId: currentUserId,
                    onSelect: onSelect
                )
            }

            if !listEntries.isEmpty {
                CommunityCardList(items: listEntries, dividerInset: 96) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        LeaderboardRow(entry: entry, category: category, isCurrentUser: entry.userId == currentUserId)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }
}

/// The top three traders side by side, first place in the middle.
struct LeaderboardPodium: View {
    let entries: [CommunityLeaderboardEntry]
    let category: LeaderboardCategory
    let currentUserId: String?
    let onSelect: (CommunityLeaderboardEntry) -> Void

    /// Display order: 2nd, 1st, 3rd
    private var ordered: [CommunityLeaderboardEntry] {
        guard entries.count == 3 else { return entries }
        return [entries[1], entries[0], entries[2]]
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.s) {
            ForEach(ordered) { entry in
                Button {
                    onSelect(entry)
                } label: {
                    column(entry)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .cardStyle(padding: DS.Spacing.l)
    }

    private func column(_ entry: CommunityLeaderboardEntry) -> some View {
        let isFirst = entry.rank == 1
        let isMe = entry.userId == currentUserId
        return VStack(spacing: DS.Spacing.s) {
            UserAvatar(username: entry.username, imageURL: entry.profileImageUrl, size: isFirst ? 64 : 50)
                .overlay(alignment: .bottom) {
                    RankBadge(rank: entry.rank, size: 24)
                        .overlay(Circle().strokeBorder(Color.surface, lineWidth: 2))
                        .offset(y: 10)
                }
                .padding(.bottom, 6)

            VStack(spacing: 2) {
                Text(isMe ? "You" : entry.username)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(category.primaryValue(for: entry))
                    .arkadNumber(isFirst ? 18 : 15)
                    .foregroundStyle(category.primaryColor(for: entry))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(category.primaryLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.m)
        .padding(.horizontal, DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(isFirst ? Color.goldTint : Color.clear)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.username), \(category.primaryValue(for: entry)) \(category.primaryLabel)")
    }
}

// MARK: - Row

struct LeaderboardRow: View {
    let entry: CommunityLeaderboardEntry
    let category: LeaderboardCategory
    var isCurrentUser = false

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            RankBadge(rank: entry.rank)

            UserAvatar(username: entry.username, imageURL: entry.profileImageUrl, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.username)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    if entry.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.goldText)
                    }
                    if isCurrentUser {
                        Tag(text: "You")
                    }
                }
                Text(secondaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Spacing.s)

            VStack(alignment: .trailing, spacing: 2) {
                Text(category.primaryValue(for: entry))
                    .arkadNumber(16)
                    .foregroundStyle(category.primaryColor(for: entry))
                    .lineLimit(1)
                Text(category.primaryLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DS.Spacing.m)
        .padding(.horizontal, DS.Spacing.l)
        .background(isCurrentUser ? Color.goldTint : Color.clear)
        .contentShape(Rectangle())
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
}

// MARK: - Rank badge

struct RankBadge: View {
    let rank: Int
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let medal {
                Circle()
                    .fill(medal.fill)
                    .overlay(
                        Text("\(rank)")
                            .arkadNumber(size * 0.48, weight: .heavy)
                            .foregroundStyle(medal.text)
                    )
            } else {
                Text("\(rank)")
                    .arkadNumber(15, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var medal: (fill: Color, text: Color)? {
        switch rank {
        case 1: return (.arkadGold, .onGold)
        case 2: return (Color(red: 0.78, green: 0.79, blue: 0.81), .black)
        case 3: return (Color(red: 0.80, green: 0.52, blue: 0.30), .white)
        default: return nil
        }
    }
}

// MARK: - Filters

/// Category chips, timeframe switcher and a one-line explanation of the board.
/// Place it inside a container that already has the page margin; the chips scroll edge to edge.
struct LeaderboardFilterBar: View {
    @Binding var category: LeaderboardCategory
    @Binding var timeframe: LeaderboardTimeframe

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.s) {
                    ForEach(LeaderboardCategory.allCases, id: \.self) { item in
                        Chip(title: item.shortName, systemImage: item.icon, isSelected: category == item) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            category = item
                        }
                    }
                }
                .padding(.horizontal, DS.pageMargin)
            }
            .padding(.horizontal, -DS.pageMargin)

            SegmentedPicker(
                options: LeaderboardTimeframe.allCases,
                selection: $timeframe,
                title: { $0.displayName }
            )

            Text(category.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
