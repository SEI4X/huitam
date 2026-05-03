import Foundation
import Observation

@MainActor
@Observable
final class AuthGateViewModel {
    private let authService: AuthServicing

    private(set) var session = AuthSessionState.signedOut
    private(set) var isLoading = false

    var isAuthenticated: Bool {
        session.isAuthenticated
    }

    var userID: String? {
        session.userID
    }

    init(authService: AuthServicing) {
        self.authService = authService
    }

    func load() async {
        isLoading = true
        session = await authService.loadSession()
        isLoading = false
    }

    func startObserving() async {
        await load()
        for await state in authService.authStateUpdates {
            session = state
        }
    }
}
