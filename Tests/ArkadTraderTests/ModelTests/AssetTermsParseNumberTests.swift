// File: Tests/ArkadTraderTests/ModelTests/AssetTermsParseNumberTests.swift
// AssetTerms.parseNumber: typed prices and quantities with either decimal mark.

import XCTest
@testable import ArkadTrader

final class AssetTermsParseNumberTests: XCTestCase {

    private var deviceUsesDotDecimal: Bool { Locale.current.decimalSeparator != "," }

    func testPlainNumbers() {
        XCTAssertEqual(AssetTerms.parseNumber("0"), 0)
        XCTAssertEqual(AssetTerms.parseNumber("42"), 42)
        XCTAssertEqual(AssetTerms.parseNumber("123.45"), 123.45)
        XCTAssertEqual(AssetTerms.parseNumber("  7.5\n"), 7.5)
    }

    func testCommaDecimalWithFewerThanThreeDigitsIsADecimalInAnyLocale() {
        XCTAssertEqual(AssetTerms.parseNumber("1,5"), 1.5)
        XCTAssertEqual(AssetTerms.parseNumber("182,40"), 182.4)
    }

    func testBothMarksUseTheLastOneAsDecimal() {
        XCTAssertEqual(AssetTerms.parseNumber("1,234.56"), 1234.56)
        XCTAssertEqual(AssetTerms.parseNumber("1.234,56"), 1234.56)
        XCTAssertEqual(AssetTerms.parseNumber("1,234,567.5"), 1_234_567.5)
    }

    func testRepeatedSameMarkIsGrouping() {
        XCTAssertEqual(AssetTerms.parseNumber("1,000,000"), 1_000_000)
        XCTAssertEqual(AssetTerms.parseNumber("1.000.000"), 1_000_000)
    }

    func testLoneMarkWithThreeDigitsDependsOnDeviceDecimal() throws {
        try XCTSkipUnless(deviceUsesDotDecimal, "Expectations assume a '.' decimal locale")
        // "," is not the device decimal, three digits follow: grouping
        XCTAssertEqual(AssetTerms.parseNumber("1,000"), 1000)
        // "." is the device decimal: a decimal even with three digits after it
        XCTAssertEqual(AssetTerms.parseNumber("1.000"), 1)
        XCTAssertEqual(AssetTerms.parseNumber("0.125"), 0.125)
    }

    func testLeadingDecimalMark() {
        XCTAssertEqual(AssetTerms.parseNumber(".5"), 0.5)
        XCTAssertEqual(AssetTerms.parseNumber(",25"), 0.25)
    }

    func testNegativeNumbers() {
        XCTAssertEqual(AssetTerms.parseNumber("-12.5"), -12.5)
        XCTAssertEqual(AssetTerms.parseNumber("\u{2212}3"), -3)  // Unicode minus sign
        XCTAssertNil(AssetTerms.parseNumber("--5"))
        XCTAssertNil(AssetTerms.parseNumber("-"))
        XCTAssertNil(AssetTerms.parseNumber("5-"))
    }

    func testGroupingSpacesAndApostrophesAreDropped() {
        XCTAssertEqual(AssetTerms.parseNumber("1 000"), 1000)
        XCTAssertEqual(AssetTerms.parseNumber("1\u{00A0}000,50"), 1000.5)
        XCTAssertEqual(AssetTerms.parseNumber("1'000.50"), 1000.5)
    }

    func testRejectsNonNumbers() {
        for text in ["", "   ", ".", ",", ".,", "inf", "-inf", "nan", "NaN", "infinity",
                     "1e308", "1E5", "12abc", "abc", "$5", "0x10", "+5", "٣"] {
            XCTAssertNil(AssetTerms.parseNumber(text), "expected nil for \"\(text)\"")
        }
    }

    func testRejectsTwoDecimalMarksOfTheLastKind() {
        // Both marks present, "," last, but "," appears twice around the "."
        XCTAssertNil(AssetTerms.parseNumber("1,2.3,4"))
    }

    func testRejectsGroupingThatIsNotGroupsOfThree() {
        for text in ["1.2.3", "12.34.5", "1,2,3", "1234,567,890", "1,234.5,6"] {
            XCTAssertNil(AssetTerms.parseNumber(text), "expected nil for \"\(text)\"")
        }
        XCTAssertEqual(AssetTerms.parseNumber("1,234,567"), 1_234_567)
        XCTAssertEqual(AssetTerms.parseNumber("1.234.567,5"), 1_234_567.5)
    }

    func testUpperBound() {
        XCTAssertEqual(AssetTerms.parseNumber("1000000000000"), AssetTerms.maxTypedNumber)
        XCTAssertNil(AssetTerms.parseNumber("1000000000001"))
        XCTAssertNil(AssetTerms.parseNumber("-1000000000001"))
        XCTAssertNil(AssetTerms.parseNumber(String(repeating: "9", count: 400)))
    }

    func testRejectsInputLongerThan24Characters() {
        let twentyFour = String(repeating: "1", count: 24)
        let twentyFive = String(repeating: "1", count: 25)
        XCTAssertNil(AssetTerms.parseNumber(twentyFour), "24 digits is above maxTypedNumber anyway")
        let fitsLength = "0." + String(repeating: "0", count: 21) + "1"  // 24 characters
        XCTAssertEqual(fitsLength.count, 24)
        XCTAssertNotNil(AssetTerms.parseNumber(fitsLength))
        XCTAssertNil(AssetTerms.parseNumber("0." + String(repeating: "0", count: 22) + "1"))  // 25 characters
        XCTAssertNil(AssetTerms.parseNumber(twentyFive))
    }

    func testCalloutParsePriceStripsDollarAndPercent() {
        XCTAssertEqual(TradeCallout.parsePrice("$182.40"), 182.4)
        XCTAssertEqual(TradeCallout.parsePrice("12%"), 12)
        XCTAssertNil(TradeCallout.parsePrice("$"))
        XCTAssertNil(TradeCallout.parsePrice("nan"))
    }

    func testBadgeText() {
        XCTAssertEqual(AssetTerms.badgeText(for: "aapl"), "AAPL")
        XCTAssertEqual(AssetTerms.badgeText(for: "EUR/USD"), "EUR")
        XCTAssertEqual(AssetTerms.badgeText(for: "GOOGL"), "GOOG")
    }
}
