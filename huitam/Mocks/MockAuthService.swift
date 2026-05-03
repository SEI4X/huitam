import AuthenticationServices
import Foundation

@MainActor
final class MockAuthService: AuthServicing {
    var state: AuthSessionState
    var authStateUpdates: AsyncStream<AuthSessionState> {
        AsyncStream { continuation in
            continuation.yield(state)
            continuation.finish()
        }
    }

    init(state: AuthSessionState = AuthSessionState(userID: "mock-user")) {
        self.state = state
    }

    func loadSession() async -> AuthSessionState {
        state
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws -> AuthSessionState {
        state = AuthSessionState(userID: "mock-user")
        return state
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws -> AuthSessionState {
        state = AuthSessionState(userID: "mock-user")
        return state
    }

    func signOut() async throws {
        state = .signedOut
    }

    func deleteAccount(reason: String) async throws {
        state = .signedOut
    }
}
