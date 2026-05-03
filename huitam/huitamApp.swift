import SwiftUI

@main
struct huitamApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) private var appDelegate
    @State private var dependencies: AppDependencyContainer?
    @State private var appearance: AppAppearanceViewModel?

    var body: some Scene {
        WindowGroup {
            Group {
                if let dependencies {
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
                } else {
                    AppBootstrapView()
                }
            }
            .task {
                if dependencies == nil {
                    dependencies = AppDependencyContainer.production()
                }
                guard let dependencies else { return }
                if appearance == nil {
                    appearance = AppAppearanceViewModel(settingsService: dependencies.settingsService)
                }
                await appearance?.start()
            }
        }
    }
}

private struct AppBootstrapView: View {
    var body: some View {
        ZStack {
            PremiumScreenBackground(glowPosition: .bottom, intensity: 0.86)
                .ignoresSafeArea()

            HStack(spacing: 12) {
                Image(systemName: "message.badge.waveform")
                    .font(.system(size: 30, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text("huitam")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
