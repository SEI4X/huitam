import Foundation
import Observation

@MainActor
@Observable
final class CreatePracticeChatViewModel {
    private let friendService: FriendServicing

    private(set) var invite: PracticeInvite?
    private(set) var isCreating = false
    private(set) var errorMessage: String?
    var guestNativeLanguage: AppLanguage = .french
    var guestLearningLanguage: LearningLanguageSelection = .none

    init(friendService: FriendServicing) {
        self.friendService = friendService
    }

    func createInvite() async {
        isCreating = true
        defer { isCreating = false }

        do {
            invite = try await friendService.createPracticeInvite(
                PracticeInviteRequest(
                    guestNativeLanguage: guestNativeLanguage,
                    guestLearningLanguage: guestLearningLanguage
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
