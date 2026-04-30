import Foundation

@MainActor
final class MockSettingsService: SettingsServicing {
    private var storedSettings: AppSettings
    private var continuations: [AsyncStream<AppSettings>.Continuation] = []

    var settingsUpdates: AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(storedSettings)
            continuations.append(continuation)
        }
    }

    init(settings: AppSettings? = nil) {
        self.storedSettings = settings ?? MockAppData.settings
    }

    func loadSettings() async throws -> AppSettings {
        storedSettings
    }

    func updateSettings(_ settings: AppSettings) async throws -> AppSettings {
        storedSettings = settings
        continuations.forEach { $0.yield(settings) }
        return settings
    }
}
