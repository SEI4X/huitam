import SwiftUI

struct ContentView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.scenePhase) private var scenePhase
    @State private var authGateViewModel: AuthGateViewModel?
    @State private var onboardingViewModel: OnboardingViewModel?
    @State private var pendingInviteID: String?
    @State private var pendingAccountNickname: String?

    var body: some View {
        ZStack {
            currentContent
                .id(contentTransitionKey)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .animation(.easeInOut(duration: 0.24), value: contentTransitionKey)
        .task {
            if authGateViewModel == nil {
                let viewModel = AuthGateViewModel(authService: dependencies.authService)
                authGateViewModel = viewModel
                await viewModel.startObserving()
            }
        }
        .task(id: authGateViewModel?.userID) {
            guard authGateViewModel?.isAuthenticated == true else {
                onboardingViewModel = nil
                dependencies.presenceService.stopTrackingCurrentUser()
                return
            }

            if onboardingViewModel == nil {
                let viewModel = OnboardingViewModel(
                    onboardingService: dependencies.onboardingService,
                    settingsService: dependencies.settingsService,
                    profileService: dependencies.profileService
                )
                onboardingViewModel = viewModel
                await viewModel.load()
            }
        }
        .task(id: presenceTrackingKey) {
            guard authGateViewModel?.isAuthenticated == true, scenePhase == .active else {
                dependencies.presenceService.stopTrackingCurrentUser()
                return
            }

            await dependencies.presenceService.startTrackingCurrentUser()
        }
        .onOpenURL { url in
            guard let inviteID = InviteDeepLinkParser.inviteID(from: url) else {
                pendingAccountNickname = InviteDeepLinkParser.accountNickname(from: url)
                return
            }

            pendingInviteID = inviteID
        }
        .onDisappear {
            dependencies.presenceService.stopTrackingCurrentUser()
        }
    }

    @ViewBuilder
    private var currentContent: some View {
        if let authGateViewModel {
            if authGateViewModel.isLoading {
                AppLaunchView()
            } else if authGateViewModel.isAuthenticated == false {
                AuthView(container: dependencies)
            } else {
                authenticatedContent
            }
        } else {
            AppLaunchView()
        }
    }

    private var contentTransitionKey: String {
        guard let authGateViewModel else { return "launch" }
        if authGateViewModel.isLoading { return "launch" }
        if authGateViewModel.isAuthenticated == false { return "auth" }
        guard let onboardingViewModel else { return "launch" }
        if onboardingViewModel.isLoading { return "launch" }
        return onboardingViewModel.state.hasCompletedOnboarding ? "chats" : "onboarding"
    }

    private var presenceTrackingKey: String {
        "\(authGateViewModel?.userID ?? "signed-out")-\(scenePhase)"
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        if let onboardingViewModel {
            if onboardingViewModel.isLoading {
                AppLaunchView()
            } else if onboardingViewModel.state.hasCompletedOnboarding {
                ChatsListView(
                    container: dependencies,
                    pendingInviteID: $pendingInviteID,
                    pendingAccountNickname: $pendingAccountNickname,
                    defaultInviteRole: onboardingViewModel.state.currentUserRole,
                    currentNickname: onboardingViewModel.nickname
                )
            } else {
                OnboardingView(
                    viewModel: onboardingViewModel,
                    container: dependencies
                )
            }
        } else {
            AppLaunchView()
        }
    }
}

private struct AppLaunchView: View {
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

#Preview {
    ContentView()
        .environment(\.appDependencies, .mock())
}
