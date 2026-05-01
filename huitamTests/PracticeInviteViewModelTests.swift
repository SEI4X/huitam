import XCTest
@testable import huitam

@MainActor
final class PracticeInviteViewModelTests: XCTestCase {
    func testCreateInviteUsesGuestLanguagesAndProducesShareLink() async throws {
        let service = RecordingFriendService()
        let viewModel = CreatePracticeChatViewModel(friendService: service)

        viewModel.guestNativeLanguage = .french
        viewModel.guestLearningLanguage = .none

        await viewModel.createInvite()

        XCTAssertEqual(service.createdInviteRequests, [
            PracticeInviteRequest(
                guestNativeLanguage: .french,
                guestLearningLanguage: .none
            )
        ])
        XCTAssertEqual(viewModel.invite?.guestRole, .companion)
        XCTAssertEqual(viewModel.invite?.shareURL.absoluteString, "https://huitam.com/invite/mock-invite")
    }

    func testAcceptingInviteAsMutualLearnerCreatesChatWithLearnerRoles() async throws {
        let service = RecordingFriendService()
        let invite = MockAppData.sampleInvite
        let viewModel = InvitedFriendViewModel(invite: invite, friendService: service)

        viewModel.guestLearningLanguage = .french

        await viewModel.acceptAsLearner()

        XCTAssertEqual(service.acceptedInvites.map(\.id), [invite.id])
        XCTAssertEqual(viewModel.createdChat?.currentUserRole, .learner(.french))
        XCTAssertEqual(viewModel.createdChat?.participantRole, .learner(.english))
    }
}
