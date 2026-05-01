import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    private let onboardingService: OnboardingServicing
    private let settingsService: SettingsServicing

    private(set) var state = OnboardingState.notStarted
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var nativeLanguage: AppLanguage = .russian
    var learningLanguage: AppLanguage = .english

    init(
        onboardingService: OnboardingServicing,
        settingsService: SettingsServicing
    ) {
        self.onboardingService = onboardingService
        self.settingsService = settingsService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            state = try await onboardingService.loadState()
            nativeLanguage = state.nativeLanguage
            if let learningLanguage = state.currentUserRole.learningLanguage {
                self.learningLanguage = learningLanguage
            }
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }

    func completeAsLearner() async {
        await complete(role: .learner(learningLanguage), learningSelection: .language(learningLanguage))
    }

    func completeAsCompanion() async {
        await complete(role: .companion, learningSelection: .none)
    }

    private func complete(
        role: ChatParticipantRole,
        learningSelection: LearningLanguageSelection
    ) async {
        do {
            var settings = try await settingsService.loadSettings()
            settings.nativeLanguage = nativeLanguage
            settings.learningLanguage = learningSelection
            _ = try await settingsService.updateSettings(settings)
            state = try await onboardingService.complete(role: role, nativeLanguage: nativeLanguage)
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }
}
