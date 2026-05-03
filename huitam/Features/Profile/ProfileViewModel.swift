import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    private let profileService: ProfileServicing

    private(set) var profile: UserProfile?
    private(set) var errorMessage: String?

    init(profileService: ProfileServicing) {
        self.profileService = profileService
        profile = profileService.cachedProfile
    }

    func load() async {
        do {
            let loadedProfile = try await profileService.loadProfile()
            if profile != loadedProfile {
                profile = loadedProfile
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
