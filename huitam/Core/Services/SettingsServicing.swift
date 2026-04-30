import Foundation

@MainActor
protocol SettingsServicing {
    var settingsUpdates: AsyncStream<AppSettings> { get }

    func loadSettings() async throws -> AppSettings
    func updateSettings(_ settings: AppSettings) async throws -> AppSettings
}
