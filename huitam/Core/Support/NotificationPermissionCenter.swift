import UIKit
import UserNotifications

enum NotificationPermissionCenter {
    static func updateRegistration(enabled: Bool) async -> Bool {
        guard enabled else {
            await MainActor.run {
                UIApplication.shared.unregisterForRemoteNotifications()
            }
            return false
        }

        let granted = await requestAuthorization()
        guard granted else { return false }

        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return true
    }

    private static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}
