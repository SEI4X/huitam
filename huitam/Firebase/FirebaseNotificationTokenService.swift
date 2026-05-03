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
        guard let token = try await currentMessagingTokenIfReady() else {
            return
        }
        try await store(token: token)
    }

    func removeCurrentMessagingTokenIfAvailable() async throws {
        guard let token = try await currentMessagingTokenIfReady() else {
            return
        }
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

    private func currentMessagingTokenIfReady() async throws -> String? {
        guard Messaging.messaging().apnsToken != nil else {
            return nil
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String?, Error>) in
            Messaging.messaging().token { token, error in
                if let error {
                    if Self.isMissingAPNSToken(error) {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: error)
                    }
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

    nonisolated private static func isMissingAPNSToken(_ error: Error) -> Bool {
        error.localizedDescription.localizedCaseInsensitiveContains("No APNS token specified")
    }
}
