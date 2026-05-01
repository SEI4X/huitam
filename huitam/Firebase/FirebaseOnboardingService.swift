import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseOnboardingService: OnboardingServicing {
    private let authSession: FirebaseAuthSession
    private let settingsService: SettingsServicing
    private let db: Firestore

    init(
        authSession: FirebaseAuthSession,
        settingsService: SettingsServicing,
        db: Firestore = Firestore.firestore()
    ) {
        self.authSession = authSession
        self.settingsService = settingsService
        self.db = db
    }

    func loadState() async throws -> OnboardingState {
        let uid = try await authSession.currentUserID()
        let snapshot = try await FirebaseAsync.getDocument(db.collection("users").document(uid))
        guard let data = snapshot.data(), data["hasCompletedOnboarding"] as? Bool == true else {
            return .notStarted
        }

        let role = try FirebaseDocumentMapper.role(from: data["currentUserRole"] as? [String: Any] ?? ["kind": "companion"])
        return OnboardingState(
            hasCompletedOnboarding: true,
            currentUserRole: role,
            nativeLanguage: FirebaseDocumentMapper.appLanguage(from: data["nativeLanguage"], fallback: AppDefaults.settings.nativeLanguage)
        )
    }

    func complete(role: ChatParticipantRole, nativeLanguage: AppLanguage) async throws -> OnboardingState {
        let uid = try await authSession.currentUserID()
        let learningSelection: LearningLanguageSelection = role.learningLanguage.map { .language($0) } ?? .none
        let settings = AppSettings(
            nativeLanguage: nativeLanguage,
            learningLanguage: learningSelection,
            theme: AppDefaults.settings.theme,
            tint: AppDefaults.settings.tint,
            notificationsEnabled: AppDefaults.settings.notificationsEnabled
        )

        _ = try await settingsService.updateSettings(settings)
        try await FirebaseAsync.setData(
            [
                "uid": uid,
                "hasCompletedOnboarding": true,
                "currentUserRole": FirebaseDocumentMapper.data(from: role),
                "nativeLanguage": nativeLanguage.rawValue,
                "learningLanguage": FirebaseDocumentMapper.rawLearningLanguage(from: learningSelection) as Any,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            on: db.collection("users").document(uid)
        )

        return OnboardingState(
            hasCompletedOnboarding: true,
            currentUserRole: role,
            nativeLanguage: nativeLanguage
        )
    }
}
