import Foundation
import Observation

enum ChatsListSheet: Identifiable, Equatable {
    case profile
    case studyCards
    case addFriend

    var id: String {
        switch self {
        case .profile: "profile"
        case .studyCards: "studyCards"
        case .addFriend: "addFriend"
        }
    }
}

@MainActor
@Observable
final class ChatsListViewModel {
    private let chatService: ChatServicing

    private(set) var chats: [ChatSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var presentedSheet: ChatsListSheet?

    init(chatService: ChatServicing) {
        self.chatService = chatService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            chats = try await chatService.loadChatSummaries()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func present(_ sheet: ChatsListSheet) {
        presentedSheet = sheet
    }
}
