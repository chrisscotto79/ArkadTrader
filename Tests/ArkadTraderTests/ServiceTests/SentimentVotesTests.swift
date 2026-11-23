// File: Tests/ArkadTraderTests/ServiceTests/SentimentVotesTests.swift
// SentimentVotes (one vote per author, single-ticker posts only) and TickerSentimentSummary.

import XCTest
@testable import ArkadTrader

final class SentimentVotesTests: XCTestCase {

    private func post(_ author: String, _ sentiment: String?, tickers: [String] = ["AAPL"]) -> [String: Any] {
        var data: [String: Any] = ["authorId": author, "tickers": tickers]
        if let sentiment { data["sentiment"] = sentiment }
        return data
    }

    func testCountsBullishAndBearish() {
        var votes = SentimentVotes()
        votes.add(post("a", "bullish"), for: "AAPL")
        votes.add(post("b", "bearish"), for: "AAPL")
        votes.add(post("c", "Bullish "), for: "AAPL")
        XCTAssertEqual(votes.bullish, 2)
        XCTAssertEqual(votes.bearish, 1)
    }

    func testOneVotePerAuthorFirstSeenWins() {
        var votes = SentimentVotes()
        votes.add(post("a", "bullish"), for: "AAPL")
        votes.add(post("a", "bearish"), for: "AAPL")
        votes.add(post("a", "bullish"), for: "AAPL")
        XCTAssertEqual(votes.bullish, 1)
        XCTAssertEqual(votes.bearish, 0)
    }

    func testUntaggedPostDoesNotUseUpTheAuthorsVote() {
        var votes = SentimentVotes()
        votes.add(post("a", nil), for: "AAPL")
        votes.add(post("a", "something"), for: "AAPL")
        votes.add(post("a", "bearish"), for: "AAPL")
        XCTAssertEqual(votes.bearish, 1)
    }

    func testMultiTickerPostsDontVote() {
        var votes = SentimentVotes()
        votes.add(post("a", "bullish", tickers: ["AAPL", "TSLA"]), for: "AAPL")
        votes.add(post("b", "bullish", tickers: ["TSLA"]), for: "AAPL")
        votes.add(post("c", "bullish", tickers: []), for: "AAPL")
        XCTAssertEqual(votes.bullish, 0)
        // The author whose multi-ticker post was skipped can still vote
        votes.add(post("a", "bearish"), for: "AAPL")
        XCTAssertEqual(votes.bearish, 1)
    }

    func testTickersAreNormalizedAndInvalidOnesIgnored() {
        var votes = SentimentVotes()
        votes.add(post("a", "bullish", tickers: ["aapl", "$AAPL"]), for: "AAPL")
        votes.add(post("b", "bullish", tickers: ["AAPL", "bad1"]), for: "AAPL")
        XCTAssertEqual(votes.bullish, 2)
    }

    func testMissingOrEmptyAuthorIsIgnored() {
        var votes = SentimentVotes()
        votes.add(post("", "bullish"), for: "AAPL")
        votes.add(["sentiment": "bullish", "tickers": ["AAPL"]], for: "AAPL")
        XCTAssertEqual(votes.bullish, 0)
    }

    func testPostSentimentFirestoreValue() {
        XCTAssertEqual(PostSentiment(firestoreValue: " BEARISH "), .bearish)
        XCTAssertNil(PostSentiment(firestoreValue: 1))
        XCTAssertNil(PostSentiment(firestoreValue: "neutral"))
        XCTAssertNil(PostSentiment(firestoreValue: nil))
    }

    func testSummaryNeedsThreeTaggedPosts() {
        XCTAssertNil(TickerSentimentSummary.make(bullish: 1, bearish: 1, postsConsidered: 50))
        let summary = TickerSentimentSummary.make(bullish: 2, bearish: 1, postsConsidered: 10)
        XCTAssertEqual(summary?.taggedCount, 3)
        XCTAssertEqual(summary?.bullishPercent ?? 0, 200.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(summary?.bearishPercent ?? 0, 100.0 / 3, accuracy: 1e-9)
    }

    func testTrendingTickerSentimentUsesSameThreshold() {
        let quiet = TrendingTicker(symbol: "AAPL", mentionCount: 5, bullishCount: 1, bearishCount: 1,
                                   lastMentionAt: Date(), window: 3600)
        XCTAssertNil(quiet.bullishPercent)
        let busy = TrendingTicker(symbol: "AAPL", mentionCount: 5, bullishCount: 3, bearishCount: 1,
                                  lastMentionAt: Date(), window: 3600)
        XCTAssertEqual(busy.bullishPercent ?? 0, 75, accuracy: 1e-9)
    }
}
