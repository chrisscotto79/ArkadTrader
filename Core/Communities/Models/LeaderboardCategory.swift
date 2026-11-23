// File: Core/Communities/Models/LeaderboardCategory.swift
// The ways a callout leaderboard can be sorted. Raw values are the `traderStats` field names.

import Foundation

enum LeaderboardCategory: String, CaseIterable {
    case winRate = "winRate"
    case avgReturn = "avgReturnPercent"
    case totalReturn = "totalReturnPercent"
    case mostCallouts = "calloutsClosed"

    var displayName: String {
        switch self {
        case .winRate: return "Win rate"
        case .avgReturn: return "Average return"
        case .totalReturn: return "Total return"
        case .mostCallouts: return "Most callouts"
        }
    }

    var description: String {
        let minimum = TraderStats.minimumClosedCallouts
        switch self {
        case .winRate: return "Share of closed callouts that made money (\(minimum)+ closed)"
        case .avgReturn: return "Average result per closed callout (\(minimum)+ closed)"
        case .totalReturn: return "Sum of all closed callout results (\(minimum)+ closed)"
        case .mostCallouts: return "Most closed callouts (\(minimum)+ closed)"
        }
    }

    var icon: String {
        switch self {
        case .winRate: return "target"
        case .avgReturn: return "percent"
        case .totalReturn: return "chart.line.uptrend.xyaxis"
        case .mostCallouts: return "megaphone.fill"
        }
    }

    /// The value this board sorts by, highest first
    func sortValue(for stats: TraderStats) -> Double {
        switch self {
        case .winRate: return stats.winRatePercent
        case .avgReturn: return stats.avgReturnPercent
        case .totalReturn: return stats.totalReturnPercent
        case .mostCallouts: return Double(stats.calloutsClosed)
        }
    }
}
