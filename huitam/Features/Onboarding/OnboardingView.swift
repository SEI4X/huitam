import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let viewModel: OnboardingViewModel
    let container: AppDependencyContainer

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("My language", selection: Binding(
                        get: { viewModel.nativeLanguage },
                        set: { viewModel.nativeLanguage = $0 }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }

                    Picker("Learning", selection: Binding(
                        get: { viewModel.learningLanguage },
                        set: { viewModel.learningLanguage = $0 }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                } header: {
                    Text("Languages")
                }

                Section {
                    Button {
                        Task { await viewModel.completeAsLearner() }
                    } label: {
                        Label("Practice a Language", systemImage: "graduationcap")
                    }

                    Button {
                        Task { await viewModel.completeAsCompanion() }
                    } label: {
                        Label("Just Chat", systemImage: "message")
                    }

                        NavigationLink {
                            InviteLookupView(container: container)
                        } label: {
                            Label("I Was Invited", systemImage: "link")
                        }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Huitam")
            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.state)
        }
    }
}

#Preview {
    OnboardingView(
        viewModel: OnboardingViewModel(
            onboardingService: MockOnboardingService(),
            settingsService: MockSettingsService()
        ),
        container: .mock()
    )
}
