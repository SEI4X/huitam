import FirebaseFirestore
import Foundation

@MainActor
extension FirebaseDocumentMapper {
    static func chatSummary(
        documentID: String,
        data: [String: Any],
        currentUID: String,
        participantProfile: [String: Any]
    ) throws -> ChatSummary {
        let participantUIDs = data["participantUIDs"] as? [String] ?? []
        let participantUID = participantUIDs.first { $0 != currentUID } ?? currentUID
        let roles = data["roles"] as? [String: [String: Any]] ?? [:]
        let currentRole = try role(from: roles[currentUID] ?? ["kind": "companion"])
        let participantRole = try role(from: roles[participantUID] ?? ["kind": "companion"])

        return ChatSummary(
            id: StableID.uuid(from: documentID),
            participant: participant(uid: participantUID, from: participantProfile),
            lastMessagePreview: data["lastMessagePreview"] as? String ?? "",
            timestamp: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            unreadCount: ((data["unreadCounts"] as? [String: Int])?[currentUID]) ?? 0,
            nativeLanguage: appLanguage(from: data["nativeLanguage"], fallback: .english),
            practiceLanguage: AppLanguage(rawValue: data["practiceLanguage"] as? String ?? ""),
            currentUserRole: currentRole,
            participantRole: participantRole
        )
    }

    static func message(documentID: String, data: [String: Any], currentUID: String, chatID: UUID) -> ChatMessage {
        let senderUID = data["senderUID"] as? String ?? currentUID
        let correctionData = data["correction"] as? [String: Any]

        return ChatMessage(
            id: StableID.uuid(from: documentID),
            chatID: chatID,
            senderID: StableID.uuid(from: senderUID),
            timestamp: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            translatedText: data["translatedText"] as? String ?? data["originalText"] as? String ?? "",
            originalText: data["originalText"] as? String ?? "",
            direction: senderUID == currentUID ? .outgoing : .incoming,
            deliveryState: MessageDeliveryState(rawValue: data["deliveryState"] as? String ?? "") ?? .sent,
            correction: correctionData.flatMap(correction(from:))
        )
    }

    static func data(from card: StudyCard) -> [String: Any] {
        [
            "sourceMessageID": card.sourceMessageID?.uuidString as Any,
            "type": card.type.rawValue,
            "frontText": card.frontText,
            "backText": card.backText,
            "note": card.note,
            "language": card.language.rawValue,
            "createdAt": Timestamp(date: card.createdAt)
        ]
    }

    static func studyCard(documentID: String, data: [String: Any]) -> StudyCard {
        StudyCard(
            id: StableID.uuid(from: documentID),
            sourceMessageID: UUID(uuidString: data["sourceMessageID"] as? String ?? ""),
            type: StudyCardType(rawValue: data["type"] as? String ?? "") ?? .word,
            frontText: data["frontText"] as? String ?? "",
            backText: data["backText"] as? String ?? "",
            note: data["note"] as? String ?? "",
            language: appLanguage(from: data["language"], fallback: .english),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    static func correction(from data: [String: Any]) -> MessageCorrection? {
        guard
            let correctedText = data["correctedText"] as? String,
            let mistakeText = data["mistakeText"] as? String,
            let explanation = data["explanation"] as? String
        else { return nil }

        return MessageCorrection(
            correctedText: correctedText,
            mistakeText: mistakeText,
            explanation: explanation
        )
    }
}

private extension MessageDeliveryState {
    init?(rawValue: String) {
        switch rawValue {
        case "sent": self = .sent
        case "delivered": self = .delivered
        case "read": self = .read
        default: return nil
        }
    }

    var rawValue: String {
        switch self {
        case .sent: "sent"
        case .delivered: "delivered"
        case .read: "read"
        }
    }
}
