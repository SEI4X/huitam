import Foundation
import Observation

@MainActor
@Observable
final class StudyCardsViewModel {
    private let studyCardService: StudyCardServicing

    private(set) var cards: [StudyCard] = []
    private(set) var errorMessage: String?
    var selectedFilter: StudyCardFilter = .all

    var visibleCards: [StudyCard] {
        guard let type = selectedFilter.cardType else { return cards }
        return cards.filter { $0.type == type }
    }

    init(studyCardService: StudyCardServicing) {
        self.studyCardService = studyCardService
    }

    func load() async {
        do {
            cards = try await studyCardService.loadCards()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ card: StudyCard) async {
        do {
            try await studyCardService.removeCard(id: card.id)
            cards.removeAll { $0.id == card.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
