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

    func testScannedInviteURLLoadsInvite() async {
        let service = RecordingFriendService()
        let viewModel = AddFriendViewModel(friendService: service)

        await viewModel.openScannedInvitePayload("https://huitam.com/invite/abc-123")

        XCTAssertEqual(service.loadedInviteIDs, ["abc-123"])
        XCTAssertEqual(viewModel.scannedInvite?.id, MockAppData.sampleInvite.id)
        XCTAssertNil(viewModel.scannedFriend)
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
