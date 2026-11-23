// File: Core/TrackRecord/TraderStats.swift
// A trader's callout record, as written by the server to `traderStats/{uid}`
// (all communities) or `communities/{cid}/traderStats/{uid}` (one community).
// The app only reads these docs.

import Foundation
import SwiftUI
import FirebaseFirestore

struct TraderStats: Identifiable, Equatable {
    /// A trader is ranked, and shows a full record, after this many closed callouts.
    static let minimumClosedCallouts = 5

    let userId: String
    var id: String { userId }

    var calloutsTotal: Int
    var calloutsClosed: Int
    var openCallouts: Int
    var wins: Int
    var losses: Int
    /// 0–1, from wins / calloutsClosed
    var winRate: Double
    var avgReturnPercent: Double
    var totalReturnPercent: Double
    var bestCalloutPercent: Double?
    var worstCalloutPercent: Double?
    var lastCalloutAt: Date?
    var updatedAt: Date?
    var username: String
    var profileImageUrl: String?

    /// Enough closed callouts to be ranked and to show win rate and returns.
    var isRanked: Bool { calloutsClosed >= Self.minimumClosedCallouts }

    var hasCallouts: Bool { calloutsTotal > 0 || calloutsClosed > 0 || openCallouts > 0 }

    /// Win rate as 0–100. Tolerates a server value already written as a percent.
    var winRatePercent: Double { winRate <= 1 ? winRate * 100 : winRate }

    var displayName: String { username.isEmpty ? "trader" : username }

    // MARK: - Firestore

    static func fromFirestore(data: [String: Any], id: String) -> TraderStats {
        let closed = TrackRecordDecode.int(data["calloutsClosed"]) ?? 0
        let wins = TrackRecordDecode.int(data["wins"]) ?? 0
        return TraderStats(
            userId: id,
            calloutsTotal: TrackRecordDecode.int(data["calloutsTotal"]) ?? 0,
            calloutsClosed: closed,
            openCallouts: TrackRecordDecode.int(data["openCallouts"]) ?? 0,
            wins: wins,
            losses: TrackRecordDecode.int(data["losses"]) ?? max(closed - wins, 0),
            winRate: TrackRecordDecode.double(data["winRate"]) ?? (closed > 0 ? Double(wins) / Double(closed) : 0),
            avgReturnPercent: TrackRecordDecode.double(data["avgReturnPercent"]) ?? 0,
            totalReturnPercent: TrackRecordDecode.double(data["totalReturnPercent"]) ?? 0,
            bestCalloutPercent: TrackRecordDecode.double(data["bestCalloutPercent"]),
            worstCalloutPercent: TrackRecordDecode.double(data["worstCalloutPercent"]),
            lastCalloutAt: TrackRecordDecode.date(data["lastCalloutAt"]),
            updatedAt: TrackRecordDecode.date(data["updatedAt"]),
            username: data["username"] as? String ?? "",
            profileImageUrl: data["profileImageUrl"] as? String
        )
    }

    // MARK: - Formatting

    /// "+4.2%" / "-1.8%"
    static func formatPercent(_ value: Double) -> String {
        String(format: "%+.1f%%", value)
    }

    /// "63%"
    static func formatWinRate(_ percent: Double) -> String {
        String(format: "%.0f%%", percent)
    }

    /// Green for gains, red for losses, neutral at zero.
    static func color(for value: Double) -> Color {
        if value > 0 { return .marketGreen }
        if value < 0 { return .marketRed }
        return .primary
    }
}

// MARK: - Decoding helpers

/// Tolerant readers for Firestore values: numbers may arrive as Double, Int or NSNumber,
/// and dates as Timestamp or Date.
enum TrackRecordDecode {
    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: return number.doubleValue
        case let double as Double: return double
        case let int as Int: return Double(int)
        case let string as String: return Double(string)
        default: return nil
        }
    }

    static func int(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: return number.intValue
        case let int as Int: return int
        case let double as Double: return Int(double)
        default: return nil
        }
    }

    static func date(_ value: Any?) -> Date? {
        switch value {
        case let timestamp as Timestamp: return timestamp.dateValue()
        case let date as Date: return date
        default: return nil
        }
    }
}

extension TraderStats {
    /// Plain-language load error. Permission errors mean the server side isn't set up yet.
    static func friendlyLoadMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "FIRFirestoreErrorDomain", nsError.code == 7 {
            return "Callout records aren't available yet."
        }
        return "Check your connection and try again."
    }
}
