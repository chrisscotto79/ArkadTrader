// File: Tests/ArkadTraderTests/ModelTests/TradeCalloutTests.swift
// Callout result math, auto-close rules, close consistency and price checks.

import XCTest
@testable import ArkadTrader

final class TradeCalloutTests: XCTestCase {

    private func callout(_ direction: TradeCallout.Direction = .long, entry: Double = 100,
                         stop: Double? = nil, target: Double? = nil,
                         status: TradeCallout.Status = .open, exit: Double? = nil,
                         result: Double? = nil, postedAt: Date? = nil) -> TradeCallout {
        var c = TradeCallout(ticker: "AAPL", assetType: .stock, direction: direction, entryPrice: entry,
                             stopPrice: stop, targetPrice: target)
        c.status = status
        c.exitPrice = exit
        c.resultPercent = result
        c.postedAt = postedAt
        return c
    }

    // MARK: Result math

    func testPercentMoveIsSignedForShorts() {
        XCTAssertEqual(callout(.long).percentMove(to: 110), 10, accuracy: 1e-9)
        XCTAssertEqual(callout(.short).percentMove(to: 110), -10, accuracy: 1e-9)
        XCTAssertEqual(callout(.short).percentMove(to: 90), 10, accuracy: 1e-9)
        XCTAssertEqual(callout(entry: 0).percentMove(to: 10), 0)
    }

    func testResultPercentRoundsToTwoDecimals() {
        XCTAssertEqual(CalloutTrackingService.resultPercent(for: callout(.long, entry: 3), exitPrice: 3.1), 3.33)
        XCTAssertEqual(CalloutTrackingService.resultPercent(for: callout(.short, entry: 3), exitPrice: 3.1), -3.33)
    }

    func testFinalPercent() {
        XCTAssertNil(callout(status: .open, exit: 110, result: 10).finalPercent)
        XCTAssertEqual(callout(status: .closed, exit: 110, result: 9.5).finalPercent, 9.5)
        XCTAssertEqual(callout(.short, status: .closed, exit: 110).finalPercent ?? 0, -10, accuracy: 1e-9)
        XCTAssertNil(callout(status: .closed).finalPercent)
        XCTAssertNil(callout(status: .closed, exit: 0).finalPercent)
    }

    func testLivePercentOnlyWhileOpen() {
        var open = callout()
        open.lastPrice = 105
        XCTAssertEqual(open.livePercent ?? 0, 5, accuracy: 1e-9)
        open.lastPrice = 0
        XCTAssertNil(open.livePercent)
        var closed = callout(status: .closed)
        closed.lastPrice = 105
        XCTAssertNil(closed.livePercent)
    }

    func testRiskRewardAndProgress() {
        XCTAssertEqual(callout(stop: 95, target: 115).riskReward ?? 0, 3, accuracy: 1e-9)
        XCTAssertNil(callout(stop: 100, target: 115).riskReward)
        XCTAssertNil(callout(target: 115).riskReward)
        XCTAssertEqual(callout(stop: 95, target: 115).progress(at: 105) ?? -1, 0.5, accuracy: 1e-9)
        XCTAssertEqual(callout(.short, stop: 105, target: 85).progress(at: 95) ?? -1, 0.5, accuracy: 1e-9)
        XCTAssertNil(callout(stop: 100, target: 100).progress(at: 100))
    }

    // MARK: Auto-close

    func testLongAutoClose() {
        let c = callout(.long, stop: 95, target: 110)
        XCTAssertNil(c.autoClose(at: 100))
        XCTAssertEqual(c.autoClose(at: 94)?.status, .stoppedOut)
        XCTAssertEqual(c.autoClose(at: 94)?.exitPrice, 95, "a stop fills at the stop")
        XCTAssertEqual(c.autoClose(at: 111)?.status, .targetHit)
        XCTAssertEqual(c.autoClose(at: 111)?.exitPrice, 110, "a target fills at the target")
        XCTAssertEqual(c.autoClose(at: 95)?.status, .stoppedOut)
        XCTAssertEqual(c.autoClose(at: 110)?.status, .targetHit)
    }

    func testShortAutoClose() {
        let c = callout(.short, stop: 105, target: 90)
        XCTAssertNil(c.autoClose(at: 100))
        XCTAssertEqual(c.autoClose(at: 106)?.status, .stoppedOut)
        XCTAssertEqual(c.autoClose(at: 106)?.exitPrice, 105)
        XCTAssertEqual(c.autoClose(at: 89)?.status, .targetHit)
        XCTAssertEqual(c.autoClose(at: 89)?.exitPrice, 90)
    }

