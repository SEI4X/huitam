import Foundation

@MainActor
final class FirebaseTranslationService: TranslationServicing {
    func translate(_ text: String, from source: AppLanguage, to target: AppLanguage) async throws -> String {
        guard source != target else { return text }

        let route = TranslationRoutingPolicy.route(
            source: source,
            target: target,
            intent: .chatMessage,
            prefersOnDevice: false
        )

        let result = try await FirebaseAsync.call(
            "translateText",
            payload: [
                "text": text,
                "sourceLanguage": source.rawValue,
                "targetLanguage": target.rawValue,
                "route": route.backendName
            ]
        )

        guard
            let data = result as? [String: Any],
            let translatedText = data["translatedText"] as? String
        else {
            throw FirebaseMappingError.missingField("translatedText")
        }

        return translatedText
    }
}

private extension TranslationRoute {
    var backendName: String {
        switch self {
        case .appleOnDevice: "appleOnDevice"
        case .cloudTranslation: "cloudTranslation"
        case .gemini: "gemini"
        }
    }
}
