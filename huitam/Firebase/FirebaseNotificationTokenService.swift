import FirebaseFirestore
import FirebaseMessaging
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

    func storeCurrentMessagingTokenIfAvailable() async throws {
        let token = try await currentMessagingToken()
        try await store(token: token)
    }

    func removeCurrentMessagingTokenIfAvailable() async throws {
        let token = try await currentMessagingToken()
        try await remove(token: token)
    }

    func remove(token: String) async throws {
        let uid = try await authSession.currentUserID()
        try await db
            .collection("users")
            .document(uid)
            .collection("deviceTokens")
            .document(token)
            .delete()
    }

    private func currentMessagingToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Messaging.messaging().token { token, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let token else {
                    continuation.resume(throwing: FirebaseMappingError.missingField("fcmToken"))
                    return
                }

                continuation.resume(returning: token)
            }
        }
    }
}
