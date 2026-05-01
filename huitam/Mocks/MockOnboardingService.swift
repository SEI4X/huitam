import Foundation

@MainActor
final class MockOnboardingService: OnboardingServicing {
    private var state: OnboardingState

    init(state: OnboardingState? = nil) {
        self.state = state ?? OnboardingState(
            hasCompletedOnboarding: false,
            currentUserRole: .learner(.english),
            nativeLanguage: .russian
        )
    }

    func loadState() async throws -> OnboardingState {
        state
    }

    func complete(role: ChatParticipantRole, nativeLanguage: AppLanguage) async throws -> OnboardingState {
        state = OnboardingState(
            hasCompletedOnboarding: true,
            currentUserRole: role,
            nativeLanguage: nativeLanguage
        )
        return state
    }
}
