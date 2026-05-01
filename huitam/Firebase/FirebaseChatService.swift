import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseChatService: ChatServicing {
    private let authSession: FirebaseAuthSession
    private let translationService: TranslationServicing
    private let db: Firestore

    init(
        authSession: FirebaseAuthSession,
        translationService: TranslationServicing,
        db: Firestore = Firestore.firestore()
    ) {
        self.authSession = authSession
        self.translationService = translationService
        self.db = db
    }

    func loadChatSummaries() async throws -> [ChatSummary] {
        let uid = try await authSession.currentUserID()
        let snapshot = try await FirebaseAsync.getDocuments(
            db.collection("chats")
                .whereField("participantUIDs", arrayContains: uid)
                .order(by: "updatedAt", descending: true)
        )

        var summaries: [ChatSummary] = []
        for document in snapshot.documents {
            let data = document.data()
            let participantUID = ((data["participantUIDs"] as? [String]) ?? []).first { $0 != uid } ?? uid
            let profileSnapshot = try await FirebaseAsync.getDocument(db.collection("users").document(participantUID))
            let profileData = profileSnapshot.data() ?? [:]
            summaries.append(try FirebaseDocumentMapper.chatSummary(
                documentID: document.documentID,
                data: data,
                currentUID: uid,
                participantProfile: profileData
            ))
        }

        return summaries
    }

    func loadMessages(chatID: UUID) async throws -> [ChatMessage] {
        let uid = try await authSession.currentUserID()
        let snapshot = try await FirebaseAsync.getDocuments(
            messagesCollection(chatID: chatID)
                .order(by: "createdAt")
                .limit(to: 100)
        )

        return snapshot.documents.map { document in
            FirebaseDocumentMapper.message(
                documentID: document.documentID,
                data: document.data(),
                currentUID: uid,
                chatID: chatID
            )
        }
    }

    func sendMessage(chatID: UUID, draft: String) async throws -> ChatMessage {
        let uid = try await authSession.currentUserID()
        let chatReference = db.collection("chats").document(chatID.uuidString)
        let chatSnapshot = try await FirebaseAsync.getDocument(chatReference)
        let chatData = chatSnapshot.data() ?? [:]
        let participantUIDs = chatData["participantUIDs"] as? [String] ?? []
        let recipientUID = participantUIDs.first { $0 != uid }
        let roles = chatData["roles"] as? [String: [String: Any]] ?? [:]
        let currentRole = role(for: uid, in: roles)
        let recipientRole = recipientUID.map { role(for: $0, in: roles) } ?? .companion
        let currentProfile = try await profile(uid: uid)
        let recipientProfile: UserProfile?
        if let recipientUID {
            recipientProfile = try await profile(uid: recipientUID)
        } else {
            recipientProfile = nil
        }
        let sourceLanguage = messageLanguage(
            role: currentRole,
            nativeLanguage: currentProfile.nativeLanguage
        )
        let targetLanguage = messageLanguage(
            role: recipientRole,
            nativeLanguage: recipientProfile?.nativeLanguage ?? sourceLanguage
        )
        let translated = try await translationService.translate(draft, from: sourceLanguage, to: targetLanguage)
        var displayTexts = [uid: draft]
        if let recipientUID {
            displayTexts[recipientUID] = translated
        }

        let messageID = UUID()
        let messageData: [String: Any] = [
            "senderUID": uid,
            "originalText": draft,
            "translatedText": translated,
            "displayTexts": displayTexts,
            "deliveryState": "sent",
            "createdAt": FieldValue.serverTimestamp()
        ]

        var lastMessagePreviews = [uid: draft]
        if let recipientUID {
            lastMessagePreviews[recipientUID] = translated
        }

        try await FirebaseAsync.setData(messageData, on: messagesCollection(chatID: chatID).document(messageID.uuidString), merge: false)
        try await FirebaseAsync.setData(
            [
                "lastMessagePreview": translated,
                "lastMessagePreviews": lastMessagePreviews,
                "updatedAt": FieldValue.serverTimestamp(),
                "lastSenderUID": uid
            ],
            on: chatReference
        )

        if let recipientUID {
            _ = try? await FirebaseAsync.call(
                "sendChatNotification",
                payload: [
                    "chatId": chatID.uuidString,
                    "recipientUid": recipientUID,
                    "preview": translated
                ]
            )
        }

        return ChatMessage(
            id: messageID,
            chatID: chatID,
            senderID: StableID.uuid(from: uid),
            timestamp: Date(),
            translatedText: draft,
            originalText: draft,
            direction: .outgoing,
            deliveryState: .sent
        )
    }

    func analyze(message: ChatMessage) async throws -> MessageAnalysis {
        let result = try await FirebaseAsync.call(
            "analyzeMessage",
            payload: [
                "messageId": message.id.uuidString,
                "text": message.translatedText
            ]
        )

        guard let data = result as? [String: Any] else {
            throw FirebaseMappingError.missingField("analysis")
        }

        let tokens = (data["tokens"] as? [[String: Any]] ?? []).map { tokenData in
            MessageToken(
                id: UUID(),
                text: tokenData["text"] as? String ?? "",
                translation: tokenData["translation"] as? String ?? "",
                partOfSpeech: tokenData["partOfSpeech"] as? String ?? ""
            )
        }

        let notes = (data["grammarNotes"] as? [[String: Any]] ?? []).map { noteData in
            GrammarNote(
                id: UUID(),
                title: noteData["title"] as? String ?? "",
                explanation: noteData["explanation"] as? String ?? ""
            )
        }

        return MessageAnalysis(
            messageID: message.id,
            tokens: tokens,
            phraseSuggestions: data["phraseSuggestions"] as? [String] ?? [],
            grammarNotes: notes
        )
    }

    private func messagesCollection(chatID: UUID) -> CollectionReference {
        db.collection("chats").document(chatID.uuidString).collection("messages")
    }

    private func role(for uid: String, in roles: [String: [String: Any]]) -> ChatParticipantRole {
        (try? FirebaseDocumentMapper.role(from: roles[uid] ?? ["kind": "companion"])) ?? .companion
    }

    private func profile(uid: String) async throws -> UserProfile {
        let snapshot = try await FirebaseAsync.getDocument(db.collection("users").document(uid))
        return FirebaseDocumentMapper.profile(uid: uid, from: snapshot.data() ?? [:])
    }

    private func messageLanguage(
        role: ChatParticipantRole,
        nativeLanguage: AppLanguage
    ) -> AppLanguage {
        role.learningLanguage ?? nativeLanguage
    }
}
