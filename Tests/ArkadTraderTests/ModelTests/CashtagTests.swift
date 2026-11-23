// File: Tests/ArkadTraderTests/ModelTests/CashtagTests.swift
// Cashtag extraction, removal and cleaning, plus hashtag / mention extraction.

import XCTest
@testable import ArkadTrader

final class CashtagTests: XCTestCase {

    // MARK: Extraction

    func testSymbolsAreCaseInsensitiveAndUppercased() {
        XCTAssertEqual(Cashtag.symbols(in: "Buying $aapl and $NVDA, watching $Tsla"), ["AAPL", "NVDA", "TSLA"])
    }

    func testShareClassSuffixIsAllowed() {
        XCTAssertEqual(Cashtag.symbols(in: "Long $BRK.B today"), ["BRK.B"])
        XCTAssertEqual(Cashtag.symbols(in: "I like $brk.b."), ["BRK.B"])
    }

    func testTrailingPunctuationIsNotPartOfTheSymbol() {
        XCTAssertEqual(Cashtag.symbols(in: "($TSLA) $AAPL. $MSFT!"), ["TSLA", "AAPL", "MSFT"])
    }

    func testNoMatchInsideWordsOrAfterDollar() {
        XCTAssertEqual(Cashtag.symbols(in: "foo$AAPL"), [])
        XCTAssertEqual(Cashtag.symbols(in: "$$AAPL"), [])
        XCTAssertEqual(Cashtag.symbols(in: "a_$AAPL"), [])
        XCTAssertEqual(Cashtag.symbols(in: "1$AAPL"), [])
    }

    func testRejectsNumbersAndTooLongSymbols() {
        XCTAssertEqual(Cashtag.symbols(in: "it cost $100"), [])
        XCTAssertEqual(Cashtag.symbols(in: "$TOOLONG"), [])
        XCTAssertEqual(Cashtag.symbols(in: "$A1"), [])
        XCTAssertEqual(Cashtag.symbols(in: "$"), [])
        XCTAssertEqual(Cashtag.symbols(in: "$GOOGL"), ["GOOGL"])
    }

    func testSymbolsAreDedupedInFirstSeenOrder() {
        XCTAssertEqual(Cashtag.symbols(in: "$MSFT then $aapl then $msft then $AAPL"), ["MSFT", "AAPL"])
    }

    func testMatchesKeepDuplicatesAndRanges() {
        let text = "$aapl $AAPL"
        let matches = Cashtag.matches(in: text)
        XCTAssertEqual(matches.map(\.symbol), ["AAPL", "AAPL"])
        XCTAssertEqual(matches.map(\.range.location), [0, 6])
        XCTAssertEqual(matches.map(\.range.length), [5, 5])
    }

    func testMatchesUseUTF16RangesAfterEmoji() throws {
        let text = "🚀 $TSLA"
        let match = try XCTUnwrap(Cashtag.matches(in: text).first)
        XCTAssertEqual((text as NSString).substring(with: match.range), "$TSLA")
    }

    func testExtractTickersCapsAtPostLimit() {
        let text = Array("ABCDEFGHIJKL").map { "$A\($0)" }.joined(separator: " ")
        XCTAssertEqual(Cashtag.symbols(in: text).count, 12)
        XCTAssertEqual(extractTickers(from: text).count, Post.maxTickers)
    }

    // MARK: Removing

    func testRemovingLeavesLongerSymbolsAlone() {
        XCTAssertEqual(Cashtag.removing("$A", from: "$A and $AAPL"), " and $AAPL")
        XCTAssertEqual(Cashtag.removing("A", from: "$AAPL only"), "$AAPL only")
    }

    func testRemovingTakesOneSpaceBeforeEachToken() {
        XCTAssertEqual(Cashtag.removing("aapl", from: "Long $AAPL now"), "Long now")
        XCTAssertEqual(Cashtag.removing("$AAPL", from: "x $aapl y $AAPL"), "x y")
    }

    func testRemovingWithNoMatchReturnsTextUnchanged() {
        XCTAssertEqual(Cashtag.removing("TSLA", from: "nothing $here"), "nothing $here")
    }

    func testRemovingShareClassSymbol() {
        XCTAssertEqual(Cashtag.removing("brk.b", from: "Own $BRK.B and $BRK"), "Own and $BRK")
    }

    // MARK: Normalize / validate / clean

    func testNormalize() {
        XCTAssertEqual(Cashtag.normalize("  $$aapl "), "AAPL")
        XCTAssertEqual(Cashtag.normalize("brk.b"), "BRK.B")
    }

    func testIsValid() {
        XCTAssertTrue(Cashtag.isValid("AAPL"))
        XCTAssertTrue(Cashtag.isValid("BRK.B"))
        XCTAssertFalse(Cashtag.isValid("aapl"))
        XCTAssertFalse(Cashtag.isValid("TOOLONG"))
        XCTAssertFalse(Cashtag.isValid("A1"))
        XCTAssertFalse(Cashtag.isValid(""))
        XCTAssertFalse(Cashtag.isValid("BRK.BB"))
    }

    func testCleanedNormalizesFiltersDedupesAndLimits() {
        let tickers = ["$aapl", "AAPL", "bad1", "msft", "", "brk.b"]
        XCTAssertEqual(Cashtag.cleaned(tickers), ["AAPL", "MSFT", "BRK.B"])
        XCTAssertEqual(Cashtag.cleaned(tickers, limit: 1), ["AAPL"])
    }

    func testUppercasingSymbolsKeepsTheRestOfTheText() {
        XCTAssertEqual(Cashtag.uppercasingSymbols(in: "buy $nvda and $brk.b, not $100"),
                       "buy $NVDA and $BRK.B, not $100")
    }

    // MARK: Hashtags and mentions

    func testHashtagsDedupeCaseInsensitivelyKeepingFirstSpelling() {
        XCTAssertEqual(extractHashtags(from: "#Swift #swift #iOS #ios_dev"), ["#Swift", "#iOS", "#ios_dev"])
    }

    func testMentionsDropAtSignAndDedupe() {
        XCTAssertEqual(extractMentions(from: "hi @sam, @Sam and @bob_1!"), ["sam", "bob_1"])
    }

    func testEmailAddressesAreNotMentions() {
        XCTAssertEqual(extractMentions(from: "mail bob@gmail.com"), [])
        XCTAssertEqual(extractMentions(from: "(@sam) and @bob."), ["sam", "bob"])
    }
}
