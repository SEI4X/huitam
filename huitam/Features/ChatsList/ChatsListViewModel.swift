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
    private let presenceService: PresenceServicing
    private var presenceTasksByUserID: [String: Task<Void, Never>] = [:]

    private(set) var chats: [ChatSummary] = []
    private(set) var presenceStatusesByUserID: [String: PresenceStatus] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var openedChat: ChatSummary?
    var presentedSheet: ChatsListSheet?
    var searchText = ""

    var filteredChats: [ChatSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else {
            return chats
        }

        return chats.filter { chat in
            chat.participant.displayName.lowercased().contains(query)
                || chat.participant.nickname.lowercased().contains(query)
        }
    }

    init(chatService: ChatServicing, presenceService: PresenceServicing? = nil) {
        self.chatService = chatService
        self.presenceService = presenceService ?? NoopPresenceService()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            chats = try await chatService.loadChatSummaries()
            await startObservingPresence()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func startObservingChats() async {
        isLoading = true
        errorMessage = nil

        for await result in chatService.chatSummaryUpdates() {
            switch result {
            case let .success(chats):
                self.chats = chats
                await startObservingPresence()
                isLoading = false
            case let .failure(error):
                errorMessage = AppErrorMessage.userFacing(error)
                isLoading = false
            }
        }
    }

    func startObservingPresence() async {
        let participantUserIDs = Set(chats.map(\.participant.uid).filter { $0.isEmpty == false })

        for (userID, task) in presenceTasksByUserID where participantUserIDs.contains(userID) == false {
            task.cancel()
            presenceTasksByUserID[userID] = nil
            presenceStatusesByUserID[userID] = nil
        }

        for userID in participantUserIDs where presenceTasksByUserID[userID] == nil {
            presenceStatusesByUserID[userID] = presenceStatusesByUserID[userID] ?? .offline
            presenceTasksByUserID[userID] = Task { [presenceService] in
                for await status in presenceService.presenceUpdates(for: userID) {
                    guard Task.isCancelled == false else { break }
                    self.presenceStatusesByUserID[userID] = status
                }
            }
        }
        for _ in 0..<3 {
            await Task.yield()
        }
    }

    func stopObservingPresence() {
        presenceTasksByUserID.values.forEach { $0.cancel() }
        presenceTasksByUserID = [:]
    }

    func presenceStatus(for chat: ChatSummary) -> PresenceStatus {
        guard chat.participant.uid.isEmpty == false else { return .offline }
        return presenceStatusesByUserID[chat.participant.uid] ?? .offline
    }

    func acceptInvite(id inviteID: String, role: ChatParticipantRole, friendService: FriendServicing) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let invite = try await friendService.loadInvite(id: inviteID)
            openedChat = try await friendService.acceptInvite(invite, as: role)
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }

    func openAccountChat(nickname: String, role: ChatParticipantRole, friendService: FriendServicing) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            openedChat = try await friendService.openAccountChat(nickname: nickname, as: role)
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }

    func clearOpenedChat() {
        openedChat = nil
    }

    func present(_ sheet: ChatsListSheet) {
        presentedSheet = sheet
    }
}
