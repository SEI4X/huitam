import Foundation

@MainActor
protocol OnboardingServicing {
    func loadState() async throws -> OnboardingState
    func complete(role: ChatParticipantRole, nativeLanguage: AppLanguage) async throws -> OnboardingState
}
