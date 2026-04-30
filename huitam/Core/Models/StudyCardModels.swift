import Foundation

enum StudyCardType: String, CaseIterable, Identifiable, Hashable {
    case word
    case phrase
    case grammar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .word: "Words"
        case .phrase: "Phrases"
        case .grammar: "Grammar"
        }
    }
}

enum StudyCardFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case word
    case phrase
    case grammar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "All"
        case .word: "Words"
        case .phrase: "Phrases"
        case .grammar: "Grammar"
        }
    }

    var cardType: StudyCardType? {
        switch self {
        case .all: nil
        case .word: .word
        case .phrase: .phrase
        case .grammar: .grammar
        }
    }
}

struct StudyCard: Identifiable, Hashable {
    var id: UUID
    var sourceMessageID: UUID?
    var type: StudyCardType
    var frontText: String
    var backText: String
    var note: String
    var language: AppLanguage
    var createdAt: Date
}
