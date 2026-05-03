import Foundation

@MainActor
protocol ChatServicing {
    func loadChatSummaries() async throws -> [ChatSummary]
    func chatSummaryUpdates() -> AsyncStream<Result<[ChatSummary], Error>>
    func loadRecentMessages(chat: ChatSummary, limit: Int) async throws -> [ChatMessage]
    func loadEarlierMessages(chat: ChatSummary, before oldestMessage: ChatMessage, limit: Int) async throws -> [ChatMessage]
    func messageUpdates(chat: ChatSummary, after date: Date?) -> AsyncStream<Result<[ChatMessage], Error>>
    func sendMessage(chat: ChatSummary, draft: String, localID: UUID, reply: MessageReplyPreview?) async throws -> ChatMessage
    func markChatRead(chat: ChatSummary) async throws
    func deleteMessage(chat: ChatSummary, message: ChatMessage) async throws
    func analyze(message: ChatMessage) async throws -> MessageAnalysis
}
