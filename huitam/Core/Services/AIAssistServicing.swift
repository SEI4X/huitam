import Foundation

@MainActor
protocol AIAssistServicing {
    func suggestReply(for chat: ChatSummary, messages: [ChatMessage]) async throws -> String
    func correctDraft(_ draft: String, targetLanguage: AppLanguage) async throws -> String
    func explain(_ text: String, language: AppLanguage) async throws -> String
}
