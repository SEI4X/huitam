import Foundation
import Observation

@MainActor
@Observable
final class CreatePracticeChatViewModel {
    private let friendService: FriendServicing

    private(set) var invite: PracticeInvite?
    private(set) var accountLink: AccountShareLink?
    private(set) var isCreating = false
    private(set) var errorMessage: String?

    init(friendService: FriendServicing) {
        self.friendService = friendService
    }

    func setAccountNickname(_ nickname: String) {
        accountLink = AccountShareLink(nickname: nickname)
    }

    func createInvite() async {
        guard invite == nil else { return }
        isCreating = true
        defer { isCreating = false }

        do {
            invite = try await friendService.createPracticeInvite(
                PracticeInviteRequest(
                    guestNativeLanguage: .english,
                    guestLearningLanguage: .none
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
