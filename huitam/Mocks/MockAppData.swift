import Foundation

enum MockAppData {
    static let currentUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let camilleID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let mateoID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let camilleChatID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let mateoChatID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let firstMessageID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    static let secondMessageID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    static let thirdMessageID = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!

    static let profile = UserProfile(
        id: currentUserID,
        nickname: "alex",
        displayName: "Alex",
        avatarSystemImage: "person.crop.circle.fill",
        nativeLanguage: .russian,
        learningLanguage: .language(.english),
        stats: UserStats(
            messagesPracticed: 128,
            cardsSaved: 42,
            correctionsUsed: 17,
            dailyMessages: [
                DailyMessagePoint(date: Date(timeIntervalSince1970: 1_774_396_800), count: 8),
                DailyMessagePoint(date: Date(timeIntervalSince1970: 1_774_483_200), count: 13),
                DailyMessagePoint(date: Date(timeIntervalSince1970: 1_774_569_600), count: 10),
                DailyMessagePoint(date: Date(timeIntervalSince1970: 1_774_656_000), count: 21),
                DailyMessagePoint(date: Date(timeIntervalSince1970: 1_774_742_400), count: 18),
                DailyMessagePoint(date: Date(timeIntervalSince1970: 1_774_828_800), count: 26),
                DailyMessagePoint(date: Date(timeIntervalSince1970: 1_774_915_200), count: 31)
            ]
        ),
        streakDays: 9
    )

    static let camille = ChatParticipant(
        id: camilleID,
        nickname: "camille",
        displayName: "Camille",
        avatarSystemImage: "person.crop.circle.fill",
        nativeLanguage: .french,
        learningLanguage: .language(.english)
    )

    static let mateo = ChatParticipant(
        id: mateoID,
        nickname: "mateo",
        displayName: "Mateo",
        avatarSystemImage: "person.crop.circle.fill",
        nativeLanguage: .spanish,
        learningLanguage: .language(.french)
    )

    static let chats: [ChatSummary] = [
        ChatSummary(
            id: camilleChatID,
            participant: camille,
            lastMessagePreview: "Can we practice after work?",
            timestamp: Date(timeIntervalSince1970: 1_775_000_000),
            unreadCount: 2,
            nativeLanguage: .russian,
            practiceLanguage: .english,
            currentUserRole: .learner(.english),
            participantRole: .companion
        ),
        ChatSummary(
            id: mateoChatID,
            participant: mateo,
            lastMessagePreview: "That phrase sounds natural.",
            timestamp: Date(timeIntervalSince1970: 1_774_996_400),
            unreadCount: 0,
            nativeLanguage: .russian,
            practiceLanguage: .english,
            currentUserRole: .learner(.english),
            participantRole: .learner(.french)
        )
    ]

    static let messagesByChatID: [UUID: [ChatMessage]] = [
        camilleChatID: [
            ChatMessage(
                id: firstMessageID,
                chatID: camilleChatID,
                senderID: camilleID,
                timestamp: Date(timeIntervalSince1970: 1_775_000_000),
                translatedText: "Bonjour Alex",
                originalText: "Привет, Алекс",
                direction: .incoming,
                deliveryState: .read
            ),
            ChatMessage(
                id: secondMessageID,
                chatID: camilleChatID,
                senderID: currentUserID,
                timestamp: Date(timeIntervalSince1970: 1_775_000_120),
                translatedText: "I want practice today.",
                originalText: "Je veux pratiquer aujourd'hui.",
                direction: .outgoing,
                deliveryState: .read,
                correction: MessageCorrection(
                    correctedText: "I want to practice today.",
                    mistakeText: "I want practice today.",
                    explanation: "After “want”, English usually uses “to” before the next verb."
                )
            ),
            ChatMessage(
                id: thirdMessageID,
                chatID: camilleChatID,
                senderID: camilleID,
                timestamp: Date(timeIntervalSince1970: 1_775_000_240),
                translatedText: "Can we meet after work?",
                originalText: "On peut se voir après le travail ?",
                direction: .incoming,
                deliveryState: .delivered
            )
        ],
        mateoChatID: [
            ChatMessage(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000004")!,
                chatID: mateoChatID,
                senderID: mateoID,
                timestamp: Date(timeIntervalSince1970: 1_774_996_400),
                translatedText: "That phrase sounds natural.",
                originalText: "Esa frase suena natural.",
                direction: .incoming,
                deliveryState: .read
            )
        ]
    ]

    static let studyCards: [StudyCard] = [
        StudyCard(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            sourceMessageID: firstMessageID,
            type: .word,
            frontText: "Bonjour",
            backText: "Hello",
            note: "A common greeting.",
            language: .french,
            createdAt: Date(timeIntervalSince1970: 1_775_000_500)
        ),
        StudyCard(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
            sourceMessageID: thirdMessageID,
            type: .phrase,
            frontText: "after work",
            backText: "après le travail",
            note: "Useful time phrase.",
            language: .english,
            createdAt: Date(timeIntervalSince1970: 1_775_000_600)
        ),
        StudyCard(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!,
            sourceMessageID: secondMessageID,
            type: .grammar,
            frontText: "want to + verb",
            backText: "I want to practice",
            note: "Use an infinitive after want.",
            language: .english,
            createdAt: Date(timeIntervalSince1970: 1_775_000_700)
        )
    ]

    static let settings = AppSettings(
        nativeLanguage: .russian,
        learningLanguage: .language(.english),
        theme: .system,
        tint: .blue,
        notificationsEnabled: true
    )

    static let sampleInvite = PracticeInvite(
        id: "mock-invite",
        inviterDisplayName: "Alex",
        inviterNativeLanguage: .russian,
        inviterLearningLanguage: .english,
        guestNativeLanguage: .french,
        guestLearningLanguage: .none
    )

    static let friendResults = [
        FriendSearchResult(
            id: camilleID,
            nickname: "camille",
            displayName: "Camille",
            avatarSystemImage: "person.crop.circle.fill",
            nativeLanguage: .french,
            learningLanguage: .language(.english)
        )
    ]

    static func analysis(for message: ChatMessage) -> MessageAnalysis {
        MessageAnalysis(
            messageID: message.id,
            tokens: [
                MessageToken(
                    id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
                    text: "Bonjour",
                    translation: "Hello",
                    partOfSpeech: "Greeting"
                ),
                MessageToken(
                    id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!,
                    text: "Alex",
                    translation: "Alex",
                    partOfSpeech: "Name"
                )
            ],
            phraseSuggestions: ["Bonjour Alex", "Salut Alex"],
            grammarNotes: [
                GrammarNote(
                    id: UUID(uuidString: "50000000-0000-0000-0000-000000000001")!,
                    title: "Greeting register",
                    explanation: "Bonjour is neutral and works in most everyday contexts."
                )
            ]
        )
    }
}
