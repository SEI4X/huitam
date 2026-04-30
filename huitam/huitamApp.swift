import SwiftUI

@main
struct huitamApp: App {
    @State private var dependencies = AppDependencyContainer.mock()
    @State private var appearance: AppAppearanceViewModel?

    var body: some Scene {
        WindowGroup {
            Group {
                if let appearance {
                    ContentView()
                        .environment(\.appDependencies, dependencies)
                        .environment(\.appTintColor, appearance.tintColor)
                        .preferredColorScheme(appearance.colorScheme)
                        .tint(appearance.tintColor)
                        .animation(.easeInOut(duration: 0.28), value: appearance.settings)
                } else {
                    ContentView()
                        .environment(\.appDependencies, dependencies)
                        .environment(\.appTintColor, AppTintPreference.blue.color)
                }
            }
            .task {
                if appearance == nil {
                    appearance = AppAppearanceViewModel(settingsService: dependencies.settingsService)
                }
                await appearance?.start()
            }
        }
    }
}
