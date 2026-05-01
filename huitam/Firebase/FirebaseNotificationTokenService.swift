import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseNotificationTokenService {
    private let authSession: FirebaseAuthSession
    private let db: Firestore

    init(authSession: FirebaseAuthSession? = nil, db: Firestore = Firestore.firestore()) {
        self.authSession = authSession ?? FirebaseAuthSession()
        self.db = db
    }

    func store(token: String) async throws {
        let uid = try await authSession.currentUserID()
        try await FirebaseAsync.setData(
            [
                "token": token,
                "platform": "ios",
                "updatedAt": FieldValue.serverTimestamp()
            ],
            on: db.collection("users").document(uid).collection("deviceTokens").document(token)
        )
    }
}
