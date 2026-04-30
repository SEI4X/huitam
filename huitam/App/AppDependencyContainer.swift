import Foundation

@MainActor
final class AppDependencyContainer {
    let chatService: ChatServicing
    let profileService: ProfileServicing
    let studyCardService: StudyCardServicing
    let friendService: FriendServicing
    let translationService: TranslationServicing
    let aiAssistService: AIAssistServicing
    let settingsService: SettingsServicing

    init(
        chatService: ChatServicing,
        profileService: ProfileServicing,
        studyCardService: StudyCardServicing,
        friendService: FriendServicing,
        translationService: TranslationServicing,
        aiAssistService: AIAssistServicing,
        settingsService: SettingsServicing
    ) {
        self.chatService = chatService
        self.profileService = profileService
        self.studyCardService = studyCardService
        self.friendService = friendService
        self.translationService = translationService
        self.aiAssistService = aiAssistService
        self.settingsService = settingsService
    }

    static func mock() -> AppDependencyContainer {
        AppDependencyContainer(
            chatService: MockChatService(),
            profileService: MockProfileService(),
            studyCardService: MockStudyCardService(),
            friendService: MockFriendService(),
            translationService: MockTranslationService(),
            aiAssistService: MockAIAssistService(),
            settingsService: MockSettingsService()
        )
    }
}
