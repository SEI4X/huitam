import Foundation

struct ChatSummary: Identifiable, Hashable {
    var id: UUID
    var documentID: String = ""
    var participant: ChatParticipant
    var lastMessagePreview: String
    var timestamp: Date
    var unreadCount: Int
    var nativeLanguage: AppLanguage
    var practiceLanguage: AppLanguage?
    var currentUserRole: ChatParticipantRole = .learner(.english)
    var participantRole: ChatParticipantRole = .companion
}

enum ChatParticipantRole: Hashable {
    case learner(AppLanguage)
    case companion

    var isLearner: Bool {
        switch self {
        case .learner: true
        case .companion: false
        }
    }

    var learningLanguage: AppLanguage? {
        switch self {
        case let .learner(language): language
        case .companion: nil
        }
    }

    var displayName: String {
        switch self {
        case let .learner(language): "Learning \(language.displayName)"
        case .companion: "Just chatting"
        }
    }
}

enum MessageDirection: Hashable {
    case incoming
    case outgoing
}

enum MessageDeliveryState: Hashable {
    case sending
    case sent
    case read
    case failed
}

struct ChatMessage: Identifiable, Hashable {
    var id: UUID
    var chatID: UUID
    var senderID: UUID
    var timestamp: Date
    var updatedAt: Date = Date()
    var translatedText: String
    var originalText: String
    var direction: MessageDirection
    var deliveryState: MessageDeliveryState
    var errorMessage: String? = nil
    var correction: MessageCorrection? = nil
    var reply: MessageReplyPreview? = nil
}

struct MessageReplyPreview: Hashable {
    var messageID: UUID
    var senderName: String
    var text: String
    var originalText: String?
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
