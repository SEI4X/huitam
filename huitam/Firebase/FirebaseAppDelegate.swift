import FirebaseAuth
import FirebaseMessaging
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
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard user != nil else { return }
            self?.flushPendingFCMToken()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
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
}
