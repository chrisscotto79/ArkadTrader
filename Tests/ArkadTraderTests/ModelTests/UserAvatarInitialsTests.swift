// File: Tests/ArkadTraderTests/ModelTests/UserAvatarInitialsTests.swift
// UserAvatar.initials(fullName:username:)

import XCTest
@testable import ArkadTrader

final class UserAvatarInitialsTests: XCTestCase {

    func testFullNameUsesFirstAndLastWord() {
        XCTAssertEqual(UserAvatar.initials(fullName: "Chris Scott", username: "cs"), "CS")
        XCTAssertEqual(UserAvatar.initials(fullName: "mary jane watson", username: "mj"), "MW")
        XCTAssertEqual(UserAvatar.initials(fullName: "  Ana   Maria  ", username: ""), "AM")
    }

    func testSingleWordNameGivesOneLetter() {
        XCTAssertEqual(UserAvatar.initials(fullName: "Chris", username: "chrisscott"), "C")
    }

    func testFallsBackToFirstTwoCharactersOfUsername() {
        XCTAssertEqual(UserAvatar.initials(fullName: nil, username: "chris"), "CH")
        XCTAssertEqual(UserAvatar.initials(fullName: "   ", username: "@chris"), "CH")
        XCTAssertEqual(UserAvatar.initials(fullName: "", username: "a"), "A")
    }

    func testUsernameWithSpacesIsTreatedAsADisplayName() {
        XCTAssertEqual(UserAvatar.initials(fullName: nil, username: "Chris Scott"), "CS")
    }

    func testFullNameWinsOverUsername() {
        XCTAssertEqual(UserAvatar.initials(fullName: "Zed", username: "Chris Scott"), "Z")
    }

    func testEmptyWhenNothingToShow() {
        XCTAssertEqual(UserAvatar.initials(fullName: nil, username: ""), "")
        XCTAssertEqual(UserAvatar.initials(fullName: " ", username: " @ "), "")
    }
}
