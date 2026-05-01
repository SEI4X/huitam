import Foundation

@MainActor
final class MockFriendService: FriendServicing {
    private let results: [FriendSearchResult]

    init(results: [FriendSearchResult]? = nil) {
        self.results = results ?? MockAppData.friendResults
    }

    func search(byNickname query: String) async throws -> [FriendSearchResult] {
        let normalizedQuery = query.lowercased()
        return results.filter { result in
            result.nickname.lowercased().contains(normalizedQuery)
        }
    }

    func sharePayload() async throws -> String {
        "huitam://add/alex"
    }

    func loadInvite(id: String) async throws -> PracticeInvite {
        MockAppData.sampleInvite
    }

    func createPracticeInvite(_ request: PracticeInviteRequest) async throws -> PracticeInvite {
        PracticeInvite(
            id: "mock-invite",
            inviterDisplayName: "Alex",
            inviterNativeLanguage: MockAppData.profile.nativeLanguage,
            inviterLearningLanguage: MockAppData.profile.learningLanguage.language ?? .english,
            guestNativeLanguage: request.guestNativeLanguage,
            guestLearningLanguage: request.guestLearningLanguage
        )
    }

    func acceptInvite(_ invite: PracticeInvite, as role: ChatParticipantRole) async throws -> ChatSummary {
        ChatSummary(
            id: UUID(),
            participant: ChatParticipant(
                id: MockAppData.currentUserID,
                nickname: "alex",
                displayName: invite.inviterDisplayName,
                avatarSystemImage: "person.crop.circle.fill",
                nativeLanguage: invite.inviterNativeLanguage,
                learningLanguage: .language(invite.inviterLearningLanguage)
            ),
            lastMessagePreview: "You joined \(invite.inviterDisplayName)'s practice chat.",
            timestamp: Date(),
            unreadCount: 0,
            nativeLanguage: invite.guestNativeLanguage,
            practiceLanguage: role.learningLanguage,
            currentUserRole: role,
            participantRole: .learner(invite.inviterLearningLanguage)
        )
    }
}
