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
}
