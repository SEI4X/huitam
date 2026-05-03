import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    private let settingsService: SettingsServicing
    private let authService: AuthServicing

    private(set) var settings = AppSettings(
        nativeLanguage: .russian,
        learningLanguage: .language(.english),
        theme: .system,
        tint: .blue,
        notificationsEnabled: false
    )
    private(set) var errorMessage: String?
    private(set) var isSigningOut = false
    private(set) var isDeletingAccount = false

    var canUseStudyFeatures: Bool {
        settings.canUseStudyFeatures
    }

    init(settingsService: SettingsServicing, authService: AuthServicing) {
        self.settingsService = settingsService
        self.authService = authService
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
        do {
            if updated.notificationsEnabled {
                try await FirebaseNotificationTokenService().storeCurrentMessagingTokenIfAvailable()
            } else {
                try await FirebaseNotificationTokenService().removeCurrentMessagingTokenIfAvailable()
            }
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
        await persist(updated)
    }

    func signOut() async {
        isSigningOut = true
        errorMessage = nil
        defer { isSigningOut = false }

        do {
            try await authService.signOut()
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }

    func deleteAccount(reason: String) async {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedReason.count >= 3 else {
            errorMessage = "Please tell us why you are deleting your account."
            return
        }

        isDeletingAccount = true
        errorMessage = nil
        defer { isDeletingAccount = false }

        do {
            try await authService.deleteAccount(reason: trimmedReason)
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
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