    func testIntradayRangeStopsOutEvenIfPriceRecovered() {
        let long = callout(.long, stop: 95, target: 110)
        XCTAssertEqual(long.autoClose(at: 100, high: 101, low: 94)?.status, .stoppedOut)
        XCTAssertEqual(long.autoClose(at: 100, high: 111, low: 99)?.status, .targetHit)
    }

    func testStopWinsWhenBothLevelsCrossedSameDay() {
        let long = callout(.long, stop: 95, target: 110)
        let result = long.autoClose(at: 100, high: 112, low: 94)
        XCTAssertEqual(result?.status, .stoppedOut)
        XCTAssertEqual(result?.exitPrice, 95)
        let short = callout(.short, stop: 105, target: 90)
        XCTAssertEqual(short.autoClose(at: 100, high: 106, low: 89)?.status, .stoppedOut)
    }

    func testInvalidRangeValuesAreIgnored() {
        let c = callout(.long, stop: 95, target: 110)
        XCTAssertNil(c.autoClose(at: 100, high: .infinity, low: -1))
        XCTAssertNil(c.autoClose(at: 100, high: .nan, low: 0))
    }

    func testAutoCloseRejectsBadPricesAndClosedCallouts() {
        let c = callout(.long, stop: 95, target: 110)
        XCTAssertNil(c.autoClose(at: 0))
        XCTAssertNil(c.autoClose(at: -5))
        XCTAssertNil(c.autoClose(at: .infinity))
        XCTAssertNil(c.autoClose(at: .nan))
        XCTAssertNil(callout(.long, stop: 95, target: 110, status: .closed).autoClose(at: 50))
    }

    func testCalloutWithoutLevelsClosesAfterMaxOpenDays() {
        let now = Date()
        let day: TimeInterval = 86_400
        let old = callout(postedAt: now.addingTimeInterval(-Double(TradeCallout.maxOpenDays) * day - 1))
        let result = old.autoClose(at: 123, now: now)
        XCTAssertEqual(result?.status, .closed)
        XCTAssertEqual(result?.exitPrice, 123)

        let young = callout(postedAt: now.addingTimeInterval(-29 * day))
        XCTAssertNil(young.autoClose(at: 123, now: now))
        XCTAssertNil(callout().autoClose(at: 123, now: now), "no postedAt: never times out")
        XCTAssertNil(callout(target: 200, postedAt: now.addingTimeInterval(-60 * day)).autoClose(at: 123, now: now),
                     "a callout with a level doesn't time out")
    }

    // MARK: Close consistency

    func testConsistentCloseRequiresExitAtTheLevel() {
        XCTAssertTrue(callout(stop: 95, target: 110, status: .targetHit, exit: 110, result: 10).isConsistentClose)
        XCTAssertFalse(callout(stop: 95, target: 110, status: .targetHit, exit: 112, result: 12).isConsistentClose)
        XCTAssertTrue(callout(stop: 95, target: 110, status: .stoppedOut, exit: 95, result: -5).isConsistentClose)
        XCTAssertFalse(callout(stop: 95, target: 110, status: .stoppedOut, exit: 94, result: -6).isConsistentClose)
        XCTAssertTrue(callout(.short, stop: 105, target: 90, status: .targetHit, exit: 90, result: 10).isConsistentClose)
        XCTAssertTrue(callout(status: .closed, exit: 103, result: 3).isConsistentClose)
    }

    func testConsistentResultTolerance() {
        XCTAssertTrue(callout(status: .closed, exit: 110, result: 10.04).isConsistentResult)
        XCTAssertFalse(callout(status: .closed, exit: 110, result: 10.1).isConsistentResult)
        XCTAssertFalse(callout(.short, status: .closed, exit: 110, result: 10).isConsistentResult, "short result must be negative")
        XCTAssertFalse(callout(status: .open, exit: 110, result: 10).isConsistentResult)
        XCTAssertFalse(callout(status: .closed, exit: 110).isConsistentResult)
        XCTAssertFalse(callout(status: .closed, exit: 0, result: -100).isConsistentResult)
    }

    // MARK: Price checks

