import AuthenticationServices
import FirebaseCore
import GoogleSignIn
import SwiftUI
import UIKit

struct AuthView: View {
    @State private var viewModel: AuthSignInViewModel
    @State private var currentNonce: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(container: AppDependencyContainer) {
        _viewModel = State(initialValue: AuthSignInViewModel(authService: container.authService))
    }

    var body: some View {
        ZStack {
            AuthTechnologyBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        AuthSignalMark()

                        Text("huitam")
                            .font(.system(size: 43, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 68)
                    .premiumEntrance(delay: 0.05, edge: .top)

                    Spacer(minLength: 0)

                    VStack(spacing: 12) {
                        Text("Real chats become language practice.")
                            .font(.system(size: 27, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .premiumEntrance(delay: 0.18, edge: .bottom)

                        Text("Practice with people you already know, while every message stays natural, private, and yours.")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.66))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .premiumEntrance(delay: 0.30, edge: .bottom)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 286)
                }
            }

            AuthActionsPanel(
                isSigningIn: viewModel.isSigningIn,
                errorMessage: viewModel.errorMessage,
                appleAction: appleSignInButton,
                googleAction: signInWithGoogle
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .premiumEntrance(delay: 0.42, edge: .bottom)
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private var appleSignInButton: some View {
        SignInWithAppleButton(.continue) { request in
            let nonce = AppleSignInNonce.randomString()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
        } onCompletion: { result in
            switch result {
            case let .success(authorization):
                guard
                    let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                    let nonce = currentNonce
                else {
                    viewModel.clearSigningError()
                    return
                }
                Task {
                    await viewModel.signInWithApple(credential: credential, nonce: nonce)
                }
            case let .failure(error):
                guard error.isUserCancelledAuthFlow == false else {
                    viewModel.clearSigningError()
                    return
                }
                viewModel.setSigningError(error)
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .disabled(viewModel.isSigningIn)
    }

    private func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            viewModel.setSigningError(AuthSessionError.missingGoogleClientID)
            return
        }

        guard let presentingViewController = UIApplication.shared.huitamTopViewController else {
            viewModel.setSigningError(AuthSessionError.missingPresentationContext)
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            if let error {
                guard error.isUserCancelledAuthFlow == false else {
                    Task { @MainActor in
                        viewModel.clearSigningError()
                    }
                    return
                }
                Task { @MainActor in
                    viewModel.setSigningError(error)
                }
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                Task { @MainActor in
                    viewModel.setSigningError(AuthSessionError.missingGoogleIdentityToken)
                }
                return
            }

            let accessToken = user.accessToken.tokenString
            Task {
                await viewModel.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            }
        }
    }
}

private struct AuthActionsPanel<AppleAction: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isSigningIn: Bool
    let errorMessage: String?
    let appleAction: AppleAction
    let googleAction: () -> Void

    var body: some View {
        VStack(spacing: 13) {
            appleAction

            Button(action: googleAction) {
                HStack(spacing: 10) {
                    Text("G")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 22)
                    Text("Continue with Google")
                        .font(.system(size: 19, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 12, y: 7)
            .disabled(isSigningIn)

            if isSigningIn {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 2)
            }

            if let errorMessage {
                AuthErrorBanner(message: errorMessage)
                    .padding(.top, 7)
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.98)))
            }

            Text("Authorization keeps invites, chats, and your nickname tied to one account.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, errorMessage == nil ? 8 : 12)
                .padding(.horizontal, 4)
        }
        .animation(AppMotion.sheetPresent(reduceMotion: reduceMotion), value: errorMessage)
        .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: isSigningIn)
    }
}

private struct AuthErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red.opacity(0.92))
                .padding(.top, 1)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct AuthSignalMark: View {
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18 - Double(index) * 0.035),
                                Color.cyan.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .scaleEffect(1 + CGFloat(index) * 0.22)
                    .opacity(0.72 - Double(index) * 0.16)
            }

            Image(systemName: "message.badge.waveform")
                .font(.system(size: 33, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
        }
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
    }
}

private struct AuthTechnologyBackdrop: View {
    var body: some View {
        ZStack {
            PremiumScreenBackground(glowPosition: .bottom, intensity: 0.86)

            GridOverlay()
                .opacity(0.55)
        }
    }
}

private struct GridOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let spacing: CGFloat = 34
                var x: CGFloat = 0
                while x < proxy.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    x += spacing
                }

                var y: CGFloat = 0
                while y < proxy.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    y += spacing
                }
            }
            .stroke(Color.white.opacity(0.025), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    AuthView(container: .mock())
}
