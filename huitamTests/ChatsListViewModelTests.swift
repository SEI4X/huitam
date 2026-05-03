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

    func testStartObservingChatsAppliesIncomingUpdates() async throws {
        let service = RecordingChatService()
        service.chatUpdates = [
            [],
            [MockAppData.chats[0]]
        ]
        let viewModel = ChatsListViewModel(chatService: service)

        await viewModel.startObservingChats()

        XCTAssertEqual(viewModel.chats.map(\.participant.displayName), ["Camille"])
        XCTAssertFalse(viewModel.isLoading)
    }

    func testFilteredChatsMatchParticipantNameAndNickname() async throws {
        let service = RecordingChatService()
        let viewModel = ChatsListViewModel(chatService: service)

        await viewModel.load()

        viewModel.searchText = "cam"
        XCTAssertEqual(viewModel.filteredChats.map(\.participant.displayName), ["Camille"])

        viewModel.searchText = "mateo"
        XCTAssertEqual(viewModel.filteredChats.map(\.participant.displayName), ["Mateo"])

        viewModel.searchText = "  "
        XCTAssertEqual(viewModel.filteredChats.count, 2)
    }

    func testStartObservingPresenceAppliesParticipantStatuses() async throws {
        let chatService = RecordingChatService()
        let presenceService = RecordingPresenceService()
        let viewModel = ChatsListViewModel(chatService: chatService, presenceService: presenceService)

        await viewModel.load()
        await viewModel.startObservingPresence()

        XCTAssertEqual(Set(presenceService.observedUserIDs), ["firebase-camille", "firebase-mateo"])
        XCTAssertTrue(viewModel.presenceStatus(for: MockAppData.chats[0]).isOnline)
        XCTAssertEqual(viewModel.presenceStatus(for: MockAppData.chats[1]).label, "last seen recently")
    }
}