    func testEntryCheckForLong() {
        XCTAssertNil(TradeCallout.entryCheckError(entry: 100, livePrice: 100, direction: .long))
        XCTAssertNil(TradeCallout.entryCheckError(entry: 99.8, livePrice: 100, direction: .long))
        XCTAssertNil(TradeCallout.entryCheckError(entry: 101.9, livePrice: 100, direction: .long))
        XCTAssertTrue(TradeCallout.entryCheckError(entry: 99.7, livePrice: 100, direction: .long)?.contains("better") ?? false)
        XCTAssertTrue(TradeCallout.entryCheckError(entry: 102.1, livePrice: 100, direction: .long)?.contains("within 2%") ?? false)
    }

    func testEntryCheckForShort() {
        XCTAssertNil(TradeCallout.entryCheckError(entry: 100.2, livePrice: 100, direction: .short))
        XCTAssertNil(TradeCallout.entryCheckError(entry: 98.1, livePrice: 100, direction: .short))
        XCTAssertTrue(TradeCallout.entryCheckError(entry: 100.3, livePrice: 100, direction: .short)?.contains("better") ?? false)
        XCTAssertTrue(TradeCallout.entryCheckError(entry: 97.9, livePrice: 100, direction: .short)?.contains("within 2%") ?? false)
    }

    func testExitCheckMirrorsEntryCheck() {
        XCTAssertNil(TradeCallout.exitCheckError(exit: 100.2, livePrice: 100, direction: .long))
        XCTAssertNotNil(TradeCallout.exitCheckError(exit: 100.3, livePrice: 100, direction: .long))
        XCTAssertNil(TradeCallout.exitCheckError(exit: 98.1, livePrice: 100, direction: .long))
        XCTAssertNotNil(TradeCallout.exitCheckError(exit: 97.9, livePrice: 100, direction: .long))
        XCTAssertNil(TradeCallout.exitCheckError(exit: 99.8, livePrice: 100, direction: .short))
        XCTAssertNotNil(TradeCallout.exitCheckError(exit: 99.7, livePrice: 100, direction: .short))
    }

    func testPriceCheckSkipsWithoutAUsableQuote() {
        XCTAssertNil(TradeCallout.entryCheckError(entry: 500, livePrice: 0, direction: .long))
        XCTAssertNil(TradeCallout.entryCheckError(entry: 500, livePrice: .infinity, direction: .long))
    }

    // MARK: Validation and follow-ups

    func testValidationError() {
        XCTAssertNil(callout(stop: 95, target: 110).validationError)
        XCTAssertNotNil(callout(entry: 0).validationError)
        XCTAssertNotNil(callout(stop: 105).validationError)
        XCTAssertNotNil(callout(target: 90).validationError)
        XCTAssertNil(callout(.short, stop: 105, target: 90).validationError)
        XCTAssertNotNil(callout(.short, stop: 95).validationError)
        var blank = callout()
        blank.ticker = "  "
        XCTAssertEqual(blank.validationError, "Enter a ticker")
    }

    func testCalloutResultFromClosedCallout() {
        XCTAssertNil(CalloutResult(closed: callout(), parentMessageId: "m", exitCheck: .live))
        let closed = callout(.short, status: .stoppedOut, exit: 105, result: -5)
        let result = CalloutResult(closed: closed, parentMessageId: "m", exitCheck: .live)
        XCTAssertEqual(result?.status, .stoppedOut)
        XCTAssertEqual(result?.exitPrice, 105)
        XCTAssertEqual(result?.resultPercent, -5)
        XCTAssertEqual(result?.isWin, false)
        XCTAssertEqual(result?.isPriceChecked, true)
    }

    func testCalloutUpdateFormatShare() {
        XCTAssertEqual(CalloutUpdate.formatShare(50), "50%")
        XCTAssertEqual(CalloutUpdate.formatShare(12.5), "12.5%")
    }

    func testFirestoreRoundTripKeepsTrackRecordFields() {
        var original = callout(.short, entry: 50, stop: 55, target: 40, status: .targetHit, exit: 40, result: 20)
        original.priceCheck = .live
        original.quoteAtPost = 50.1
        let decoded = TradeCallout.fromFirestore(original.toFirestore())
        XCTAssertEqual(decoded?.direction, .short)
        XCTAssertEqual(decoded?.status, .targetHit)
        XCTAssertEqual(decoded?.exitPrice, 40)
        XCTAssertEqual(decoded?.resultPercent, 20)
        XCTAssertEqual(decoded?.priceCheck, .live)
        XCTAssertEqual(decoded?.quoteAtPost, 50.1)
        XCTAssertNil(TradeCallout.fromFirestore(["ticker": "AAPL"]))
    }
}
