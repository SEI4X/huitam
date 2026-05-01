import SwiftUI

struct ContentView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var onboardingViewModel: OnboardingViewModel?
    @State private var pendingInvite: PendingInviteDeepLink?

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
        .onOpenURL { url in
            guard let inviteID = InviteDeepLinkParser.inviteID(from: url) else {
                return
            }

            pendingInvite = PendingInviteDeepLink(inviteID: inviteID)
        }
        .sheet(item: $pendingInvite) { pendingInvite in
            NavigationStack {
                InviteLookupView(
                    container: dependencies,
                    initialInviteID: pendingInvite.inviteID
                )
            }
        }
    }
}

private struct PendingInviteDeepLink: Identifiable {
    let inviteID: String

    var id: String {
        inviteID
    }
}

#Preview {
    ContentView()
        .environment(\.appDependencies, .mock())
}
