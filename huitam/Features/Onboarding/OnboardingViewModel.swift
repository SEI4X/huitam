import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    private let onboardingService: OnboardingServicing
    private let settingsService: SettingsServicing
    private let profileService: ProfileServicing
    private let notificationPermissionService: NotificationPermissionServicing

    private(set) var state = OnboardingState.notStarted
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var nickname = ""
    var nativeLanguage: AppLanguage = .russian
    var learningLanguage: AppLanguage = .english {
        didSet {
            guard learningSelection.isEnabled else { return }
            learningSelection = .language(learningLanguage)
        }
    }
    var learningSelection: LearningLanguageSelection = .language(.english)

    var normalizedNickname: String {
        nickname
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    var isNicknameLongEnough: Bool {
        normalizedNickname.count >= 3
    }

    var invalidNicknameCharacters: [String] {
        let invalidCharacters = nickname.lowercased().filter { character in
            Self.allowedNicknameCharacters.contains(character) == false
        }
        return Array(Set(invalidCharacters.map(Self.displayName(for:)))).sorted()
    }

    var isNicknameValid: Bool {
        isNicknameLongEnough && invalidNicknameCharacters.isEmpty
    }

    var nicknameValidationMessage: String {
        if normalizedNickname.isEmpty {
            return "3+ chars: a-z, 0-9, . _ - / no spaces."
        }
        if invalidNicknameCharacters.isEmpty == false {
            return "Not allowed: \(invalidNicknameCharacters.joined(separator: ", ")). Use only a-z, 0-9, . _ -"
        }
        if isNicknameLongEnough == false {
            return "Nickname must be at least 3 characters."
        }
        return "Looks good. This nickname will be used in invites."
    }

    init(
        onboardingService: OnboardingServicing,
        settingsService: SettingsServicing,
        profileService: ProfileServicing,
        notificationPermissionService: NotificationPermissionServicing = AppNotificationPermissionService()
    ) {
        self.onboardingService = onboardingService
        self.settingsService = settingsService
        self.profileService = profileService
        self.notificationPermissionService = notificationPermissionService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            state = try await onboardingService.loadState()
            nativeLanguage = state.nativeLanguage
            if let learningLanguage = state.currentUserRole.learningLanguage {
                self.learningLanguage = learningLanguage
                learningSelection = .language(learningLanguage)
            } else if state.hasCompletedOnboarding {
                learningSelection = .none
            }
            let profile = try await profileService.loadProfile()
            nickname = profile.nickname.hasPrefix("user-") ? "" : profile.nickname
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }

    func completeAsLearner() async {
        await complete(role: .learner(learningLanguage), learningSelection: .language(learningLanguage))
    }

    func completeAsCompanion() async {
        await complete(role: .companion, learningSelection: .none)
    }

    func completeLearningChoice(requestNotifications: Bool = false) async {
        if let selectedLanguage = learningSelection.language {
            learningLanguage = selectedLanguage
            await complete(role: .learner(selectedLanguage), learningSelection: .language(selectedLanguage), requestNotifications: requestNotifications)
        } else {
            await complete(role: .companion, learningSelection: .none, requestNotifications: requestNotifications)
        }
    }

    func selectLearningLanguage(_ language: AppLanguage) {
        learningLanguage = language
        learningSelection = .language(language)
    }

    func selectNoLearning() {
        learningSelection = .none
    }

    private func complete(
        role: ChatParticipantRole,
        learningSelection: LearningLanguageSelection,
        requestNotifications: Bool = false
    ) async {
        let normalizedNickname = normalizedNickname

        guard isNicknameValid else {
            errorMessage = nicknameValidationMessage
            return
        }

        do {
            var settings = try await settingsService.loadSettings()
            settings.nativeLanguage = nativeLanguage
            settings.learningLanguage = learningSelection
            if requestNotifications {
                settings.notificationsEnabled = await notificationPermissionService.updateRegistration(enabled: true)
            }
            _ = try await settingsService.updateSettings(settings)

            var profile = try await profileService.loadProfile()
            profile.nickname = normalizedNickname
            profile.displayName = normalizedNickname
            profile.nativeLanguage = nativeLanguage
            profile.learningLanguage = learningSelection
            _ = try await profileService.updateProfile(profile)

            state = try await onboardingService.complete(role: role, nativeLanguage: nativeLanguage)
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }

    private static let allowedNicknameCharacters = Set("abcdefghijklmnopqrstuvwxyz0123456789._-")

    private static func displayName(for character: Character) -> String {
        switch character {
        case " ":
            "space"
        case "\n":
            "line break"
        case "\t":
            "tab"
        default:
            String(character)
        }
    }
}
