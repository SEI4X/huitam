import Foundation

struct PracticeInviteRequest: Equatable {
    var guestNativeLanguage: AppLanguage
    var guestLearningLanguage: LearningLanguageSelection
}

struct PracticeInvite: Identifiable, Hashable {
    var id: String
    var inviterDisplayName: String
    var inviterNativeLanguage: AppLanguage
    var inviterLearningLanguage: AppLanguage
    var guestNativeLanguage: AppLanguage
    var guestLearningLanguage: LearningLanguageSelection

    var guestRole: ChatParticipantRole {
        if let language = guestLearningLanguage.language {
            return .learner(language)
        }
        return .companion
    }

    var shareURL: URL {
        URL(string: "https://huitam.app/invite/\(id)")!
    }
}
