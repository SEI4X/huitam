import FirebaseFirestore
import Foundation

extension FirebaseDocumentMapper {
    static func settings(from data: [String: Any]) -> AppSettings {
        AppSettings(
            nativeLanguage: appLanguage(from: data["nativeLanguage"], fallback: AppDefaults.settings.nativeLanguage),
            learningLanguage: learningSelection(from: data["learningLanguage"] as? String),
            theme: AppThemePreference(rawValue: data["theme"] as? String ?? "") ?? AppDefaults.settings.theme,
            tint: AppTintPreference(rawValue: data["tint"] as? String ?? "") ?? AppDefaults.settings.tint,
            notificationsEnabled: data["notificationsEnabled"] as? Bool ?? AppDefaults.settings.notificationsEnabled
        )
    }

    static func data(from settings: AppSettings) -> [String: Any] {
        [
            "nativeLanguage": settings.nativeLanguage.rawValue,
            "learningLanguage": rawLearningLanguage(from: settings.learningLanguage) as Any,
            "theme": settings.theme.rawValue,
            "tint": settings.tint.rawValue,
            "notificationsEnabled": settings.notificationsEnabled,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    static func profile(uid: String, from data: [String: Any]) -> UserProfile {
        UserProfile(
            id: StableID.uuid(from: uid),
            nickname: data["nickname"] as? String ?? "user-\(uid.prefix(6))",
            displayName: data["displayName"] as? String ?? "New Friend",
            avatarSystemImage: data["avatarSystemImage"] as? String ?? "person.crop.circle.fill",
            nativeLanguage: appLanguage(from: data["nativeLanguage"], fallback: AppDefaults.settings.nativeLanguage),
            learningLanguage: learningSelection(from: data["learningLanguage"] as? String),
            stats: UserStats(
                messagesPracticed: data["messagesPracticed"] as? Int ?? 0,
                cardsSaved: data["cardsSaved"] as? Int ?? 0,
                correctionsUsed: data["correctionsUsed"] as? Int ?? 0,
                dailyMessages: []
            ),
            streakDays: data["streakDays"] as? Int ?? 0
        )
    }

    static func data(from profile: UserProfile, uid: String) -> [String: Any] {
        [
            "uid": uid,
            "nickname": profile.nickname.lowercased(),
            "displayName": profile.displayName,
            "avatarSystemImage": profile.avatarSystemImage,
            "nativeLanguage": profile.nativeLanguage.rawValue,
            "learningLanguage": rawLearningLanguage(from: profile.learningLanguage) as Any,
            "messagesPracticed": profile.stats.messagesPracticed,
            "cardsSaved": profile.stats.cardsSaved,
            "correctionsUsed": profile.stats.correctionsUsed,
            "streakDays": profile.streakDays,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    static func participant(uid: String, from data: [String: Any]) -> ChatParticipant {
        ChatParticipant(
            id: StableID.uuid(from: uid),
            uid: uid,
            nickname: data["nickname"] as? String ?? "friend",
            displayName: data["displayName"] as? String ?? "Friend",
            avatarSystemImage: data["avatarSystemImage"] as? String ?? "person.crop.circle.fill",
            nativeLanguage: appLanguage(from: data["nativeLanguage"], fallback: .english),
            learningLanguage: learningSelection(from: data["learningLanguage"] as? String)
        )
    }

    static func appLanguage(from value: Any?, fallback: AppLanguage) -> AppLanguage {
        guard let rawValue = value as? String else { return fallback }
        return AppLanguage(rawValue: rawValue) ?? fallback
    }
}
