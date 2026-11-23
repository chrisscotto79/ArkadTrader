// File: Core/Communities/Models/LeaderboardEntry.swift
// One trader's row on a community or global leaderboard, built from their verified callout record.

import Foundation

struct CommunityLeaderboardEntry: Identifiable, Equatable {
    let stats: TraderStats
    var rank: Int

    var id: String { stats.userId }
    var userId: String { stats.userId }
    var username: String { stats.displayName }
    var profileImageUrl: String? { stats.profileImageUrl }
}
