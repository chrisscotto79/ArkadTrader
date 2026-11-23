// File: Tests/ArkadTraderTests/ServiceTests/TrackRecordMathTests.swift
// traderStats aggregation (TrackRecordMath), which mirror docs count (TrackRecordWriter.counts),
// and TraderStats decoding / ranking.

import XCTest
@testable import ArkadTrader

final class TrackRecordMathTests: XCTestCase {

    private func closed(_ result: Double?, exit: Double? = nil, postedAt: Date? = nil) -> TradeCallout {
        var c = TradeCallout(ticker: "AAPL", assetType: .stock, direction: .long, entryPrice: 100)
        c.status = .closed
        c.resultPercent = result
        c.exitPrice = exit
        c.postedAt = postedAt
        return c
    }

    private func open(postedAt: Date? = nil) -> TradeCallout {
        var c = TradeCallout(ticker: "TSLA", assetType: .stock, direction: .short, entryPrice: 200)
        c.postedAt = postedAt
        return c
    }

    // MARK: statsData

    func testAggregatesClosedResults() {
        let callouts = [closed(10), closed(-5), closed(nil), closed(2.5), open()]
        let data = TrackRecordMath.statsData(for: callouts, username: "chris", profileImageUrl: "https://x/y.png")
        XCTAssertEqual(data["calloutsTotal"] as? Int, 5)
        XCTAssertEqual(data["calloutsClosed"] as? Int, 4)
        XCTAssertEqual(data["openCallouts"] as? Int, 1)
        XCTAssertEqual(data["wins"] as? Int, 2)
        XCTAssertEqual(data["losses"] as? Int, 2, "a flat close counts as not-a-win")
        XCTAssertEqual(data["winRate"] as? Double, 0.5)
        XCTAssertEqual(data["avgReturnPercent"] as? Double, 1.88)  // 7.5 / 4 = 1.875
        XCTAssertEqual(data["totalReturnPercent"] as? Double, 7.5)
        XCTAssertEqual(data["bestCalloutPercent"] as? Double, 10)
        XCTAssertEqual(data["worstCalloutPercent"] as? Double, -5)
        XCTAssertEqual(data["username"] as? String, "chris")
        XCTAssertEqual(data["profileImageUrl"] as? String, "https://x/y.png")
        XCTAssertNotNil(data["updatedAt"])
    }

    func testWinRateIsAFractionRoundedToFourPlaces() {
        let data = TrackRecordMath.statsData(for: [closed(1), closed(2), closed(-1)], username: "u", profileImageUrl: nil)
        XCTAssertEqual(data["winRate"] as? Double, 0.6667)
        let winRate = data["winRate"] as? Double ?? -1
        XCTAssertTrue((0...1).contains(winRate))
    }

    func testClosedCalloutWithoutResultFallsBackToExitPrice() {
        let data = TrackRecordMath.statsData(for: [closed(nil, exit: 110)], username: "u", profileImageUrl: nil)
        XCTAssertEqual(data["wins"] as? Int, 1)
        XCTAssertEqual(data["totalReturnPercent"] as? Double, 10)
    }

    func testEmptyAndOpenOnlyRecords() {
        let empty = TrackRecordMath.statsData(for: [], username: "u", profileImageUrl: "")
        XCTAssertEqual(empty["calloutsClosed"] as? Int, 0)
        XCTAssertEqual(empty["winRate"] as? Double, 0)
        XCTAssertEqual(empty["avgReturnPercent"] as? Double, 0)
        XCTAssertNil(empty["bestCalloutPercent"])
        XCTAssertNil(empty["worstCalloutPercent"])
        XCTAssertNil(empty["lastCalloutAt"])
        XCTAssertNil(empty["profileImageUrl"], "an empty image URL is left out")

        let openOnly = TrackRecordMath.statsData(for: [open(), open()], username: "u", profileImageUrl: nil)
        XCTAssertEqual(openOnly["openCallouts"] as? Int, 2)
        XCTAssertEqual(openOnly["losses"] as? Int, 0)
    }

    func testLastCalloutAtIsSetFromPostedAt() {
        let data = TrackRecordMath.statsData(for: [open(postedAt: Date())], username: "u", profileImageUrl: nil)
        XCTAssertNotNil(data["lastCalloutAt"])
    }

    // MARK: Which mirror docs count

    private func mirror(_ overrides: [String: Any] = [:]) -> [String: Any] {
        var data: [String: Any] = ["ticker": "AAPL", "entryPrice": 100.0, "direction": "long",
                                   "status": "open", "priceCheck": "live"]
        data.merge(overrides) { $1 }
        return data
    }

