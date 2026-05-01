import XCTest
@testable import huitam

@MainActor
final class ChatViewModelTests: XCTestCase {
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
}

@MainActor
private final class TestServices {
    let chat = RecordingChatService()
    let cards = RecordingStudyCardService()
    let ai = RecordingAIAssistService()
    let settings = RecordingSettingsService()
    let subscription = RecordingSubscriptionService()
}
