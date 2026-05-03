import Foundation

enum AppErrorMessage {
    static func userFacing(_ error: Error) -> String {
        let nsError = error as NSError
        let description = error.localizedDescription

        if description.localizedCaseInsensitiveContains("No APNS token specified") {
            return "Notifications are almost ready. Please try again in a moment."
        }

        if nsError.domain == "FIRFirestoreErrorDomain", nsError.code == 7 {
            return "We couldn't sync your account yet. Please try again in a moment."
        }

        if nsError.domain == "com.firebase.functions", nsError.code == 7 {
            return "We couldn't complete this action yet. Please try again in a moment."
        }

        if description.localizedCaseInsensitiveContains("restricted to administrators") ||
            description.localizedCaseInsensitiveContains("permission") ||
            description.localizedCaseInsensitiveContains("app attestation") ||
            description.localizedCaseInsensitiveContains("app check") {
            return "We couldn't sync your account yet. Please try again in a moment."
        }

        return description
    }
}
