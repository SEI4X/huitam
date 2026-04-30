import Foundation

@MainActor
protocol ProfileServicing {
    func loadProfile() async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
}
