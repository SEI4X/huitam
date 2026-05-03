import AuthenticationServices
import GoogleSignIn
import XCTest
@testable import huitam

@MainActor
final class AuthGateViewModelTests: XCTestCase {
    func testAnonymousUserIsTreatedAsSignedOut() async {
        let auth = RecordingAuthService(initialState: .signedOut)
        let viewModel = AuthGateViewModel(authService: auth)

        await viewModel.load()

        XCTAssertFalse(viewModel.isAuthenticated)
    }

    func testAuthenticatedUserUnlocksApp() async {
        let auth = RecordingAuthService(initialState: AuthSessionState(userID: "user-1"))
        let viewModel = AuthGateViewModel(authService: auth)

        await viewModel.load()

        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertEqual(viewModel.userID, "user-1")
    }

    func testGoogleSignInUsesAuthServiceTokens() async {
        let auth = RecordingAuthService(initialState: .signedOut)
        let viewModel = AuthSignInViewModel(authService: auth)

        await viewModel.signInWithGoogle(idToken: "id-token", accessToken: "access-token")

        XCTAssertEqual(auth.googleSignInTokens.count, 1)
        XCTAssertEqual(auth.googleSignInTokens.first?.idToken, "id-token")
        XCTAssertEqual(auth.googleSignInTokens.first?.accessToken, "access-token")
        XCTAssertFalse(viewModel.isSigningIn)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAuthCancellationDoesNotShowError() {
        let auth = RecordingAuthService(initialState: .signedOut)
        let viewModel = AuthSignInViewModel(authService: auth)

        let appleCancel = ASAuthorizationError(.canceled)
        viewModel.setSigningError(appleCancel)

        XCTAssertNil(viewModel.errorMessage)

        let googleCancel = NSError(
            domain: kGIDSignInErrorDomain,
            code: GIDSignInError.Code.canceled.rawValue
        )
        viewModel.setSigningError(googleCancel)

        XCTAssertNil(viewModel.errorMessage)
    }
}
