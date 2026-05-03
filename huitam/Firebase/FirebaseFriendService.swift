import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseFriendService: FriendServicing {
    private let authSession: FirebaseAuthSession
    private let db: Firestore

    init(authSession: FirebaseAuthSession, db: Firestore = Firestore.firestore()) {
        self.authSession = authSession
        self.db = db
    }

    func search(byNickname query: String) async throws -> [FriendSearchResult] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return [] }

        let usernameSnapshot = try await FirebaseAsync.getDocument(db.collection("usernames").document(normalized))
        guard
            let uid = usernameSnapshot.data()?["uid"] as? String,
            uid != (try await authSession.currentUserID())
        else {
            return []
        }

        let userSnapshot = try await FirebaseAsync.getDocument(db.collection("users").document(uid))
        guard let userData = userSnapshot.data() else { return [] }
        let participant = FirebaseDocumentMapper.participant(uid: uid, from: userData)
        return [
            FriendSearchResult(
                id: participant.id,
                nickname: participant.nickname,
                displayName: participant.displayName,
                avatarSystemImage: participant.avatarSystemImage,
                nativeLanguage: participant.nativeLanguage,
                learningLanguage: participant.learningLanguage
            )
        ]
    }

    func loadInvite(id: String) async throws -> PracticeInvite {
        let inviteID = id
            .replacingOccurrences(of: "https://huitam.com/invite/", with: "")
            .replacingOccurrences(of: "huitam://invite/", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshot = try await FirebaseAsync.getDocument(db.collection("invites").document(inviteID))

        guard let data = snapshot.data() else {
            throw FirebaseMappingError.missingField("invite")
        }

        return PracticeInvite(
            id: inviteID,
            inviterDisplayName: data["inviterDisplayName"] as? String ?? "Friend",
            inviterNativeLanguage: FirebaseDocumentMapper.appLanguage(from: data["inviterNativeLanguage"], fallback: .english),
            inviterLearningLanguage: FirebaseDocumentMapper.appLanguage(from: data["inviterLearningLanguage"], fallback: .english),
            guestNativeLanguage: FirebaseDocumentMapper.appLanguage(from: data["guestNativeLanguage"], fallback: .english),
            guestLearningLanguage: FirebaseDocumentMapper.learningSelection(from: data["guestLearningLanguage"] as? String)
        )
    }

    func createPracticeInvite(_ request: PracticeInviteRequest) async throws -> PracticeInvite {
        let uid = try await authSession.currentUserID()
        let profileSnapshot = try await FirebaseAsync.getDocument(db.collection("users").document(uid))
        let profile = FirebaseDocumentMapper.profile(uid: uid, from: profileSnapshot.data() ?? [:])
        let inviteID = UUID().uuidString
        let inviterLearningLanguage = profile.learningLanguage.language ?? AppDefaults.settings.learningLanguage.language ?? .english

        let invite = PracticeInvite(
            id: inviteID,
            inviterDisplayName: profile.displayName,
            inviterNativeLanguage: profile.nativeLanguage,
            inviterLearningLanguage: inviterLearningLanguage,
            guestNativeLanguage: request.guestNativeLanguage,
            guestLearningLanguage: request.guestLearningLanguage
        )

        try await FirebaseAsync.setData(
            [
                "inviterUID": uid,
                "inviterDisplayName": invite.inviterDisplayName,
                "inviterNativeLanguage": invite.inviterNativeLanguage.rawValue,
                "inviterLearningLanguage": invite.inviterLearningLanguage.rawValue,
                "guestNativeLanguage": invite.guestNativeLanguage.rawValue,
                "guestLearningLanguage": FirebaseDocumentMapper.rawLearningLanguage(from: invite.guestLearningLanguage) as Any,
                "status": "open",
                "createdAt": FieldValue.serverTimestamp()
            ],
            on: db.collection("invites").document(inviteID),
            merge: false
        )

        return invite
    }

    func acceptInvite(_ invite: PracticeInvite, as role: ChatParticipantRole) async throws -> ChatSummary {
        let uid = try await authSession.currentUserID()
        let inviterUID = try await inviterUID(for: invite)
        guard inviterUID != uid else {
            throw FriendServiceError.cannotOpenSelf
        }

        if let existingChat = try await existingChatSummary(with: inviterUID, currentUID: uid) {
            return existingChat
        }

        let chatID = UUID()
        let guestProfile = try await FirebaseProfileService(authSession: authSession, db: db).loadProfile()
        let participant = ChatParticipant(
            id: StableID.uuid(from: inviterUID),
            nickname: invite.inviterDisplayName.lowercased(),
            displayName: invite.inviterDisplayName,
            avatarSystemImage: "person.crop.circle.fill",
            nativeLanguage: invite.inviterNativeLanguage,
            learningLanguage: .language(invite.inviterLearningLanguage)
        )

        try await FirebaseAsync.setData(
            [
                "participantUIDs": [inviterUID, uid],
                "roles": [
                    inviterUID: FirebaseDocumentMapper.data(from: ChatParticipantRole.learner(invite.inviterLearningLanguage)),
                    uid: FirebaseDocumentMapper.data(from: role)
                ],
                "nativeLanguage": guestProfile.nativeLanguage.rawValue,
                "practiceLanguage": role.learningLanguage?.rawValue as Any,
                "lastMessagePreview": "",
                "unreadCounts": [inviterUID: 0, uid: 0],
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            on: db.collection("chats").document(chatID.uuidString),
            merge: false
        )

        try await FirebaseAsync.setData(
            [
                "status": "accepted",
                "guestUID": uid,
                "chatID": chatID.uuidString,
                "acceptedAt": FieldValue.serverTimestamp()
            ],
            on: db.collection("invites").document(invite.id)
        )

        return ChatSummary(
            id: chatID,
            documentID: chatID.uuidString,
            participant: participant,
            lastMessagePreview: "",
            timestamp: Date(),
            unreadCount: 0,
            nativeLanguage: guestProfile.nativeLanguage,
            practiceLanguage: role.learningLanguage,
            currentUserRole: role,
            participantRole: .learner(invite.inviterLearningLanguage)
        )
    }

    func openAccountChat(nickname: String, as role: ChatParticipantRole) async throws -> ChatSummary {
        let normalizedNickname = nickname.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try await FirebaseAsync.call(
            "openAccountChat",
            payload: [
                "nickname": normalizedNickname,
                "role": FirebaseDocumentMapper.data(from: role)
            ]
        )
        return try FirebaseDocumentMapper.chatSummary(fromCallable: result)
    }

    private func inviterUID(for invite: PracticeInvite) async throws -> String {
        let snapshot = try await FirebaseAsync.getDocument(db.collection("invites").document(invite.id))
        guard let inviterUID = snapshot.data()?["inviterUID"] as? String else {
            throw FirebaseMappingError.missingField("inviterUID")
        }
        return inviterUID
    }

    private func existingChatSummary(with participantUID: String, currentUID uid: String) async throws -> ChatSummary? {
        let snapshot = try await FirebaseAsync.getDocuments(
            db.collection("chats")
                .whereField("participantUIDs", arrayContains: uid)
        )

        guard let document = snapshot.documents.first(where: { document in
            let participantUIDs = document.data()["participantUIDs"] as? [String] ?? []
            return participantUIDs.contains(participantUID)
        }) else {
            return nil
        }

        return try await chatSummary(chatID: document.documentID, participantUID: participantUID, currentUID: uid)
    }

    private func chatSummary(chatID: String, participantUID: String, currentUID uid: String) async throws -> ChatSummary {
        let chatSnapshot = try await FirebaseAsync.getDocument(db.collection("chats").document(chatID))
        let profileSnapshot = try await FirebaseAsync.getDocument(db.collection("users").document(participantUID))
        return try FirebaseDocumentMapper.chatSummary(
            documentID: chatID,
            data: chatSnapshot.data() ?? [:],
            currentUID: uid,
            participantProfile: profileSnapshot.data() ?? [:]
        )
    }
}

enum FriendServiceError: LocalizedError {
    case accountNotFound
    case cannotOpenSelf

    var errorDescription: String? {
        switch self {
        case .accountNotFound:
            "This huitam account was not found."
        case .cannotOpenSelf:
            "This is your own huitam link."
        }
    }
}
