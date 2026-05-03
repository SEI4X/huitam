import Foundation

@MainActor
protocol ProfileServicing {
    var cachedProfile: UserProfile? { get }

    func loadProfile() async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
}
