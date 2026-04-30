import SwiftUI

private struct AppDependencyContainerKey: EnvironmentKey {
    @MainActor static let defaultValue = AppDependencyContainer.mock()
}

private struct AppTintColorKey: EnvironmentKey {
    static let defaultValue = Color.blue
}

extension EnvironmentValues {
    var appDependencies: AppDependencyContainer {
        get { self[AppDependencyContainerKey.self] }
        set { self[AppDependencyContainerKey.self] = newValue }
    }

    var appTintColor: Color {
        get { self[AppTintColorKey.self] }
        set { self[AppTintColorKey.self] = newValue }
    }
}
