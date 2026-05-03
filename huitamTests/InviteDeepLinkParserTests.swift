import XCTest
@testable import huitam

final class InviteDeepLinkParserTests: XCTestCase {
    func testParsesUniversalInviteLink() {
        let url = URL(string: "https://huitam.com/invite/abc-123")!

        XCTAssertEqual(InviteDeepLinkParser.inviteID(from: url), "abc-123")
    }

    func testParsesCustomSchemeInviteLink() {
        let url = URL(string: "huitam://invite/abc-123")!

        XCTAssertEqual(InviteDeepLinkParser.inviteID(from: url), "abc-123")
    }

    func testRejectsNonInviteLinks() {
        let url = URL(string: "https://huitam.com/profile/abc-123")!

        XCTAssertNil(InviteDeepLinkParser.inviteID(from: url))
    }

    func testParsesUniversalAccountLink() {
        let url = URL(string: "https://huitam.com/user/alex_2026")!

        XCTAssertEqual(InviteDeepLinkParser.accountNickname(from: url), "alex_2026")
    }

    func testParsesCustomSchemeAccountLink() {
        let url = URL(string: "huitam://user/alex_2026")!

        XCTAssertEqual(InviteDeepLinkParser.accountNickname(from: url), "alex_2026")
    }
}
