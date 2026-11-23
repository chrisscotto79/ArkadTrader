// File: Tests/ArkadTraderTests/ModelTests/TradeTests.swift
// Trade P&L signed by side, delete window, and TradeStats / publicRecord.

import XCTest
@testable import ArkadTrader

final class TradeTests: XCTestCase {

    private func makeTrade(side: TradeSide = .long, entry: Double = 100, quantity: Double = 10,
                           exit: Double? = nil, current: Double? = nil,
                           isPublic: Bool = true, proof: TradeProof = .priceChecked,
                           id: String = UUID().uuidString) -> Trade {
        var trade = Trade(ticker: "aapl", tradeType: .stock, entryPrice: entry, quantity: quantity, userId: "u1")
        trade.id = id
        trade.side = side
        trade.isPublic = isPublic
        trade.proof = proof
        if let current { trade.currentPrice = current }
        if let exit { trade.close(at: exit, on: Date(timeIntervalSinceNow: -3 * 86_400)) }
        return trade
    }

    // MARK: Basics

    func testInitUppercasesTickerAndStartsOpenAtEntry() {
        let trade = makeTrade()
        XCTAssertEqual(trade.ticker, "AAPL")
        XCTAssertTrue(trade.isOpen)
        XCTAssertEqual(trade.currentPrice, 100)
        XCTAssertEqual(trade.side, .long)
    }

    func testCloseSetsExitAndClearsLivePrice() {
        let trade = makeTrade(exit: 110)
        XCTAssertFalse(trade.isOpen)
        XCTAssertEqual(trade.exitPrice, 110)
        XCTAssertNil(trade.currentPrice)
    }

    // MARK: Realized P&L

    func testLongProfitAndLoss() {
        XCTAssertEqual(makeTrade(side: .long, exit: 110).profitLoss, 100, accuracy: 1e-9)
        XCTAssertEqual(makeTrade(side: .long, exit: 110).profitLossPercentage, 10, accuracy: 1e-9)
        XCTAssertEqual(makeTrade(side: .long, exit: 90).profitLoss, -100, accuracy: 1e-9)
        XCTAssertEqual(makeTrade(side: .long, exit: 90).profitLossPercentage, -10, accuracy: 1e-9)
    }

    func testShortProfitAndLossAreSignedBySide() {
        XCTAssertEqual(makeTrade(side: .short, exit: 90).profitLoss, 100, accuracy: 1e-9)
        XCTAssertEqual(makeTrade(side: .short, exit: 90).profitLossPercentage, 10, accuracy: 1e-9)
        XCTAssertEqual(makeTrade(side: .short, exit: 110).profitLoss, -100, accuracy: 1e-9)
        XCTAssertEqual(makeTrade(side: .short, exit: 110).profitLossPercentage, -10, accuracy: 1e-9)
    }

    func testFractionalQuantity() {
        XCTAssertEqual(makeTrade(entry: 50_000, quantity: 0.01, exit: 51_000).profitLoss, 10, accuracy: 1e-9)
    }

    func testOpenTradeHasNoRealizedPL() {
        let trade = makeTrade(current: 150)
        XCTAssertEqual(trade.profitLoss, 0)
        XCTAssertEqual(trade.profitLossPercentage, 0)
    }

    func testZeroEntryPriceGuardsPercentages() {
        XCTAssertEqual(makeTrade(entry: 0, exit: 10).profitLossPercentage, 0)
        XCTAssertEqual(Trade.returnPercent(side: .long, entry: 0, exit: 10), 0)
        XCTAssertEqual(Trade.returnPercent(side: .short, entry: -5, exit: 10), 0)
        XCTAssertEqual(makeTrade(entry: 0, current: 10).unrealizedPLPercentage, 0)
    }

    func testStaticHelpers() {
        XCTAssertEqual(Trade.profitLoss(side: .short, entry: 20, exit: 15, quantity: 3), 15, accuracy: 1e-9)
        XCTAssertEqual(Trade.returnPercent(side: .short, entry: 20, exit: 15), 25, accuracy: 1e-9)
    }

    // MARK: Unrealized P&L

