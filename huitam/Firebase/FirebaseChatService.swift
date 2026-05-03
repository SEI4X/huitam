import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseChatService: ChatServicing {
    private let authSession: FirebaseAuthSession
    private let db: Firestore

    init(
        authSession: FirebaseAuthSession,
        translationService _: TranslationServicing,
        db: Firestore = Firestore.firestore()
    ) {
        self.authSession = authSession
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

    func chatSummaryUpdates() -> AsyncStream<Result<[ChatSummary], Error>> {
        AsyncStream { continuation in
            Task { @MainActor in
                do {
                    let uid = try await authSession.currentUserID()
                    let query = db.collection("chats")
                        .whereField("participantUIDs", arrayContains: uid)
                        .order(by: "updatedAt", descending: true)

                    let listener = query.addSnapshotListener { [weak self] snapshot, error in
                        if let error {
                            continuation.yield(.failure(error))
                            return
                        }

                        guard let self, let documents = snapshot?.documents else {
                            continuation.yield(.success([]))
                            return
                        }

                        Task { @MainActor in
                            do {
                                let summaries = try await self.chatSummaries(from: documents, currentUID: uid)
                                continuation.yield(.success(summaries))
                            } catch {
                                continuation.yield(.failure(error))
                            }
                        }
                    }

                    continuation.onTermination = { _ in
                        listener.remove()
                    }
                } catch {
                    continuation.yield(.failure(error))
                    continuation.finish()
                }
            }
        }
    }

    func loadRecentMessages(chat: ChatSummary, limit: Int) async throws -> [ChatMessage] {
        let uid = try await authSession.currentUserID()
        let snapshot = try await FirebaseAsync.getDocuments(
            messagesCollection(chat: chat)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
        )

        return messages(from: snapshot.documents, currentUID: uid, chat: chat)
            .sorted { $0.timestamp < $1.timestamp }
    }

    func loadEarlierMessages(chat: ChatSummary, before oldestMessage: ChatMessage, limit: Int) async throws -> [ChatMessage] {
        let uid = try await authSession.currentUserID()
        let snapshot = try await FirebaseAsync.getDocuments(
            messagesCollection(chat: chat)
                .whereField("createdAt", isLessThan: Timestamp(date: oldestMessage.timestamp))
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
        )

        return messages(from: snapshot.documents, currentUID: uid, chat: chat)
            .sorted { $0.timestamp < $1.timestamp }
    }

    func messageUpdates(chat: ChatSummary, after date: Date?) -> AsyncStream<Result<[ChatMessage], Error>> {
        AsyncStream { continuation in
            Task { @MainActor in
                do {
                    let uid = try await authSession.currentUserID()
                    var query: Query = messagesCollection(chat: chat)
                        .order(by: "updatedAt")

                    if let date {
                        query = query.whereField("updatedAt", isGreaterThan: Timestamp(date: date))
                    }

                    let listener = query.addSnapshotListener { [weak self] snapshot, error in
                        if let error {
                            continuation.yield(.failure(error))
                            return
                        }

                        guard let self, let documents = snapshot?.documents else {
                            continuation.yield(.success([]))
                            return
                        }

                        let messages = self.messages(from: documents, currentUID: uid, chat: chat)
                        continuation.yield(.success(messages))
                    }

                    continuation.onTermination = { _ in
                        listener.remove()
                    }
                } catch {
                    continuation.yield(.failure(error))
                    continuation.finish()
                }
            }
        }
    }

    func sendMessage(chat: ChatSummary, draft: String, localID: UUID, reply: MessageReplyPreview?) async throws -> ChatMessage {
        let uid = try await authSession.currentUserID()
        let chatReference = db.collection("chats").document(remoteDocumentID(for: chat))
        let messageID = localID
        let messageReference = messagesCollection(chat: chat).document(messageID.uuidString)
        var messageData: [String: Any] = [
            "senderUID": uid,
            "originalText": draft,
            "translatedText": draft,
            "displayTexts": [uid: draft],
            "deliveryState": "sent",
            "translationState": "pending",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let reply {
            messageData["replyToMessageID"] = reply.messageID.uuidString
            messageData["replySenderName"] = reply.senderName
            messageData["replyPreviewText"] = reply.text
            if let originalText = reply.originalText, originalText.isEmpty == false {
                messageData["replyOriginalText"] = originalText
            }
        }

        let batch = db.batch()
        batch.setData(messageData, forDocument: messageReference, merge: false)
        batch.setData(
            [
                "lastMessagePreview": draft,
                "lastMessagePreviews": [uid: draft],
                "updatedAt": FieldValue.serverTimestamp(),
                "lastSenderUID": uid
            ],
            forDocument: chatReference,
            merge: true
        )
        try await FirebaseAsync.commit(batch)

        return ChatMessage(
            id: messageID,
            chatID: chat.id,
            senderID: StableID.uuid(from: uid),
            timestamp: Date(),
            updatedAt: Date(),
            translatedText: draft,
            originalText: draft,
            direction: .outgoing,
            deliveryState: .sent,
            reply: reply
        )
    }

    func markChatRead(chat: ChatSummary) async throws {
        let uid = try await authSession.currentUserID()
        let chatReference = db.collection("chats").document(remoteDocumentID(for: chat))
        let snapshot = try await FirebaseAsync.getDocuments(
            messagesCollection(chat: chat)
                .order(by: "createdAt", descending: true)
                .limit(to: 60)
        )

        let batch = db.batch()
        batch.setData(
            [
                "unreadCounts.\(uid)": 0
            ],
            forDocument: chatReference,
            merge: true
        )

        for document in snapshot.documents {
            let data = document.data()
            let senderUID = data["senderUID"] as? String
            let deliveryState = data["deliveryState"] as? String
            guard senderUID != uid, deliveryState != "read" else { continue }
            batch.setData(
                [
                    "deliveryState": "read",
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: document.reference,
                merge: true
            )
        }

        try await FirebaseAsync.commit(batch)
    }

    func deleteMessage(chat: ChatSummary, message: ChatMessage) async throws {
        try await FirebaseAsync.delete(messagesCollection(chat: chat).document(message.id.uuidString))
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

    private func messagesCollection(chat: ChatSummary) -> CollectionReference {
        db.collection("chats").document(remoteDocumentID(for: chat)).collection("messages")
    }

    private func messages(
        from documents: [QueryDocumentSnapshot],
        currentUID uid: String,
        chat: ChatSummary
    ) -> [ChatMessage] {
        documents.map { document in
            FirebaseDocumentMapper.message(
                documentID: document.documentID,
                data: document.data(),
                currentUID: uid,
                chatID: chat.id
            )
        }
    }

    private func remoteDocumentID(for chat: ChatSummary) -> String {
        chat.documentID.isEmpty ? chat.id.uuidString : chat.documentID
    }

    private func chatSummaries(
        from documents: [QueryDocumentSnapshot],
        currentUID uid: String
    ) async throws -> [ChatSummary] {
        var summaries: [ChatSummary] = []
        for document in documents {
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

}
