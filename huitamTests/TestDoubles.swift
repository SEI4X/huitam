import Foundation
import AuthenticationServices
@testable import huitam

@MainActor
final class RecordingChatService: ChatServicing {
    var loadedChatIDs: [UUID] = []
    var sentDrafts: [String] = []
    var sentMessageIDs: [UUID] = []
    var sentReplies: [MessageReplyPreview?] = []
    var recentMessageLoadLimits: [Int] = []
    var earlierMessageLoadRequests: [(before: UUID, limit: Int)] = []
    var messageUpdateAfterDates: [Date?] = []
    var markedReadChatIDs: [UUID] = []
    var deletedMessageIDs: [UUID] = []
    var chats = MockAppData.chats
    var chatUpdates: [[ChatSummary]] = []
    var messagesByChatID = MockAppData.messagesByChatID
    var sendDelayNanoseconds: UInt64 = 0
    var sendError: Error?

    func loadChatSummaries() async throws -> [ChatSummary] {
        chats
    }

    func chatSummaryUpdates() -> AsyncStream<Result<[ChatSummary], Error>> {
        AsyncStream { continuation in
            let updates = chatUpdates.isEmpty ? [chats] : chatUpdates
            for update in updates {
                continuation.yield(.success(update))
            }
            continuation.finish()
        }
    }

    func loadRecentMessages(chat: ChatSummary, limit: Int) async throws -> [ChatMessage] {
        loadedChatIDs.append(chat.id)
        recentMessageLoadLimits.append(limit)
        return Array((messagesByChatID[chat.id] ?? []).sorted { $0.timestamp > $1.timestamp }.prefix(limit))
            .sorted { $0.timestamp < $1.timestamp }
    }

    func loadEarlierMessages(chat: ChatSummary, before oldestMessage: ChatMessage, limit: Int) async throws -> [ChatMessage] {
        earlierMessageLoadRequests.append((before: oldestMessage.id, limit: limit))
        return Array((messagesByChatID[chat.id] ?? [])
            .filter { $0.timestamp < oldestMessage.timestamp }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit))
            .sorted { $0.timestamp < $1.timestamp }
    }

    func messageUpdates(chat: ChatSummary, after date: Date?) -> AsyncStream<Result<[ChatMessage], Error>> {
        messageUpdateAfterDates.append(date)
        return AsyncStream { continuation in
            continuation.yield(.success([]))
            continuation.finish()
        }
    }

    func sendMessage(chat: ChatSummary, draft: String, localID: UUID, reply: MessageReplyPreview?) async throws -> ChatMessage {
        if sendDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: sendDelayNanoseconds)
        }
        if let sendError {
            throw sendError
        }
        sentDrafts.append(draft)
        sentMessageIDs.append(localID)
        sentReplies.append(reply)
        let message = ChatMessage(
            id: localID,
            chatID: chat.id,
            senderID: MockAppData.currentUserID,
            timestamp: Date(),
            translatedText: draft,
            originalText: "[friend language] \(draft)",
            direction: .outgoing,
            deliveryState: .sent,
            reply: reply
        )
        messagesByChatID[chat.id, default: []].append(message)
        return message
    }

    func markChatRead(chat: ChatSummary) async throws {
        markedReadChatIDs.append(chat.id)
    }

    func deleteMessage(chat: ChatSummary, message: ChatMessage) async throws {
        deletedMessageIDs.append(message.id)
        messagesByChatID[chat.id, default: []].removeAll { $0.id == message.id }
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
final class RecordingNotificationPermissionService: NotificationPermissionServicing {
    var registrationResult = false
    var registrationRequests: [Bool] = []

    func updateRegistration(enabled: Bool) async -> Bool {
        registrationRequests.append(enabled)
        return registrationResult
    }
}

final class RecordingPresenceService: PresenceServicing {
    var observedUserIDs: [String] = []
    var statusesByUserID: [String: PresenceStatus] = [
        "firebase-camille": PresenceStatus(isOnline: true, lastSeenAt: Date()),
        "firebase-mateo": PresenceStatus(isOnline: false, lastSeenAt: Date())
    ]
    private(set) var isTrackingCurrentUser = false

    func startTrackingCurrentUser() async {
        isTrackingCurrentUser = true
    }

    func stopTrackingCurrentUser() {
        isTrackingCurrentUser = false
    }

    func presenceUpdates(for userID: String) -> AsyncStream<PresenceStatus> {
        observedUserIDs.append(userID)
        return AsyncStream { continuation in
            continuation.yield(statusesByUserID[userID] ?? .offline)
            continuation.finish()
        }
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
final class RecordingAuthService: AuthServicing {
    var state: AuthSessionState
    var signOutCount = 0
    var deletedAccountReasons: [String] = []
    var googleSignInTokens: [(idToken: String, accessToken: String)] = []
    var authStateUpdates: AsyncStream<AuthSessionState> {
        AsyncStream { continuation in
            continuation.yield(state)
            continuation.finish()
        }
    }

    init(initialState: AuthSessionState = AuthSessionState(userID: "user-1")) {
        self.state = initialState
    }

    func loadSession() async -> AuthSessionState {
        state
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws -> AuthSessionState {
        state = AuthSessionState(userID: "apple-user")
        return state
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws -> AuthSessionState {
        googleSignInTokens.append((idToken, accessToken))
        state = AuthSessionState(userID: "google-user")
        return state
    }

    func signOut() async throws {
        signOutCount += 1
        state = .signedOut
    }

    func deleteAccount(reason: String) async throws {
        deletedAccountReasons.append(reason)
        state = .signedOut
    }
}

@MainActor
final class RecordingProfileService: ProfileServicing {
    var profile = MockAppData.profile
    var updatedProfiles: [UserProfile] = []
    var cachedProfile: UserProfile? {
        profile
    }

    func loadProfile() async throws -> UserProfile {
        profile
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        updatedProfiles.append(profile)
        self.profile = profile
        return profile
    }
}

@MainActor
final class RecordingFriendService: FriendServicing {
    var queries: [String] = []
    var loadedInviteIDs: [String] = []
    var createdInviteRequests: [PracticeInviteRequest] = []
    var acceptedInvites: [PracticeInvite] = []
    var openedAccountNicknames: [String] = []

    func search(byNickname query: String) async throws -> [FriendSearchResult] {
        queries.append(query)
        return MockAppData.friendResults.filter { $0.nickname.contains(query) }
    }

    func loadInvite(id: String) async throws -> PracticeInvite {
        loadedInviteIDs.append(id)
        return MockAppData.sampleInvite
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

    func openAccountChat(nickname: String, as role: ChatParticipantRole) async throws -> ChatSummary {
        openedAccountNicknames.append(nickname)
        return ChatSummary(
            id: UUID(),
            participant: MockAppData.camille,
            lastMessagePreview: "",
            timestamp: Date(),
            unreadCount: 0,
            nativeLanguage: .russian,
            practiceLanguage: role.learningLanguage,
            currentUserRole: role,
            participantRole: .learner(.english)
        )
    }
}