    func testOpenPriceCheckedCalloutCounts() {
        XCTAssertNotNil(TrackRecordWriter.counts(mirror()))
    }

    func testUncheckedEntryOrExitDoesNotCount() {
        XCTAssertNil(TrackRecordWriter.counts(mirror(["priceCheck": "unchecked"])))
        XCTAssertNil(TrackRecordWriter.counts(mirror().filter { $0.key != "priceCheck" }))
        XCTAssertNil(TrackRecordWriter.counts(mirror(["status": "closed", "exitPrice": 110.0, "resultPercent": 10.0,
                                                      "exitCheck": "unchecked"])))
    }

    func testClosedCalloutCountsOnlyWithAConsistentResult() {
        XCTAssertNotNil(TrackRecordWriter.counts(mirror(["status": "closed", "exitPrice": 110.0,
                                                         "resultPercent": 10.0, "exitCheck": "live"])))
        XCTAssertNil(TrackRecordWriter.counts(mirror(["status": "closed", "exitPrice": 110.0, "resultPercent": 25.0])))
        XCTAssertNil(TrackRecordWriter.counts(mirror(["status": "target_hit", "exitPrice": 110.0])))
    }

    // MARK: TraderStats

    func testIsRankedNeedsFiveClosedCallouts() {
        XCTAssertEqual(TraderStats.minimumClosedCallouts, 5)
        XCTAssertFalse(TraderStats.fromFirestore(data: ["calloutsClosed": 4], id: "u").isRanked)
        XCTAssertTrue(TraderStats.fromFirestore(data: ["calloutsClosed": 5], id: "u").isRanked)
    }

    func testFromFirestoreDerivesMissingFields() {
        let stats = TraderStats.fromFirestore(data: ["calloutsClosed": 4, "wins": 3, "calloutsTotal": 6], id: "u")
        XCTAssertEqual(stats.losses, 1)
        XCTAssertEqual(stats.winRate, 0.75, accuracy: 1e-9)
        XCTAssertEqual(stats.winRatePercent, 75, accuracy: 1e-9)
        XCTAssertEqual(stats.displayName, "trader")
        XCTAssertTrue(stats.hasCallouts)
        XCTAssertFalse(TraderStats.fromFirestore(data: [:], id: "u").hasCallouts)
    }

    func testWinRatePercentToleratesPercentValues() {
        XCTAssertEqual(TraderStats.fromFirestore(data: ["winRate": 0.6], id: "u").winRatePercent, 60, accuracy: 1e-9)
        XCTAssertEqual(TraderStats.fromFirestore(data: ["winRate": 60.0], id: "u").winRatePercent, 60, accuracy: 1e-9)
    }

    func testStatsDataRoundTripsThroughTraderStats() {
        let callouts = [closed(10), closed(-5), closed(3), closed(4), closed(-1), open()]
        let data = TrackRecordMath.statsData(for: callouts, username: "chris", profileImageUrl: nil)
        let stats = TraderStats.fromFirestore(data: data, id: "u")
        XCTAssertTrue(stats.isRanked)
        XCTAssertEqual(stats.calloutsClosed, 5)
        XCTAssertEqual(stats.wins, 3)
        XCTAssertEqual(stats.losses, 2)
        XCTAssertEqual(stats.winRatePercent, 60, accuracy: 1e-9)
        XCTAssertEqual(stats.totalReturnPercent, 11, accuracy: 1e-9)
        XCTAssertEqual(stats.avgReturnPercent, 2.2, accuracy: 1e-9)
        XCTAssertEqual(stats.bestCalloutPercent, 10)
        XCTAssertEqual(stats.worstCalloutPercent, -5)
    }

    func testDecodeHelpers() {
        XCTAssertEqual(TrackRecordDecode.int(3.0), 3)
        XCTAssertEqual(TrackRecordDecode.int(NSNumber(value: 7)), 7)
        XCTAssertNil(TrackRecordDecode.int("3"))
        XCTAssertEqual(TrackRecordDecode.double("1.5"), 1.5)
        XCTAssertEqual(TrackRecordDecode.double(2), 2)
        XCTAssertNil(TrackRecordDecode.double(nil))
        let now = Date()
        XCTAssertEqual(TrackRecordDecode.date(now), now)
        XCTAssertNil(TrackRecordDecode.date("today"))
    }

    func testFormatting() {
        XCTAssertEqual(TraderStats.formatPercent(4.2), "+4.2%")
        XCTAssertEqual(TraderStats.formatPercent(-1.8), "-1.8%")
        XCTAssertEqual(TraderStats.formatWinRate(63.4), "63%")
    }
}
