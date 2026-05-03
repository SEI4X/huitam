import Foundation

enum AppDefaults {
    static let settings = AppSettings(
        nativeLanguage: .russian,
        learningLanguage: .language(.english),
        theme: .dark,
        tint: .blue,
        notificationsEnabled: false
    )

    static let profileStats = UserStats(
        messagesPracticed: 0,
        cardsSaved: 0,
        correctionsUsed: 0,
        dailyMessages: []
    )
}
