import Foundation

@MainActor
final class AppDependencyContainer {
    let authService: AuthServicing
    let chatService: ChatServicing
    let profileService: ProfileServicing
    let studyCardService: StudyCardServicing
    let friendService: FriendServicing
    let translationService: TranslationServicing
    let aiAssistService: AIAssistServicing
    let settingsService: SettingsServicing
    let onboardingService: OnboardingServicing
    let subscriptionService: SubscriptionServicing
    let presenceService: PresenceServicing

    init(
        authService: AuthServicing,
        chatService: ChatServicing,
        profileService: ProfileServicing,
        studyCardService: StudyCardServicing,
        friendService: FriendServicing,
        translationService: TranslationServicing,
        aiAssistService: AIAssistServicing,
        settingsService: SettingsServicing,
        onboardingService: OnboardingServicing,
        subscriptionService: SubscriptionServicing,
        presenceService: PresenceServicing
    ) {
        self.authService = authService
        self.chatService = chatService
        self.profileService = profileService
        self.studyCardService = studyCardService
        self.friendService = friendService
        self.translationService = translationService
        self.aiAssistService = aiAssistService
        self.settingsService = settingsService
        self.onboardingService = onboardingService
        self.subscriptionService = subscriptionService
        self.presenceService = presenceService
    }

    static func mock() -> AppDependencyContainer {
        AppDependencyContainer(
            authService: MockAuthService(),
            chatService: MockChatService(),
            profileService: MockProfileService(),
            studyCardService: MockStudyCardService(),
            friendService: MockFriendService(),
            translationService: MockTranslationService(),
            aiAssistService: MockAIAssistService(),
            settingsService: MockSettingsService(),
            onboardingService: MockOnboardingService(),
            subscriptionService: MockSubscriptionService(),
            presenceService: MockPresenceService()
        )
    }

    static func production() -> AppDependencyContainer {
        FirebaseBootstrap.configureIfNeeded()

        let authSession = FirebaseAuthSession()
        let authService = FirebaseAuthService()
        let settingsService = FirebaseSettingsService(authSession: authSession)
        let translationService = FirebaseTranslationService()
        let chatService = FirebaseChatService(
            authSession: authSession,
            translationService: translationService
        )

        return AppDependencyContainer(
            authService: authService,
            chatService: chatService,
            profileService: FirebaseProfileService(authSession: authSession),
            studyCardService: FirebaseStudyCardService(authSession: authSession),
            friendService: FirebaseFriendService(authSession: authSession),
            translationService: translationService,
            aiAssistService: FirebaseAIAssistService(),
            settingsService: settingsService,
            onboardingService: FirebaseOnboardingService(
                authSession: authSession,
                settingsService: settingsService
            ),
            subscriptionService: FirebaseSubscriptionService(authSession: authSession),
            presenceService: FirebasePresenceService(authSession: authSession)
        )
    }
}
