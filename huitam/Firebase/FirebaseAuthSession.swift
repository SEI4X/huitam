import FirebaseAuth
import Foundation

@MainActor
final class FirebaseAuthSession {
    func currentUserID() async throws -> String {
        if let user = Auth.auth().currentUser, user.isAnonymous == false {
            let uid = user.uid
            return uid
        }

        if Auth.auth().currentUser?.isAnonymous == true {
            try? Auth.auth().signOut()
        }

        throw AuthSessionError.unauthenticated
    }
}
