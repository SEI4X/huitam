import Foundation
import Observation

@MainActor
@Observable
final class InvitedFriendViewModel {
    let invite: PracticeInvite
    private let friendService: FriendServicing

    private(set) var createdChat: ChatSummary?
    private(set) var isAccepting = false
    private(set) var errorMessage: String?
    var guestLearningLanguage: AppLanguage = .english

    init(invite: PracticeInvite, friendService: FriendServicing) {
        self.invite = invite
        self.friendService = friendService
    }

    func acceptAsCompanion() async {
        await accept(role: .companion)
    }

    func acceptAsLearner() async {
        await accept(role: .learner(guestLearningLanguage))
    }

    private func accept(role: ChatParticipantRole) async {
        isAccepting = true
        defer { isAccepting = false }

        do {
            createdChat = try await friendService.acceptInvite(invite, as: role)
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }
}
