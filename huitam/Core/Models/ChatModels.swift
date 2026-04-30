import Foundation

struct ChatSummary: Identifiable, Hashable {
    var id: UUID
    var participant: ChatParticipant
    var lastMessagePreview: String
    var timestamp: Date
    var unreadCount: Int
    var nativeLanguage: AppLanguage
    var practiceLanguage: AppLanguage?
}

enum MessageDirection: Hashable {
    case incoming
    case outgoing
}

enum MessageDeliveryState: Hashable {
    case sent
    case delivered
    case read
}

struct ChatMessage: Identifiable, Hashable {
    var id: UUID
    var chatID: UUID
    var senderID: UUID
    var timestamp: Date
    var translatedText: String
    var originalText: String
    var direction: MessageDirection
    var deliveryState: MessageDeliveryState
    var correction: MessageCorrection? = nil
}

struct MessageCorrection: Hashable {
    var correctedText: String
    var mistakeText: String
    var explanation: String
}

struct MessageToken: Identifiable, Hashable {
    var id: UUID
    var text: String
    var translation: String
    var partOfSpeech: String
}

struct GrammarNote: Identifiable, Hashable {
    var id: UUID
    var title: String
    var explanation: String
}

struct MessageAnalysis: Identifiable, Equatable {
    var messageID: UUID
    var tokens: [MessageToken]
    var phraseSuggestions: [String]
    var grammarNotes: [GrammarNote]
    var selectedTokenIDs: Set<UUID> = []

    var selectedTokens: [MessageToken] {
        tokens.filter { selectedTokenIDs.contains($0.id) }
    }

    var id: UUID {
        messageID
    }
}
