import Foundation

enum FirebaseMappingError: Error {
    case missingField(String)
    case invalidField(String)
}

enum FirebaseDocumentMapper {
    static func data(from role: ChatParticipantRole) -> [String: Any] {
        switch role {
        case let .learner(language):
            [
                "kind": "learner",
                "learningLanguage": language.rawValue
            ]
        case .companion:
            [
                "kind": "companion"
            ]
        }
    }

    static func role(from data: [String: Any]) throws -> ChatParticipantRole {
        guard let kind = data["kind"] as? String else {
            throw FirebaseMappingError.missingField("kind")
        }

        switch kind {
        case "learner":
            guard let rawLanguage = data["learningLanguage"] as? String else {
                throw FirebaseMappingError.missingField("learningLanguage")
            }
            guard let language = AppLanguage(rawValue: rawLanguage) else {
                throw FirebaseMappingError.invalidField("learningLanguage")
            }
            return .learner(language)
        case "companion":
            return .companion
        default:
            throw FirebaseMappingError.invalidField("kind")
        }
    }

    static func learningSelection(from rawValue: String?) -> LearningLanguageSelection {
        guard let rawValue, let language = AppLanguage(rawValue: rawValue) else {
            return .none
        }
        return .language(language)
    }

    static func rawLearningLanguage(from selection: LearningLanguageSelection) -> String? {
        selection.language?.rawValue
    }
}
