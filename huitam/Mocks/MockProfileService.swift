import Foundation

@MainActor
final class MockProfileService: ProfileServicing {
    private var profile: UserProfile
    var cachedProfile: UserProfile? {
        profile
    }

    init(profile: UserProfile? = nil) {
        self.profile = profile ?? MockAppData.profile
    }

    func loadProfile() async throws -> UserProfile {
        profile
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        self.profile = profile
        return profile
    }
}
