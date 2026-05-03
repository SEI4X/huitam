import AuthenticationServices
import Foundation

struct AuthSessionState: Equatable {
    var userID: String?

    static let signedOut = AuthSessionState(userID: nil)

    var isAuthenticated: Bool {
        userID != nil
    }
}

enum AuthSessionError: LocalizedError {
    case unauthenticated
    case missingAppleIdentityToken
    case missingGoogleClientID
    case missingGoogleIdentityToken
    case missingPresentationContext

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            "Sign in is required."
        case .missingAppleIdentityToken:
            "Apple did not return an identity token."
        case .missingGoogleClientID:
            "Google Sign-In is not configured."
        case .missingGoogleIdentityToken:
            "Google did not return an identity token."
        case .missingPresentationContext:
            "Could not open the sign-in screen."
        }
    }
}

@MainActor
protocol AuthServicing {
    var authStateUpdates: AsyncStream<AuthSessionState> { get }

    func loadSession() async -> AuthSessionState
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws -> AuthSessionState
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> AuthSessionState
    func signOut() async throws
    func deleteAccount(reason: String) async throws
}
