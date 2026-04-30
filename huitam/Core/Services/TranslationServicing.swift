import Foundation

@MainActor
protocol TranslationServicing {
    func translate(_ text: String, from source: AppLanguage, to target: AppLanguage) async throws -> String
}
