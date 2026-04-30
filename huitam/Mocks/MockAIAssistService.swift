import Foundation

struct MockAIAssistService: AIAssistServicing {
    func suggestReply(for chat: ChatSummary, messages: [ChatMessage]) async throws -> String {
        "Sounds good, see you soon."
    }

    func correctDraft(_ draft: String, targetLanguage: AppLanguage) async throws -> String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func explain(_ text: String, language: AppLanguage) async throws -> String {
        "\(text) is useful in everyday \(language.displayName) conversation."
    }
}