    func testUnrealizedPLSignedBySide() {
        XCTAssertEqual(makeTrade(side: .long, quantity: 2, current: 120).unrealizedPL, 40, accuracy: 1e-9)
        XCTAssertEqual(makeTrade(side: .short, quantity: 2, current: 120).unrealizedPL, -40, accuracy: 1e-9)
        XCTAssertEqual(makeTrade(side: .short, quantity: 2, current: 120).unrealizedPLPercentage, -20, accuracy: 1e-9)
    }

    func testUnrealizedPLNeedsALivePriceAndAnOpenTrade() {
        var noPrice = makeTrade()
        noPrice.currentPrice = nil
        XCTAssertEqual(noPrice.unrealizedPL, 0)
        XCTAssertEqual(makeTrade(current: 0).unrealizedPL, 0)
        XCTAssertEqual(makeTrade(exit: 120).unrealizedPL, 0)
    }

    func testCurrentValueAndStatusText() {
        XCTAssertEqual(makeTrade(quantity: 2, current: 120).currentValue, 240, accuracy: 1e-9)
        XCTAssertEqual(makeTrade(side: .short, quantity: 2, exit: 80).currentValue, 240, accuracy: 1e-9)
        XCTAssertEqual(makeTrade().statusText, "OPEN")
        XCTAssertEqual(makeTrade(exit: 101).statusText, "PROFIT")
        XCTAssertEqual(makeTrade(exit: 100).statusText, "PROFIT")
        XCTAssertEqual(makeTrade(exit: 99).statusText, "LOSS")
    }

    func testRiskRewardRatio() {
        var trade = makeTrade(quantity: 1)
        trade.setStopLoss(95)
        trade.setTakeProfit(115)
        XCTAssertEqual(trade.riskAmount, 5, accuracy: 1e-9)
        XCTAssertEqual(trade.potentialReward, 15, accuracy: 1e-9)
        XCTAssertEqual(trade.riskRewardRatio, 3, accuracy: 1e-9)
    }

    // MARK: Side validation

    func testStopAndTargetSideProblems() {
        XCTAssertNil(TradeSide.long.stopLossProblem(stop: 95, entry: 100))
        XCTAssertNotNil(TradeSide.long.stopLossProblem(stop: 100, entry: 100))
        XCTAssertNil(TradeSide.short.stopLossProblem(stop: 105, entry: 100))
        XCTAssertNotNil(TradeSide.short.stopLossProblem(stop: 95, entry: 100))
        XCTAssertNil(TradeSide.long.takeProfitProblem(target: 110, entry: 100))
        XCTAssertNotNil(TradeSide.long.takeProfitProblem(target: 90, entry: 100))
        XCTAssertNil(TradeSide.short.takeProfitProblem(target: 90, entry: 100))
        XCTAssertNotNil(TradeSide.short.takeProfitProblem(target: 100, entry: 100))
    }

    // MARK: Proof and deletion

    func testProofFromFirestoreValue() {
        XCTAssertEqual(TradeProof(firestoreValue: "verified"), .verified)
        XCTAssertEqual(TradeProof(firestoreValue: "price_checked"), .priceChecked)
        XCTAssertEqual(TradeProof(firestoreValue: "bogus"), .selfReported)
        XCTAssertEqual(TradeProof(firestoreValue: nil), .selfReported)
        XCTAssertFalse(TradeProof.selfReported.countsTowardStats)
        XCTAssertTrue(TradeProof.priceChecked.countsTowardStats)
    }

    func testCanDelete() {
        XCTAssertTrue(makeTrade(proof: .selfReported).canDelete())

        var fresh = makeTrade(proof: .priceChecked)
        fresh.loggedAt = Date()
        XCTAssertTrue(fresh.canDelete())
        XCTAssertFalse(fresh.canDelete(at: Date().addingTimeInterval(Trade.priceCheckedDeleteWindow)))

        var old = makeTrade(proof: .priceChecked)
        old.loggedAt = Date().addingTimeInterval(-20 * 60)
        XCTAssertFalse(old.canDelete())

        XCTAssertFalse(makeTrade(proof: .verified).canDelete())
        var imported = makeTrade(proof: .selfReported)
        imported.source = "brokerage"
        XCTAssertFalse(imported.canDelete())
    }

