import Foundation

enum AppThemePreference: String, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum AppTintPreference: String, CaseIterable, Identifiable, Hashable {
    case blue
    case green
    case orange
    case pink
    case purple
    case gray

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: "Blue"
        case .green: "Green"
        case .orange: "Orange"
        case .pink: "Pink"
        case .purple: "Purple"
        case .gray: "Gray"
        }
    }
}

struct AppSettings: Equatable {
    var nativeLanguage: AppLanguage
    var learningLanguage: LearningLanguageSelection
    var theme: AppThemePreference
    var tint: AppTintPreference
    var notificationsEnabled: Bool

    var canUseStudyFeatures: Bool {
        learningLanguage.isEnabled
    }
}

struct FriendSearchResult: Identifiable, Hashable {
    var id: UUID
    var nickname: String
    var displayName: String
    var avatarSystemImage: String
    var nativeLanguage: AppLanguage
    var learningLanguage: LearningLanguageSelection
}
