import XCTest
@testable import huitam

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testCompletingLearnerOnboardingPersistsLearningSettings() async throws {
        let onboarding = RecordingOnboardingService()
        let settings = RecordingSettingsService()
        let viewModel = OnboardingViewModel(
            onboardingService: onboarding,
            settingsService: settings
        )

        viewModel.nativeLanguage = .russian
        viewModel.learningLanguage = .english

        await viewModel.completeAsLearner()

        XCTAssertTrue(viewModel.state.hasCompletedOnboarding)
        XCTAssertEqual(viewModel.state.currentUserRole, .learner(.english))
        XCTAssertEqual(settings.settings.nativeLanguage, .russian)
        XCTAssertEqual(settings.settings.learningLanguage, .language(.english))
        XCTAssertEqual(onboarding.completedRoles, [.learner(.english)])
    }

    func testCompletingCompanionOnboardingDisablesLearningSettings() async throws {
        let onboarding = RecordingOnboardingService()
        let settings = RecordingSettingsService()
        let viewModel = OnboardingViewModel(
            onboardingService: onboarding,
            settingsService: settings
        )

        viewModel.nativeLanguage = .french

        await viewModel.completeAsCompanion()

        XCTAssertTrue(viewModel.state.hasCompletedOnboarding)
        XCTAssertEqual(viewModel.state.currentUserRole, .companion)
        XCTAssertEqual(settings.settings.nativeLanguage, .french)
        XCTAssertEqual(settings.settings.learningLanguage, .none)
    }
}
