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

    func scanQRCodeMockResult() async throws -> FriendSearchResult? {
        results.first
    }
}
