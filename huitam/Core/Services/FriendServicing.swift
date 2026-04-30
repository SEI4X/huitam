import Foundation

@MainActor
protocol FriendServicing {
    func search(byNickname query: String) async throws -> [FriendSearchResult]
    func sharePayload() async throws -> String
    func scanQRCodeMockResult() async throws -> FriendSearchResult?
}
