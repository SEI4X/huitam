import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import SwiftUI
import UIKit
import UserNotifications

final class FirebaseAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    private let pendingFCMTokenKey = "huitam.pendingFCMToken"
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configureIfNeeded()
        configureGoogleSignInAppCheck()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        registerForRemoteNotificationsIfAuthorized(application)
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let user, user.isAnonymous == false else { return }
            self?.flushPendingFCMToken()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        refreshMessagingTokenAfterAPNSRegistration()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Remote notification registration failed: \(error.localizedDescription)")
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        UserDefaults.standard.set(fcmToken, forKey: pendingFCMTokenKey)
        flushPendingFCMToken()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    private func flushPendingFCMToken() {
        guard let token = UserDefaults.standard.string(forKey: pendingFCMTokenKey) else {
            return
        }

        Task { @MainActor in
            do {
                try await FirebaseNotificationTokenService().store(token: token)
                UserDefaults.standard.removeObject(forKey: pendingFCMTokenKey)
            } catch {
                UserDefaults.standard.set(token, forKey: pendingFCMTokenKey)
            }
        }
    }

    private func refreshMessagingTokenAfterAPNSRegistration() {
        Messaging.messaging().token { [weak self] token, _ in
            guard let self, let token else { return }
            UserDefaults.standard.set(token, forKey: self.pendingFCMTokenKey)
            self.flushPendingFCMToken()
        }
    }

    private func registerForRemoteNotificationsIfAuthorized(_ application: UIApplication) {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }

            await MainActor.run {
                application.registerForRemoteNotifications()
            }
        }
    }

    private func configureGoogleSignInAppCheck() {
        #if DEBUG
        guard let apiKey = FirebaseApp.app()?.options.apiKey else {
            return
        }
        GIDSignIn.sharedInstance.configureDebugProvider(withAPIKey: apiKey) { error in
            if let error {
                print("Error configuring Google Sign-In App Check debug provider: \(error)")
            }
        }
        #else
        GIDSignIn.sharedInstance.configure { error in
            if let error {
                print("Error configuring Google Sign-In App Check: \(error)")
            }
        }
        #endif
    }
}
