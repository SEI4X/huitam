import XCTest
@testable import huitam

@MainActor
final class AddFriendViewModelTests: XCTestCase {
    func testEmptyQueryClearsSearchResults() async {
        let service = RecordingFriendService()
        let viewModel = AddFriendViewModel(friendService: service)

        viewModel.query = "   "
        await viewModel.search()

        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertTrue(service.queries.isEmpty)
    }

    func testSearchByNicknameReturnsResults() async {
        let service = RecordingFriendService()
        let viewModel = AddFriendViewModel(friendService: service)

        viewModel.query = "cam"
        await viewModel.search()

        XCTAssertEqual(viewModel.results.map(\.nickname), ["camille"])
        XCTAssertEqual(service.queries, ["cam"])
    }

    func testScannedInviteURLAcceptsInviteAndOpensChat() async {
        let service = RecordingFriendService()
        let viewModel = AddFriendViewModel(friendService: service)

        await viewModel.acceptInvitePayload("https://huitam.com/invite/abc-123", as: .learner(.english))

        XCTAssertEqual(service.loadedInviteIDs, ["abc-123"])
        XCTAssertEqual(service.acceptedInvites.map(\.id), [MockAppData.sampleInvite.id])
        XCTAssertEqual(viewModel.openedChat?.participant.displayName, "Camille")
        XCTAssertNil(viewModel.scannedInvite)
        XCTAssertNil(viewModel.scannedFriend)
    }

    func testScannedAccountURLOpensExistingOrCreatedChat() async {
        let service = RecordingFriendService()
        let viewModel = AddFriendViewModel(friendService: service)

        await viewModel.acceptInvitePayload("https://huitam.com/user/camille", as: .learner(.english))

        XCTAssertEqual(service.openedAccountNicknames, ["camille"])
        XCTAssertEqual(viewModel.openedChat?.participant.displayName, "Camille")
        XCTAssertNil(viewModel.scannedInvite)
    }

    func testInvalidScannedInviteURLShowsError() async {
        let service = RecordingFriendService()
        let viewModel = AddFriendViewModel(friendService: service)

        await viewModel.openScannedInvitePayload("not an invite")

        XCTAssertTrue(service.loadedInviteIDs.isEmpty)
        XCTAssertNil(viewModel.scannedInvite)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}
