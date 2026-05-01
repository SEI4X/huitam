import Foundation

struct OnboardingState: Equatable {
    var hasCompletedOnboarding: Bool
    var currentUserRole: ChatParticipantRole
    var nativeLanguage: AppLanguage

    static let notStarted = OnboardingState(
        hasCompletedOnboarding: false,
        currentUserRole: .learner(.english),
        nativeLanguage: .russian
    )
}
