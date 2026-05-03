import AuthenticationServices
import Foundation
import GoogleSignIn
import Observation

@MainActor
@Observable
final class AuthSignInViewModel {
    private let authService: AuthServicing

    private(set) var isSigningIn = false
    private(set) var errorMessage: String?

    init(authService: AuthServicing) {
        self.authService = authService
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async {
        await signIn {
            try await authService.signInWithApple(credential: credential, nonce: nonce)
        }
    }

    func signInWithGoogle(idToken: String, accessToken: String) async {
        await signIn {
            try await authService.signInWithGoogle(idToken: idToken, accessToken: accessToken)
        }
    }

    private func signIn(_ action: () async throws -> AuthSessionState) async {
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            _ = try await action()
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }

    func setSigningError(_ error: Error) {
        guard error.isUserCancelledAuthFlow == false else {
            errorMessage = nil
            return
        }
        errorMessage = AppErrorMessage.userFacing(error)
    }

    func clearSigningError() {
        errorMessage = nil
    }
}

extension Error {
    var isUserCancelledAuthFlow: Bool {
        let nsError = self as NSError

        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.Code.canceled.rawValue {
            return true
        }

        if nsError.domain == kGIDSignInErrorDomain,
           nsError.code == GIDSignInError.Code.canceled.rawValue {
            return true
        }

        return false
    }
}
