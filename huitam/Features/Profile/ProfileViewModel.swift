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
    }

    func load() async {
        do {
            profile = try await profileService.loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
