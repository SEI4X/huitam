import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseSettingsService: SettingsServicing {
    private let authSession: FirebaseAuthSession
    private let db: Firestore

    init(authSession: FirebaseAuthSession, db: Firestore = Firestore.firestore()) {
        self.authSession = authSession
        self.db = db
    }

    var settingsUpdates: AsyncStream<AppSettings> {
        AsyncStream { continuation in
            Task { @MainActor in
                let uid = try? await authSession.currentUserID()
                guard let uid else {
                    continuation.finish()
                    return
                }

                let registration = settingsReference(uid: uid).addSnapshotListener { snapshot, _ in
                    guard let data = snapshot?.data() else { return }
                    continuation.yield(FirebaseDocumentMapper.settings(from: data))
                }

                continuation.onTermination = { _ in
                    registration.remove()
                }
            }
        }
    }

    func loadSettings() async throws -> AppSettings {
        let uid = try await authSession.currentUserID()
        let reference = settingsReference(uid: uid)
        let snapshot = try await FirebaseAsync.getDocument(reference)

        guard let data = snapshot.data() else {
            try await FirebaseAsync.setData(FirebaseDocumentMapper.data(from: AppDefaults.settings), on: reference)
            return AppDefaults.settings
        }

        return FirebaseDocumentMapper.settings(from: data)
    }

    func updateSettings(_ settings: AppSettings) async throws -> AppSettings {
        let uid = try await authSession.currentUserID()
        let batch = db.batch()
        batch.setData(
            FirebaseDocumentMapper.data(from: settings),
            forDocument: settingsReference(uid: uid),
            merge: true
        )
        batch.setData(
            [
                "nativeLanguage": settings.nativeLanguage.rawValue,
                "learningLanguage": FirebaseDocumentMapper.rawLearningLanguage(from: settings.learningLanguage) as Any,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            forDocument: db.collection("users").document(uid),
            merge: true
        )
        try await FirebaseAsync.commit(batch)
        return settings
    }

    private func settingsReference(uid: String) -> DocumentReference {
        db.collection("users").document(uid).collection("private").document("settings")
    }
}
