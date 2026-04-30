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

    func scanQRCode() async {
        do {
            scannedFriend = try await friendService.scanQRCodeMockResult()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
