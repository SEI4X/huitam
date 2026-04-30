import Foundation

@MainActor
final class MockStudyCardService: StudyCardServicing {
    private var cards: [StudyCard]

    init(cards: [StudyCard]? = nil) {
        self.cards = cards ?? MockAppData.studyCards
    }

    func loadCards() async throws -> [StudyCard] {
        cards.sorted { $0.createdAt > $1.createdAt }
    }

    func saveCards(_ cards: [StudyCard]) async throws {
        self.cards.append(contentsOf: cards)
    }

    func removeCard(id: UUID) async throws {
        cards.removeAll { $0.id == id }
    }
}
