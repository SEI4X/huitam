import SwiftUI
import Observation

@MainActor
@Observable
final class AppAppearanceViewModel {
    private let settingsService: SettingsServicing

    private(set) var settings = MockAppData.settings

    init(settingsService: SettingsServicing) {
        self.settingsService = settingsService
    }

    var colorScheme: ColorScheme? {
        switch settings.theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var tintColor: Color {
        settings.tint.color
    }

    func start() async {
        if let loaded = try? await settingsService.loadSettings() {
            withAnimation(.easeInOut(duration: 0.28)) {
                settings = loaded
            }
        }

        for await updatedSettings in settingsService.settingsUpdates {
            withAnimation(.easeInOut(duration: 0.28)) {
                settings = updatedSettings
            }
        }
    }
}

extension AppTintPreference {
    var color: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .pink: .pink
        case .purple: .purple
        case .gray: .gray
        }
    }
}
