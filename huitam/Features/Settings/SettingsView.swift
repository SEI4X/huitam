import SwiftUI

struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: SettingsViewModel

    init(container: AppDependencyContainer) {
        _viewModel = State(initialValue: SettingsViewModel(settingsService: container.settingsService))
    }

    var body: some View {
        Form {
            Section("Languages") {
                Picker("My language", selection: Binding(
                    get: { viewModel.settings.nativeLanguage },
                    set: { language in
                        Task { await viewModel.updateNativeLanguage(language) }
                    }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }

                Picker("Learning", selection: Binding(
                    get: { viewModel.settings.learningLanguage },
                    set: { selection in
                        Task {
                            await viewModel.updateLearningLanguage(selection)
                        }
                    }
                )) {
                    Text("Not learning").tag(LearningLanguageSelection.none)
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(LearningLanguageSelection.language(language))
                    }
                }

                if viewModel.canUseStudyFeatures == false {
                    Text("Study actions are hidden while language learning is off.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { viewModel.settings.theme },
                    set: { theme in
                        Task { await viewModel.updateTheme(theme) }
                    }
                )) {
                    ForEach(AppThemePreference.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }

                Picker("Tint", selection: Binding(
                    get: { viewModel.settings.tint },
                    set: { tint in
                        Task { await viewModel.updateTint(tint) }
                    }
                )) {
                    ForEach(AppTintPreference.allCases) { tint in
                        Label {
                            Text(tint.displayName)
                        } icon: {
                            Circle()
                                .fill(tint.color)
                                .frame(width: 10, height: 10)
                        }
                        .tag(tint)
                    }
                }
            }

            Section("Notifications") {
                Toggle("Practice reminders", isOn: Binding(
                    get: { viewModel.settings.notificationsEnabled },
                    set: { enabled in
                        Task { await viewModel.updateNotifications(enabled: enabled) }
                    }
                ))
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.canUseStudyFeatures)
    }
}
