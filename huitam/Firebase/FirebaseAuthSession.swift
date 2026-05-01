import FirebaseAuth
import Foundation

@MainActor
final class FirebaseAuthSession {
    func currentUserID() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }

        return try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signInAnonymously { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let uid = result?.user.uid else {
                    continuation.resume(throwing: FirebaseMappingError.missingField("uid"))
                    return
                }

                continuation.resume(returning: uid)
            }
        }
    }
}
