import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseProfileService: ProfileServicing {
    private let authSession: FirebaseAuthSession
    private let db: Firestore

    init(authSession: FirebaseAuthSession, db: Firestore = Firestore.firestore()) {
        self.authSession = authSession
        self.db = db
    }

    func loadProfile() async throws -> UserProfile {
        let uid = try await authSession.currentUserID()
        let reference = db.collection("users").document(uid)
        let snapshot = try await FirebaseAsync.getDocument(reference)

        if let data = snapshot.data() {
            return FirebaseDocumentMapper.profile(uid: uid, from: data)
        }

        let profile = defaultProfile(uid: uid)
        try await FirebaseAsync.setData(FirebaseDocumentMapper.data(from: profile, uid: uid), on: reference)
        return profile
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        let uid = try await authSession.currentUserID()
        let normalizedNickname = profile.nickname.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let savedProfile = UserProfile(
            id: profile.id,
            nickname: normalizedNickname,
            displayName: profile.displayName,
            avatarSystemImage: profile.avatarSystemImage,
            nativeLanguage: profile.nativeLanguage,
            learningLanguage: profile.learningLanguage,
            stats: profile.stats,
            streakDays: profile.streakDays
        )

        try await FirebaseAsync.setData(
            FirebaseDocumentMapper.data(from: savedProfile, uid: uid),
            on: db.collection("users").document(uid)
        )

        try await FirebaseAsync.setData(
            ["uid": uid, "updatedAt": FieldValue.serverTimestamp()],
            on: db.collection("usernames").document(normalizedNickname)
        )

        return savedProfile
    }

    private func defaultProfile(uid: String) -> UserProfile {
        UserProfile(
            id: StableID.uuid(from: uid),
            nickname: "user-\(uid.prefix(6))",
            displayName: "New Friend",
            avatarSystemImage: "person.crop.circle.fill",
            nativeLanguage: AppDefaults.settings.nativeLanguage,
            learningLanguage: AppDefaults.settings.learningLanguage,
            stats: AppDefaults.profileStats,
            streakDays: 0
        )
    }
}
