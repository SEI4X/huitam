import Foundation

struct UserStats: Equatable {
    var messagesPracticed: Int
    var cardsSaved: Int
    var correctionsUsed: Int
    var dailyMessages: [DailyMessagePoint]
}

struct DailyMessagePoint: Identifiable, Equatable {
    var id: Date { date }
    var date: Date
    var count: Int
}

struct UserProfile: Identifiable, Equatable {
    var id: UUID
    var nickname: String
    var displayName: String
    var avatarSystemImage: String
    var nativeLanguage: AppLanguage
    var learningLanguage: LearningLanguageSelection
    var stats: UserStats
    var streakDays: Int
}

struct ChatParticipant: Identifiable, Hashable {
    var id: UUID
    var nickname: String
    var displayName: String
    var avatarSystemImage: String
    var nativeLanguage: AppLanguage
    var learningLanguage: LearningLanguageSelection
}
