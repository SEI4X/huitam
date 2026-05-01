import XCTest
@testable import huitam

@MainActor
final class FirebaseMappingTests: XCTestCase {
    func testRoleRoundTripPreservesLearnerLanguage() throws {
        let role = ChatParticipantRole.learner(.french)

        let data = FirebaseDocumentMapper.data(from: role)
        let decoded = try FirebaseDocumentMapper.role(from: data)

        XCTAssertEqual(decoded, role)
    }

    func testRoleRoundTripPreservesCompanion() throws {
        let role = ChatParticipantRole.companion

        let data = FirebaseDocumentMapper.data(from: role)
        let decoded = try FirebaseDocumentMapper.role(from: data)

        XCTAssertEqual(decoded, role)
    }

    func testTranslationPolicyUsesAppleForSimpleSupportedPairs() {
        let route = TranslationRoutingPolicy.route(
            source: .french,
            target: .english,
            intent: .simpleMessage,
            prefersOnDevice: true
        )

        XCTAssertEqual(route, .appleOnDevice)
    }

    func testTranslationPolicyUsesCloudForChatQuality() {
        let route = TranslationRoutingPolicy.route(
            source: .french,
            target: .english,
            intent: .chatMessage,
            prefersOnDevice: true
        )

        XCTAssertEqual(route, .cloudTranslation)
    }

    func testTranslationPolicyUsesGeminiForExplanations() {
        let route = TranslationRoutingPolicy.route(
            source: .english,
            target: .russian,
            intent: .grammarExplanation,
            prefersOnDevice: true
        )

        XCTAssertEqual(route, .gemini)
    }

    func testMessageMapperUsesDisplayTextForCurrentUser() {
        let chatID = UUID()
        let message = FirebaseDocumentMapper.message(
            documentID: "message-1",
            data: [
                "senderUID": "user-a",
                "originalText": "Salut",
                "translatedText": "Hello",
                "displayTexts": [
                    "user-a": "Salut",
                    "user-b": "Hello there"
                ],
                "deliveryState": "sent"
            ],
            currentUID: "user-b",
            chatID: chatID
        )

        XCTAssertEqual(message.translatedText, "Hello there")
        XCTAssertEqual(message.originalText, "Salut")
        XCTAssertEqual(message.direction, .incoming)
    }

    func testMessageMapperFallsBackToTranslatedText() {
        let chatID = UUID()
        let message = FirebaseDocumentMapper.message(
            documentID: "message-2",
            data: [
                "senderUID": "user-a",
                "originalText": "Bonjour",
                "translatedText": "Good morning",
                "deliveryState": "sent"
            ],
            currentUID: "user-b",
            chatID: chatID
        )

        XCTAssertEqual(message.translatedText, "Good morning")
    }

    func testChatSummaryMapperUsesPreviewForCurrentUser() throws {
        let summary = try FirebaseDocumentMapper.chatSummary(
            documentID: "chat-1",
            data: [
                "participantUIDs": ["user-a", "user-b"],
                "roles": [
                    "user-a": FirebaseDocumentMapper.data(from: ChatParticipantRole.learner(.english)),
                    "user-b": FirebaseDocumentMapper.data(from: ChatParticipantRole.companion)
                ],
                "lastMessagePreview": "Legacy preview",
                "lastMessagePreviews": [
                    "user-a": "See you soon",
                    "user-b": "A bientot"
                ],
                "nativeLanguage": "french"
            ],
            currentUID: "user-b",
            participantProfile: [:]
        )

        XCTAssertEqual(summary.lastMessagePreview, "A bientot")
    }
}
