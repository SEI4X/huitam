import Foundation

enum TranslationIntent: Equatable {
    case simpleMessage
    case chatMessage
    case correction
    case grammarExplanation
    case replySuggestion
}

enum TranslationRoute: Equatable {
    case appleOnDevice
    case cloudTranslation
    case gemini
}

enum TranslationRoutingPolicy {
    static func route(
        source: AppLanguage,
        target: AppLanguage,
        intent: TranslationIntent,
        prefersOnDevice: Bool
    ) -> TranslationRoute {
        switch intent {
        case .simpleMessage where prefersOnDevice && supportsAppleTranslation(source: source, target: target):
            return .appleOnDevice
        case .simpleMessage, .chatMessage:
            return .cloudTranslation
        case .correction, .grammarExplanation, .replySuggestion:
            return .gemini
        }
    }

    private static func supportsAppleTranslation(source: AppLanguage, target: AppLanguage) -> Bool {
        source != target && appleSupportedLanguages.contains(source) && appleSupportedLanguages.contains(target)
    }

    private static let appleSupportedLanguages: Set<AppLanguage> = [
        .english,
        .french,
        .spanish,
        .german,
        .italian,
        .portuguese,
        .russian,
        .japanese,
        .korean,
        .chinese
    ]
}
