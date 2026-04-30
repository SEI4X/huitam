import XCTest
@testable import huitam

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testLoadSettingsMapsLearningMode() async {
        let service = RecordingSettingsService()
        let viewModel = SettingsViewModel(settingsService: service)

        await viewModel.load()

        XCTAssertEqual(viewModel.settings.learningLanguage, .language(.english))
        XCTAssertTrue(viewModel.canUseStudyFeatures)
    }

    func testSelectingNoLearningDisablesStudyFeaturesAndPersists() async {
        let service = RecordingSettingsService()
        let viewModel = SettingsViewModel(settingsService: service)
        await viewModel.load()

        await viewModel.updateLearningLanguage(.none)

        XCTAssertFalse(viewModel.canUseStudyFeatures)
        XCTAssertEqual(service.settings.learningLanguage, .none)
    }
}
