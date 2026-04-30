import Foundation

struct MockTranslationService: TranslationServicing {
    func translate(_ text: String, from source: AppLanguage, to target: AppLanguage) async throws -> String {
        "[\(target.shortCode)] \(text)"
    }
}
