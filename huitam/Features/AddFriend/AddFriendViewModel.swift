import Foundation
import Observation

@MainActor
@Observable
final class AddFriendViewModel {
    private let friendService: FriendServicing

    var query = ""
    private(set) var results: [FriendSearchResult] = []
    private(set) var hasSearched = false
    private(set) var scannedFriend: FriendSearchResult?
    private(set) var scannedInvite: PracticeInvite?
    private(set) var openedChat: ChatSummary?
    private(set) var isAcceptingInvite = false
    private(set) var errorMessage: String?

    init(friendService: FriendServicing) {
        self.friendService = friendService
    }

    func search() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            hasSearched = false
            results = []
            return
        }

        do {
            results = try await friendService.search(byNickname: trimmedQuery)
            hasSearched = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openScannedInvitePayload(_ payload: String) async {
        await acceptInvitePayload(payload, as: .learner(.english))
    }

    func acceptInvitePayload(_ payload: String, as role: ChatParticipantRole) async {
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmedPayload),
           let nickname = InviteDeepLinkParser.accountNickname(from: url) {
            await openAccountLink(nickname: nickname, as: role)
            return
        }

        guard
            let url = URL(string: trimmedPayload),
            let inviteID = InviteDeepLinkParser.inviteID(from: url)
        else {
            scannedInvite = nil
            errorMessage = "This QR code is not a huitam invite."
            return
        }

        isAcceptingInvite = true
        defer { isAcceptingInvite = false }

        do {
            let invite = try await friendService.loadInvite(id: inviteID)
            openedChat = try await friendService.acceptInvite(invite, as: role)
            scannedInvite = nil
            scannedFriend = nil
            errorMessage = nil
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }

    private func openAccountLink(nickname: String, as role: ChatParticipantRole) async {
        isAcceptingInvite = true
        defer { isAcceptingInvite = false }

        do {
            openedChat = try await friendService.openAccountChat(nickname: nickname, as: role)
            scannedInvite = nil
            scannedFriend = nil
            errorMessage = nil
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }

    func clearOpenedChat() {
        openedChat = nil
    }
}
