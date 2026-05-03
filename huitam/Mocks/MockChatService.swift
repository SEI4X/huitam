import Foundation

@MainActor
final class MockChatService: ChatServicing {
    private var chats: [ChatSummary]
    private var messagesByChatID: [UUID: [ChatMessage]]

    init(
        chats: [ChatSummary]? = nil,
        messagesByChatID: [UUID: [ChatMessage]]? = nil
    ) {
        self.chats = chats ?? MockAppData.chats
        self.messagesByChatID = messagesByChatID ?? MockAppData.messagesByChatID
    }

    func loadChatSummaries() async throws -> [ChatSummary] {
        chats.sorted { $0.timestamp > $1.timestamp }
    }

    func chatSummaryUpdates() -> AsyncStream<Result<[ChatSummary], Error>> {
        AsyncStream { continuation in
            continuation.yield(.success(chats.sorted { $0.timestamp > $1.timestamp }))
            continuation.finish()
        }
    }

    func loadRecentMessages(chat: ChatSummary, limit: Int) async throws -> [ChatMessage] {
        Array((messagesByChatID[chat.id] ?? []).sorted { $0.timestamp > $1.timestamp }.prefix(limit))
            .sorted { $0.timestamp < $1.timestamp }
    }

    func loadEarlierMessages(chat: ChatSummary, before oldestMessage: ChatMessage, limit: Int) async throws -> [ChatMessage] {
        Array((messagesByChatID[chat.id] ?? [])
            .filter { $0.timestamp < oldestMessage.timestamp }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit))
            .sorted { $0.timestamp < $1.timestamp }
    }

    func messageUpdates(chat: ChatSummary, after date: Date?) -> AsyncStream<Result<[ChatMessage], Error>> {
        AsyncStream { continuation in
            continuation.yield(.success([]))
            continuation.finish()
        }
    }

    func sendMessage(chat: ChatSummary, draft: String, localID: UUID, reply: MessageReplyPreview?) async throws -> ChatMessage {
        let message = ChatMessage(
            id: localID,
            chatID: chat.id,
            senderID: MockAppData.currentUserID,
            timestamp: Date(),
            translatedText: draft,
            originalText: "[Translated for friend] \(draft)",
            direction: .outgoing,
            deliveryState: .sent,
            reply: reply
        )
        messagesByChatID[chat.id, default: []].append(message)
        return message
    }

    func markChatRead(chat: ChatSummary) async throws {
        messagesByChatID[chat.id] = (messagesByChatID[chat.id] ?? []).map { message in
            guard message.direction == .incoming else { return message }
            var readMessage = message
            readMessage.deliveryState = .read
            return readMessage
        }
    }

    func deleteMessage(chat: ChatSummary, message: ChatMessage) async throws {
        messagesByChatID[chat.id, default: []].removeAll { $0.id == message.id }
    }

    func analyze(message: ChatMessage) async throws -> MessageAnalysis {
        MockAppData.analysis(for: message)
    }
}
