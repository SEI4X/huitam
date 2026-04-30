import XCTest
@testable import huitam

@MainActor
final class ChatsListViewModelTests: XCTestCase {
    func testLoadChatsMapsSummaries() async throws {
        let service = RecordingChatService()
        let viewModel = ChatsListViewModel(chatService: service)

        await viewModel.load()

        XCTAssertEqual(viewModel.chats.map(\.participant.displayName), ["Camille", "Mateo"])
    }

    func testToolbarSheetRoutingUsesSingleSelection() {
        let viewModel = ChatsListViewModel(chatService: RecordingChatService())

        viewModel.present(.profile)
        XCTAssertEqual(viewModel.presentedSheet, .profile)

        viewModel.present(.addFriend)
        XCTAssertEqual(viewModel.presentedSheet, .addFriend)
    }
}
