import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case english
    case french
    case spanish
    case german
    case italian
    case portuguese
    case russian
    case japanese
    case korean
    case chinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .french: "French"
        case .spanish: "Spanish"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .russian: "Russian"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .chinese: "Chinese"
        }
    }

    var shortCode: String {
        switch self {
        case .english: "EN"
        case .french: "FR"
        case .spanish: "ES"
        case .german: "DE"
        case .italian: "IT"
        case .portuguese: "PT"
        case .russian: "RU"
        case .japanese: "JA"
        case .korean: "KO"
        case .chinese: "ZH"
        }
    }
}

enum LearningLanguageSelection: Hashable {
    case language(AppLanguage)
    case none

    var language: AppLanguage? {
        guard case let .language(language) = self else { return nil }
        return language
    }

    var isEnabled: Bool {
        language != nil
    }

    var displayName: String {
        switch self {
        case let .language(language): language.displayName
        case .none: "Not learning"
        }
    }
}
