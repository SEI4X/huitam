import XCTest
@testable import huitam

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testLoadSettingsMapsLearningMode() async {
        let service = RecordingSettingsService()
        let auth = RecordingAuthService()
        let viewModel = SettingsViewModel(settingsService: service, authService: auth)

        await viewModel.load()

        XCTAssertEqual(viewModel.settings.learningLanguage, .language(.english))
        XCTAssertTrue(viewModel.canUseStudyFeatures)
    }

    func testSelectingNoLearningDisablesStudyFeaturesAndPersists() async {
        let service = RecordingSettingsService()
        let auth = RecordingAuthService()
        let viewModel = SettingsViewModel(settingsService: service, authService: auth)
        await viewModel.load()

        await viewModel.updateLearningLanguage(.none)

        XCTAssertFalse(viewModel.canUseStudyFeatures)
        XCTAssertEqual(service.settings.learningLanguage, .none)
    }

    func testSignOutUsesAuthService() async {
        let settings = RecordingSettingsService()
        let auth = RecordingAuthService()
        let viewModel = SettingsViewModel(settingsService: settings, authService: auth)

        await viewModel.signOut()

        XCTAssertEqual(auth.signOutCount, 1)
    }

    func testDeleteAccountRequiresReasonAndUsesAuthService() async {
        let settings = RecordingSettingsService()
        let auth = RecordingAuthService()
        let viewModel = SettingsViewModel(settingsService: settings, authService: auth)

        await viewModel.deleteAccount(reason: "I do not need it anymore")

        XCTAssertEqual(auth.deletedAccountReasons, ["I do not need it anymore"])
    }
}
