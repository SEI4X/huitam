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

    func loadMessages(chatID: UUID) async throws -> [ChatMessage] {
        (messagesByChatID[chatID] ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    func sendMessage(chatID: UUID, draft: String) async throws -> ChatMessage {
        let message = ChatMessage(
            id: UUID(),
            chatID: chatID,
            senderID: MockAppData.currentUserID,
            timestamp: Date(),
            translatedText: draft,
            originalText: "[Translated for friend] \(draft)",
            direction: .outgoing,
            deliveryState: .sent
        )
        messagesByChatID[chatID, default: []].append(message)
        return message
    }

    func analyze(message: ChatMessage) async throws -> MessageAnalysis {
        MockAppData.analysis(for: message)
    }
}
