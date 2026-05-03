import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation

@MainActor
final class FirebaseAuthService: AuthServicing {
    var authStateUpdates: AsyncStream<AuthSessionState> {
        AsyncStream { continuation in
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                if user?.isAnonymous == true {
                    try? Auth.auth().signOut()
                    continuation.yield(.signedOut)
                    return
                }

                continuation.yield(AuthSessionState(userID: user?.uid))
            }

            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }

    func loadSession() async -> AuthSessionState {
        guard let user = Auth.auth().currentUser, user.isAnonymous == false else {
            if Auth.auth().currentUser?.isAnonymous == true {
                try? Auth.auth().signOut()
            }
            return .signedOut
        }

        return AuthSessionState(userID: user.uid)
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws -> AuthSessionState {
        guard
            let identityToken = credential.identityToken,
            let tokenString = String(data: identityToken, encoding: .utf8)
        else {
            throw AuthSessionError.missingAppleIdentityToken
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        let result = try await signIn(with: firebaseCredential)
        return AuthSessionState(userID: result.user.uid)
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws -> AuthSessionState {
        let trimmedIDToken = idToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedIDToken.isEmpty == false, trimmedAccessToken.isEmpty == false else {
            throw AuthSessionError.missingGoogleIdentityToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: trimmedIDToken,
            accessToken: trimmedAccessToken
        )
        let result = try await signIn(with: credential)
        return AuthSessionState(userID: result.user.uid)
    }

    func signOut() async throws {
        try Auth.auth().signOut()
    }

    func deleteAccount(reason: String) async throws {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedReason.count >= 3 else {
            throw FirebaseMappingError.invalidField("reason")
        }

        _ = try await FirebaseAsync.call("deleteAccount", payload: ["reason": trimmedReason])
        try? Auth.auth().signOut()
    }

    private func signIn(with credential: AuthCredential) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: FirebaseMappingError.missingField("authResult"))
                }
            }
        }
    }
}

enum AppleSignInNonce {
    static func randomString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            guard status == errSecSuccess else {
                fatalError("Unable to generate nonce.")
            }

            randoms.forEach { random in
                guard remainingLength > 0 else { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}
