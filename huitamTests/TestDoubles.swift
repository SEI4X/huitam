import Foundation
@testable import huitam

@MainActor
final class RecordingChatService: ChatServicing {
    var loadedChatIDs: [UUID] = []
    var sentDrafts: [String] = []
    var chats = MockAppData.chats
    var messagesByChatID = MockAppData.messagesByChatID

    func loadChatSummaries() async throws -> [ChatSummary] {
        chats
    }

    func loadMessages(chatID: UUID) async throws -> [ChatMessage] {
        loadedChatIDs.append(chatID)
        return messagesByChatID[chatID] ?? []
    }

    func sendMessage(chatID: UUID, draft: String) async throws -> ChatMessage {
        sentDrafts.append(draft)
        let message = ChatMessage(
            id: UUID(),
            chatID: chatID,
            senderID: MockAppData.currentUserID,
            timestamp: Date(),
            translatedText: draft,
            originalText: "[friend language] \(draft)",
            direction: .outgoing,
            deliveryState: .sent
        )
        messagesByChatID[chatID, default: []].append(message)
        return message
    }

    func analyze(message: ChatMessage) async throws -> MessageAnalysis {
        MockAppData.analysis(for: message)
    }
}

@MainActor
final class RecordingOnboardingService: OnboardingServicing {
    var state = OnboardingState.notStarted
    var completedRoles: [ChatParticipantRole] = []

    func loadState() async throws -> OnboardingState {
        state
    }

    func complete(role: ChatParticipantRole, nativeLanguage: AppLanguage) async throws -> OnboardingState {
        completedRoles.append(role)
        state = OnboardingState(
            hasCompletedOnboarding: true,
            currentUserRole: role,
            nativeLanguage: nativeLanguage
        )
        return state
    }
}

@MainActor
final class RecordingSubscriptionService: SubscriptionServicing {
    var entitlement = SubscriptionEntitlement.trial
    var startedTrialCount = 0

    func loadEntitlement() async throws -> SubscriptionEntitlement {
        entitlement
    }

    func startTrial() async throws -> SubscriptionEntitlement {
        startedTrialCount += 1
        entitlement = .trial
        return entitlement
    }
}

@MainActor
final class RecordingStudyCardService: StudyCardServicing {
    var cards = MockAppData.studyCards
    var savedCards: [StudyCard] = []

    func loadCards() async throws -> [StudyCard] {
        cards
    }

    func saveCards(_ cards: [StudyCard]) async throws {
        savedCards.append(contentsOf: cards)
        self.cards.append(contentsOf: cards)
    }

    func removeCard(id: UUID) async throws {
        cards.removeAll { $0.id == id }
    }
}

struct RecordingAIAssistService: AIAssistServicing {
    func suggestReply(for chat: ChatSummary, messages: [ChatMessage]) async throws -> String {
        "Sounds good, see you soon."
    }

    func correctDraft(_ draft: String, targetLanguage: AppLanguage) async throws -> String {
        draft
    }

    func explain(_ text: String, language: AppLanguage) async throws -> String {
        text
    }
}

@MainActor
final class RecordingSettingsService: SettingsServicing {
    var settings = MockAppData.settings
    var settingsUpdates: AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(settings)
            continuation.finish()
        }
    }

    func loadSettings() async throws -> AppSettings {
        settings
    }

    func updateSettings(_ settings: AppSettings) async throws -> AppSettings {
        self.settings = settings
        return settings
    }
}

@MainActor
final class RecordingFriendService: FriendServicing {
    var queries: [String] = []
    var createdInviteRequests: [PracticeInviteRequest] = []
    var acceptedInvites: [PracticeInvite] = []

    func search(byNickname query: String) async throws -> [FriendSearchResult] {
        queries.append(query)
        return MockAppData.friendResults.filter { $0.nickname.contains(query) }
    }

    func sharePayload() async throws -> String {
        "huitam://add/alex"
    }

    func scanQRCodeMockResult() async throws -> FriendSearchResult? {
        MockAppData.friendResults.first
    }

    func loadInvite(id: String) async throws -> PracticeInvite {
        MockAppData.sampleInvite
    }

    func createPracticeInvite(_ request: PracticeInviteRequest) async throws -> PracticeInvite {
        createdInviteRequests.append(request)
        return PracticeInvite(
            id: "mock-invite",
            inviterDisplayName: "Alex",
            inviterNativeLanguage: .russian,
            inviterLearningLanguage: .english,
            guestNativeLanguage: request.guestNativeLanguage,
            guestLearningLanguage: request.guestLearningLanguage
        )
    }

    func acceptInvite(_ invite: PracticeInvite, as role: ChatParticipantRole) async throws -> ChatSummary {
        acceptedInvites.append(invite)
        return ChatSummary(
            id: UUID(),
            participant: MockAppData.camille,
            lastMessagePreview: "You joined Alex's practice chat.",
            timestamp: Date(),
            unreadCount: 0,
            nativeLanguage: invite.guestNativeLanguage,
            practiceLanguage: role.learningLanguage,
            currentUserRole: role,
            participantRole: .learner(invite.inviterLearningLanguage)
        )
    }
}
