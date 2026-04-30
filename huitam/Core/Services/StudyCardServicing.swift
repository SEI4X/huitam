import Foundation

@MainActor
protocol StudyCardServicing {
    func loadCards() async throws -> [StudyCard]
    func saveCards(_ cards: [StudyCard]) async throws
    func removeCard(id: UUID) async throws
}
