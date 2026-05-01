import SwiftUI

struct ContentView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var onboardingViewModel: OnboardingViewModel?

    var body: some View {
        Group {
            if let onboardingViewModel {
                if onboardingViewModel.isLoading {
                    ProgressView()
                } else if onboardingViewModel.state.hasCompletedOnboarding {
                    ChatsListView(container: dependencies)
                } else {
                    OnboardingView(
                        viewModel: onboardingViewModel,
                        container: dependencies
                    )
                }
            } else {
                ProgressView()
            }
        }
        .task {
            if onboardingViewModel == nil {
                let viewModel = OnboardingViewModel(
                    onboardingService: dependencies.onboardingService,
                    settingsService: dependencies.settingsService
                )
                onboardingViewModel = viewModel
                await viewModel.load()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.appDependencies, .mock())
}
