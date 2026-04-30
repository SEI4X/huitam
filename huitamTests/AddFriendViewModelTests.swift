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
}