    func testDeleteDeadlineUsesEntryProof() {
        var trade = makeTrade(proof: .priceChecked)
        trade.entryProof = .selfReported
        XCTAssertNil(trade.deleteDeadline)
    }

    func testExitNotChecked() {
        var trade = makeTrade(exit: 110, proof: .priceChecked)
        trade.exitProof = .selfReported
        XCTAssertTrue(trade.exitNotChecked)
        trade.exitProof = .priceChecked
        XCTAssertFalse(trade.exitNotChecked)
    }

    // MARK: TradeStats

    func testStatsCountsWinsLossesAndFlat() {
        let trades = [
            makeTrade(exit: 110, id: "win"),       // +100
            makeTrade(exit: 95, id: "loss"),       // -50
            makeTrade(exit: 100, id: "flat"),      // 0
            makeTrade(side: .short, exit: 80, id: "shortWin"),  // +200
            makeTrade(current: 105, id: "open")    // unrealized +50
        ]
        let stats = TradeStats(trades: trades)
        XCTAssertEqual(stats.closedCount, 4)
        XCTAssertEqual(stats.openCount, 1)
        XCTAssertEqual(stats.tradeCount, 5)
        XCTAssertEqual(stats.winCount, 2)
        XCTAssertEqual(stats.lossCount, 1)
        XCTAssertEqual(stats.realizedPL, 250, accuracy: 1e-9)
        XCTAssertEqual(stats.unrealizedPL, 50, accuracy: 1e-9)
        XCTAssertEqual(stats.totalPL, 300, accuracy: 1e-9)
        XCTAssertEqual(stats.winRate, 50, accuracy: 1e-9)
        XCTAssertEqual(stats.bestTradeId, "shortWin")
        XCTAssertEqual(stats.bestTradePL ?? 0, 200, accuracy: 1e-9)
        XCTAssertEqual(stats.closedTodayPL, 0)
    }

    func testStatsWithoutClosedTrades() {
        let stats = TradeStats(trades: [makeTrade(current: 90)])
        XCTAssertFalse(stats.hasClosedTrades)
        XCTAssertEqual(stats.winRate, 0)
        XCTAssertNil(stats.bestTradeId)
    }

    func testClosedTodayPL() {
        var trade = makeTrade()
        trade.close(at: 105, on: Date())
        XCTAssertEqual(TradeStats(trades: [trade]).closedTodayPL, 50, accuracy: 1e-9)
    }

    func testCountedAndSelfReportedSplits() {
        let trades = [makeTrade(exit: 110, proof: .verified), makeTrade(exit: 90, proof: .selfReported)]
        XCTAssertEqual(TradeStats(counted: trades).realizedPL, 100, accuracy: 1e-9)
        XCTAssertEqual(TradeStats(selfReported: trades).realizedPL, -100, accuracy: 1e-9)
        XCTAssertEqual(trades.countedForStats.count, 1)
    }

    func testPublicRecordUsesOnlyPublicClosedCountedTrades() {
        let trades = [
            makeTrade(exit: 110, isPublic: true, proof: .priceChecked, id: "counted"),   // +100
            makeTrade(exit: 120, isPublic: true, proof: .verified, id: "verified"),      // +200
            makeTrade(exit: 200, isPublic: false, proof: .verified, id: "private"),
            makeTrade(exit: 300, isPublic: true, proof: .selfReported, id: "selfReported"),
            makeTrade(current: 500, isPublic: true, proof: .verified, id: "open")
        ]
        let record = TradeStats.publicRecord(trades)
        XCTAssertEqual(record.closedCount, 2)
        XCTAssertEqual(record.openCount, 0)
        XCTAssertEqual(record.unrealizedPL, 0)
        XCTAssertEqual(record.realizedPL, 300, accuracy: 1e-9)
        XCTAssertEqual(record.winRate, 100, accuracy: 1e-9)
        XCTAssertEqual(record.bestTradeId, "verified")
    }
}
