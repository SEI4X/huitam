import Foundation

@MainActor
protocol FriendServicing {
    func search(byNickname query: String) async throws -> [FriendSearchResult]
    func loadInvite(id: String) async throws -> PracticeInvite
    func createPracticeInvite(_ request: PracticeInviteRequest) async throws -> PracticeInvite
    func acceptInvite(_ invite: PracticeInvite, as role: ChatParticipantRole) async throws -> ChatSummary
    func openAccountChat(nickname: String, as role: ChatParticipantRole) async throws -> ChatSummary
}
