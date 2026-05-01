import Foundation
import Observation

@MainActor
@Observable
final class AddFriendViewModel {
    private let friendService: FriendServicing

    var query = ""
    private(set) var results: [FriendSearchResult] = []
    private(set) var hasSearched = false
    private(set) var sharePayload: String?
    private(set) var scannedFriend: FriendSearchResult?
    private(set) var scannedInvite: PracticeInvite?
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

    func loadSharePayload() async {
        do {
            sharePayload = try await friendService.sharePayload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openScannedInvitePayload(_ payload: String) async {
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmedPayload),
            let inviteID = InviteDeepLinkParser.inviteID(from: url)
        else {
            scannedInvite = nil
            errorMessage = "This QR code is not a huitam invite."
            return
        }

        do {
            scannedInvite = try await friendService.loadInvite(id: inviteID)
            scannedFriend = nil
            errorMessage = nil
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }
}
