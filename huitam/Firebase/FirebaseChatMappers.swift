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
            documentID: documentID,
            participant: participant(uid: participantUID, from: participantProfile),
            lastMessagePreview: previewText(from: data, currentUID: currentUID),
            timestamp: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            unreadCount: ((data["unreadCounts"] as? [String: Int])?[currentUID]) ?? 0,
            nativeLanguage: appLanguage(from: data["nativeLanguage"], fallback: .english),
            practiceLanguage: AppLanguage(rawValue: data["practiceLanguage"] as? String ?? ""),
            currentUserRole: currentRole,
            participantRole: participantRole
        )
    }

    static func chatSummary(fromCallable result: Any) throws -> ChatSummary {
        guard
            let root = result as? [String: Any],
            let data = root["chat"] as? [String: Any],
            let documentID = data["id"] as? String,
            let participantUID = data["participantUID"] as? String,
            let participantProfile = data["participant"] as? [String: Any],
            let currentRoleData = data["currentUserRole"] as? [String: Any],
            let participantRoleData = data["participantRole"] as? [String: Any]
        else {
            throw FirebaseMappingError.missingField("callableChatSummary")
        }

        let updatedAtMillis = numericValue(data["updatedAtMillis"]) ?? 0
        let unreadCount = Int(numericValue(data["unreadCount"]) ?? 0)
        let updatedAt = updatedAtMillis > 0 ? Date(timeIntervalSince1970: updatedAtMillis / 1000) : Date()

        return ChatSummary(
            id: StableID.uuid(from: documentID),
            documentID: documentID,
            participant: participant(uid: participantUID, from: participantProfile),
            lastMessagePreview: data["lastMessagePreview"] as? String ?? "",
            timestamp: updatedAt,
            unreadCount: unreadCount,
            nativeLanguage: appLanguage(from: data["nativeLanguage"], fallback: .english),
            practiceLanguage: AppLanguage(rawValue: data["practiceLanguage"] as? String ?? ""),
            currentUserRole: try role(from: currentRoleData),
            participantRole: try role(from: participantRoleData)
        )
    }

    static func message(documentID: String, data: [String: Any], currentUID: String, chatID: UUID) -> ChatMessage {
        let senderUID = data["senderUID"] as? String ?? currentUID
        let correctionData = data["correction"] as? [String: Any]
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt

        return ChatMessage(
            id: StableID.uuid(from: documentID),
            chatID: chatID,
            senderID: StableID.uuid(from: senderUID),
            timestamp: createdAt,
            updatedAt: updatedAt,
            translatedText: displayText(from: data, currentUID: currentUID),
            originalText: data["originalText"] as? String ?? "",
            direction: senderUID == currentUID ? .outgoing : .incoming,
            deliveryState: MessageDeliveryState(rawValue: data["deliveryState"] as? String ?? "") ?? .sent,
            errorMessage: nil,
            correction: correctionData.flatMap(correction(from:)),
            reply: replyPreview(from: data)
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

    static func displayText(from data: [String: Any], currentUID: String) -> String {
        if let displayTexts = data["displayTexts"] as? [String: String],
           let displayText = displayTexts[currentUID] {
            return displayText
        }

        return data["translatedText"] as? String ?? data["originalText"] as? String ?? ""
    }

    static func replyPreview(from data: [String: Any]) -> MessageReplyPreview? {
        guard
            let rawID = data["replyToMessageID"] as? String,
            let messageID = UUID(uuidString: rawID),
            let text = data["replyPreviewText"] as? String
        else {
            return nil
        }

        return MessageReplyPreview(
            messageID: messageID,
            senderName: data["replySenderName"] as? String ?? "Message",
            text: text,
            originalText: data["replyOriginalText"] as? String
        )
    }

    static func previewText(from data: [String: Any], currentUID: String) -> String {
        if let previews = data["lastMessagePreviews"] as? [String: String],
           let preview = previews[currentUID] {
            return preview
        }

        return data["lastMessagePreview"] as? String ?? ""
    }

    private static func numericValue(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            value
        case let value as Int:
            Double(value)
        case let value as NSNumber:
            value.doubleValue
        default:
            nil
        }
    }
}

private extension MessageDeliveryState {
    init?(rawValue: String) {
        switch rawValue {
        case "sending": self = .sending
        case "sent": self = .sent
        case "delivered": self = .sent
        case "read": self = .read
        case "failed": self = .failed
        default: return nil
        }
    }

    var rawValue: String {
        switch self {
        case .sending: "sending"
        case .sent: "sent"
        case .read: "read"
        case .failed: "failed"
        }
    }
}
