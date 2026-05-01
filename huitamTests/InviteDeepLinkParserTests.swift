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
}
