import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseStudyCardService: StudyCardServicing {
    private let authSession: FirebaseAuthSession
    private let db: Firestore

    init(authSession: FirebaseAuthSession, db: Firestore = Firestore.firestore()) {
        self.authSession = authSession
        self.db = db
    }

    func loadCards() async throws -> [StudyCard] {
        let uid = try await authSession.currentUserID()
        let snapshot = try await FirebaseAsync.getDocuments(
            cardsCollection(uid: uid).order(by: "createdAt", descending: true)
        )

        return snapshot.documents.map { document in
            FirebaseDocumentMapper.studyCard(documentID: document.documentID, data: document.data())
        }
    }

    func saveCards(_ cards: [StudyCard]) async throws {
        let uid = try await authSession.currentUserID()
        for card in cards {
            try await FirebaseAsync.setData(
                FirebaseDocumentMapper.data(from: card),
                on: cardsCollection(uid: uid).document(card.id.uuidString)
            )
        }
    }

    func removeCard(id: UUID) async throws {
        let uid = try await authSession.currentUserID()
        try await FirebaseAsync.delete(cardsCollection(uid: uid).document(id.uuidString))
    }

    private func cardsCollection(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("studyCards")
    }
}
