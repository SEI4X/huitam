import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    private let settingsService: SettingsServicing

    private(set) var settings = AppSettings(
        nativeLanguage: .russian,
        learningLanguage: .language(.english),
        theme: .system,
        tint: .blue,
        notificationsEnabled: false
    )
    private(set) var errorMessage: String?

    var canUseStudyFeatures: Bool {
        settings.canUseStudyFeatures
    }

    init(settingsService: SettingsServicing) {
        self.settingsService = settingsService
    }

    func load() async {
        do {
            settings = try await settingsService.loadSettings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNativeLanguage(_ language: AppLanguage) async {
        var updated = settings
        updated.nativeLanguage = language
        await persist(updated)
    }

    func updateLearningLanguage(_ selection: LearningLanguageSelection) async {
        var updated = settings
        updated.learningLanguage = selection
        await persist(updated)
    }

    func updateTheme(_ theme: AppThemePreference) async {
        var updated = settings
        updated.theme = theme
        await persist(updated)
    }

    func updateTint(_ tint: AppTintPreference) async {
        var updated = settings
        updated.tint = tint
        await persist(updated)
    }

    func updateNotifications(enabled: Bool) async {
        var updated = settings
        updated.notificationsEnabled = await NotificationPermissionCenter.updateRegistration(enabled: enabled)
        await persist(updated)
    }

    private func persist(_ updated: AppSettings) async {
        do {
            withAnimation(.easeInOut(duration: 0.22)) {
                settings = updated
            }
            settings = try await settingsService.updateSettings(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
