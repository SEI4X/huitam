import XCTest
@testable import huitam

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testCompletingLearnerOnboardingPersistsLearningSettings() async throws {
        let onboarding = RecordingOnboardingService()
        let settings = RecordingSettingsService()
        let profile = RecordingProfileService()
        let viewModel = OnboardingViewModel(
            onboardingService: onboarding,
            settingsService: settings,
            profileService: profile
        )

        viewModel.nickname = "alex"
        viewModel.nativeLanguage = .russian
        viewModel.learningLanguage = .english

        await viewModel.completeAsLearner()

        XCTAssertTrue(viewModel.state.hasCompletedOnboarding)
        XCTAssertEqual(viewModel.state.currentUserRole, .learner(.english))
        XCTAssertEqual(settings.settings.nativeLanguage, .russian)
        XCTAssertEqual(settings.settings.learningLanguage, .language(.english))
        XCTAssertEqual(onboarding.completedRoles, [.learner(.english)])
        XCTAssertEqual(profile.updatedProfiles.last?.nickname, "alex")
    }

    func testCompletingCompanionOnboardingDisablesLearningSettings() async throws {
        let onboarding = RecordingOnboardingService()
        let settings = RecordingSettingsService()
        let profile = RecordingProfileService()
        let viewModel = OnboardingViewModel(
            onboardingService: onboarding,
            settingsService: settings,
            profileService: profile
        )

        viewModel.nickname = "camille"
        viewModel.nativeLanguage = .french

        await viewModel.completeAsCompanion()

        XCTAssertTrue(viewModel.state.hasCompletedOnboarding)
        XCTAssertEqual(viewModel.state.currentUserRole, .companion)
        XCTAssertEqual(settings.settings.nativeLanguage, .french)
        XCTAssertEqual(settings.settings.learningLanguage, .none)
    }

    func testLearningChoiceCanCompleteAsCompanion() async throws {
        let onboarding = RecordingOnboardingService()
        let settings = RecordingSettingsService()
        let profile = RecordingProfileService()
        let viewModel = OnboardingViewModel(
            onboardingService: onboarding,
            settingsService: settings,
            profileService: profile
        )

        viewModel.nickname = "camille"
        viewModel.selectNoLearning()

        await viewModel.completeLearningChoice()

        XCTAssertTrue(viewModel.state.hasCompletedOnboarding)
        XCTAssertEqual(viewModel.state.currentUserRole, .companion)
        XCTAssertEqual(settings.settings.learningLanguage, .none)
    }

    func testLearningChoiceCanReturnFromCompanionToLearner() async throws {
        let onboarding = RecordingOnboardingService()
        let settings = RecordingSettingsService()
        let profile = RecordingProfileService()
        let notifications = RecordingNotificationPermissionService()
        let viewModel = OnboardingViewModel(
            onboardingService: onboarding,
            settingsService: settings,
            profileService: profile,
            notificationPermissionService: notifications
        )

        viewModel.nickname = "camille"
        viewModel.selectNoLearning()
        viewModel.selectLearningLanguage(.french)

        await viewModel.completeLearningChoice()

        XCTAssertTrue(viewModel.state.hasCompletedOnboarding)
        XCTAssertEqual(viewModel.state.currentUserRole, .learner(.french))
        XCTAssertEqual(settings.settings.learningLanguage, .language(.french))
    }

    func testCompletingOnboardingWithNotificationsRequestsPermissionAndPersistsResult() async throws {
        let onboarding = RecordingOnboardingService()
        let settings = RecordingSettingsService()
        let profile = RecordingProfileService()
        let notifications = RecordingNotificationPermissionService()
        notifications.registrationResult = true
        let viewModel = OnboardingViewModel(
            onboardingService: onboarding,
            settingsService: settings,
            profileService: profile,
            notificationPermissionService: notifications
        )

        viewModel.nickname = "alex"

        await viewModel.completeLearningChoice(requestNotifications: true)

        XCTAssertEqual(notifications.registrationRequests, [true])
        XCTAssertTrue(settings.settings.notificationsEnabled)
        XCTAssertTrue(viewModel.state.hasCompletedOnboarding)
    }

    func testNicknameValidationRejectsSpacesAndNonLatinCharacters() async throws {
        let viewModel = OnboardingViewModel(
            onboardingService: RecordingOnboardingService(),
            settingsService: RecordingSettingsService(),
            profileService: RecordingProfileService()
        )

        viewModel.nickname = "alex mash"

        XCTAssertFalse(viewModel.isNicknameValid)
        XCTAssertTrue(viewModel.nicknameValidationMessage.contains("space"))

        viewModel.nickname = "алекс"

        XCTAssertFalse(viewModel.isNicknameValid)
        XCTAssertTrue(viewModel.nicknameValidationMessage.contains("а"))

        viewModel.nickname = "alex_2026"

        XCTAssertTrue(viewModel.isNicknameValid)
    }
}
