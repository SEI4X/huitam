import Foundation

@MainActor
final class FirebaseAIAssistService: AIAssistServicing {
    func suggestReply(for chat: ChatSummary, messages: [ChatMessage]) async throws -> String {
        let result = try await FirebaseAsync.call(
            "suggestReply",
            payload: [
                "chatId": chat.id.uuidString,
                "targetLanguage": chat.practiceLanguage?.rawValue ?? AppDefaults.settings.learningLanguage.language?.rawValue ?? AppLanguage.english.rawValue,
                "messages": messages.suffix(12).map { message in
                    [
                        "text": message.translatedText,
                        "direction": message.direction == .outgoing ? "outgoing" : "incoming"
                    ]
                }
            ]
        )
        return try textResult(result, field: "suggestion")
    }

    func correctDraft(_ draft: String, targetLanguage: AppLanguage) async throws -> String {
        let result = try await FirebaseAsync.call(
            "correctDraft",
            payload: [
                "text": draft,
                "targetLanguage": targetLanguage.rawValue
            ]
        )
        return try textResult(result, field: "correctedText")
    }

    func explain(_ text: String, language: AppLanguage) async throws -> String {
        let result = try await FirebaseAsync.call(
            "explainText",
            payload: [
                "text": text,
                "language": language.rawValue
            ]
        )
        return try textResult(result, field: "explanation")
    }

    private func textResult(_ result: Any, field: String) throws -> String {
        guard let data = result as? [String: Any], let text = data[field] as? String else {
            throw FirebaseMappingError.missingField(field)
        }
        return text
    }
}
