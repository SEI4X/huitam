import XCTest
@testable import huitam

@MainActor
final class ChatViewModelTests: XCTestCase {
    override func setUp() async throws {
        ChatViewModel.resetPendingMessagesForTesting()
    }

    func testLoadMessagesUsesChatService() async throws {
        let services = TestServices()
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.messages.count, 3)
        XCTAssertEqual(services.chat.loadedChatIDs, [MockAppData.chats[0].id])
        XCTAssertEqual(services.chat.recentMessageLoadLimits, [15])
    }

    func testReopeningChatUsesCachedMessagesAndOnlyListensForUpdates() async throws {
        let services = TestServices()
        let firstViewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        await firstViewModel.load()

        let secondViewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        await secondViewModel.load()

        XCTAssertEqual(services.chat.recentMessageLoadLimits, [15])
        XCTAssertEqual(secondViewModel.messages.count, firstViewModel.messages.count)
        XCTAssertGreaterThanOrEqual(services.chat.messageUpdateAfterDates.count, 2)
        XCTAssertNotNil(services.chat.messageUpdateAfterDates.last ?? nil)
    }

    func testLoadEarlierMessagesRequestsOnePageBeforeOldestLoadedMessage() async throws {
        let services = TestServices()
        services.chat.messagesByChatID[MockAppData.chats[0].id] = makeMessages(count: 25, chatID: MockAppData.chats[0].id)
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        await viewModel.load()
        let oldestRecentMessage = try XCTUnwrap(viewModel.messages.first)

        await viewModel.loadEarlierMessages()

        XCTAssertEqual(services.chat.earlierMessageLoadRequests.count, 1)
        XCTAssertEqual(services.chat.earlierMessageLoadRequests.first?.before, oldestRecentMessage.id)
        XCTAssertEqual(services.chat.earlierMessageLoadRequests.first?.limit, 15)
        XCTAssertEqual(viewModel.messages.count, 25)
    }

    func testSendDraftTranslatesAndClearsDraft() async throws {
        let services = TestServices()
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        viewModel.draft = "I can meet after work"

        await viewModel.sendDraft()

        XCTAssertEqual(viewModel.draft, "")
        XCTAssertEqual(viewModel.messages.last?.translatedText, "I can meet after work")
        XCTAssertEqual(services.chat.sentDrafts, ["I can meet after work"])
    }

    func testSendDraftUsesSameMessageIDForLocalAndRemoteMessage() async throws {
        let services = TestServices()
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        viewModel.draft = "Keep one bubble"

        await viewModel.sendDraft()

        let message = try XCTUnwrap(viewModel.messages.last)
        XCTAssertEqual(services.chat.sentMessageIDs, [message.id])
        XCTAssertEqual(viewModel.messages.filter { $0.id == message.id }.count, 1)
    }

    func testSendDraftShowsOptimisticSendingMessageBeforeNetworkFinishes() async throws {
        let services = TestServices()
        services.chat.sendDelayNanoseconds = 250_000_000
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        viewModel.draft = "Sending should feel instant"

        let sendTask = Task {
            await viewModel.sendDraft()
        }
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.draft, "")
        XCTAssertEqual(viewModel.messages.last?.translatedText, "Sending should feel instant")
        XCTAssertEqual(viewModel.messages.last?.deliveryState, .sending)

        await sendTask.value

        XCTAssertEqual(viewModel.messages.last?.deliveryState, .sent)
        XCTAssertEqual(services.chat.sentDrafts, ["Sending should feel instant"])
    }

    func testSendDraftMarksMessageFailedWhenSendFails() async throws {
        let services = TestServices()
        services.chat.sendError = TestSendError.rejected
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        viewModel.draft = "This should fail"

        await viewModel.sendDraft()

        XCTAssertEqual(viewModel.draft, "")
        XCTAssertEqual(viewModel.messages.last?.translatedText, "This should fail")
        XCTAssertEqual(viewModel.messages.last?.deliveryState, .failed)
        XCTAssertNotNil(viewModel.messages.last?.errorMessage)
    }

    func testPendingFailedMessageSurvivesChatViewModelReload() async throws {
        let services = TestServices()
        services.chat.sendError = TestSendError.rejected
        let firstViewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        firstViewModel.draft = "Do not disappear"

        await firstViewModel.sendDraft()

        let secondViewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        await secondViewModel.load()

        XCTAssertTrue(secondViewModel.messages.contains { message in
            message.translatedText == "Do not disappear" && message.deliveryState == .failed
        })
    }

    func testRetryFailedMessageSendsOriginalDraft() async throws {
        let services = TestServices()
        services.chat.sendError = TestSendError.rejected
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        viewModel.draft = "Retry me"
        await viewModel.sendDraft()
        let failedMessage = try XCTUnwrap(viewModel.messages.last)

        services.chat.sendError = nil
        await viewModel.retry(failedMessage)

        XCTAssertEqual(viewModel.messages.last?.deliveryState, .sent)
        XCTAssertEqual(services.chat.sentDrafts, ["Retry me"])
    }

    func testDeleteFailedMessageRemovesPendingMessage() async throws {
        let services = TestServices()
        services.chat.sendError = TestSendError.rejected
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        viewModel.draft = "Delete me"
        await viewModel.sendDraft()
        let failedMessage = try XCTUnwrap(viewModel.messages.last)

        viewModel.deleteFailedMessage(failedMessage)

        XCTAssertFalse(viewModel.messages.contains { $0.id == failedMessage.id })
    }

    func testEmptyDraftDoesNotSend() async throws {
        let services = TestServices()
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        viewModel.draft = "   "

        await viewModel.sendDraft()

        XCTAssertTrue(services.chat.sentDrafts.isEmpty)
    }

    func testRevealOriginalTracksExpandedMessage() async throws {
        let services = TestServices()
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        await viewModel.load()
        let message = try XCTUnwrap(viewModel.messages.first)

        viewModel.toggleOriginal(for: message)

        XCTAssertTrue(viewModel.isOriginalVisible(for: message))
    }

    func testAnalyzeMessageCreatesSelectableTokens() async throws {
        let services = TestServices()
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        await viewModel.load()
        let message = try XCTUnwrap(viewModel.messages.first)

        await viewModel.analyze(message)

        XCTAssertEqual(viewModel.analysis?.tokens.map(\.text), ["Bonjour", "Alex"])
    }

    func testSaveSelectedTokensCreatesStudyCardsWhenLearningIsEnabled() async throws {
        let services = TestServices()
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        await viewModel.load()
        let message = try XCTUnwrap(viewModel.messages.first)
        await viewModel.analyze(message)
        viewModel.toggleTokenSelection(viewModel.analysis!.tokens[0])

        await viewModel.saveSelectedTokens()

        XCTAssertEqual(services.cards.savedCards.map(\.frontText), ["Bonjour"])
    }

    func testLearningDisabledPreventsSavingStudyCards() async throws {
        let services = TestServices()
        services.settings.settings.learningLanguage = .none
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )

        await viewModel.loadSettings()

        XCTAssertFalse(viewModel.canUseStudyFeatures)
    }

    func testFreeLearnerNeedsSubscriptionAndCannotUseStudyFeatures() async throws {
        let services = TestServices()
        services.subscription.entitlement = .free
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )

        await viewModel.load()

        XCTAssertTrue(viewModel.needsSubscription)
        XCTAssertFalse(viewModel.canUseStudyFeatures)
    }

    func testCompanionDoesNotNeedSubscription() async throws {
        let services = TestServices()
        services.subscription.entitlement = .free
        var chat = MockAppData.chats[0]
        chat.currentUserRole = .companion
        let viewModel = ChatViewModel(
            chat: chat,
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )

        await viewModel.load()

        XCTAssertFalse(viewModel.needsSubscription)
        XCTAssertFalse(viewModel.canUseStudyFeatures)
    }

    func testStartingTrialUnlocksLearnerStudyFeatures() async throws {
        let services = TestServices()
        services.subscription.entitlement = .free
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )
        await viewModel.load()

        await viewModel.startLearnerTrial()

        XCTAssertFalse(viewModel.needsSubscription)
        XCTAssertTrue(viewModel.canUseStudyFeatures)
        XCTAssertEqual(services.subscription.startedTrialCount, 1)
    }

    func testAISuggestionUpdatesDraft() async throws {
        let services = TestServices()
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription
        )

        await viewModel.suggestReply()

        XCTAssertEqual(viewModel.draft, "Sounds good, see you soon.")
    }

    func testStartObservingPresenceUpdatesParticipantStatus() async throws {
        let services = TestServices()
        let viewModel = ChatViewModel(
            chat: MockAppData.chats[0],
            chatService: services.chat,
            studyCardService: services.cards,
            aiAssistService: services.ai,
            settingsService: services.settings,
            subscriptionService: services.subscription,
            presenceService: services.presence
        )

        await viewModel.startObservingPresence()

        XCTAssertEqual(services.presence.observedUserIDs, ["firebase-camille"])
        XCTAssertTrue(viewModel.participantPresence.isOnline)
        XCTAssertEqual(viewModel.participantPresence.label, "online")
    }
}

@MainActor
private final class TestServices {
    let chat = RecordingChatService()
    let cards = RecordingStudyCardService()
    let ai = RecordingAIAssistService()
    let settings = RecordingSettingsService()
    let subscription = RecordingSubscriptionService()
    let presence = RecordingPresenceService()
}

private enum TestSendError: LocalizedError {
    case rejected

    var errorDescription: String? {
        "Send rejected"
    }
}

private func makeMessages(count: Int, chatID: UUID) -> [ChatMessage] {
    (0..<count).map { index in
        let date = Date(timeIntervalSince1970: Double(index + 1))
        return ChatMessage(
            id: StableID.uuid(from: "message-\(index)"),
            chatID: chatID,
            senderID: MockAppData.currentUserID,
            timestamp: date,
            updatedAt: date,
            translatedText: "Message \(index)",
            originalText: "Message \(index)",
            direction: .outgoing,
            deliveryState: .sent
        )
    }
}
