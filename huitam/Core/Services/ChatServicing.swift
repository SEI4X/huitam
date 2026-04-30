import Foundation

@MainActor
protocol ChatServicing {
    func loadChatSummaries() async throws -> [ChatSummary]
    func loadMessages(chatID: UUID) async throws -> [ChatMessage]
    func sendMessage(chatID: UUID, draft: String) async throws -> ChatMessage
    func analyze(message: ChatMessage) async throws -> MessageAnalysis
}
