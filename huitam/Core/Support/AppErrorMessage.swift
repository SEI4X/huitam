import Foundation

enum AppErrorMessage {
    static func userFacing(_ error: Error) -> String {
        let nsError = error as NSError
        let description = error.localizedDescription

        if nsError.domain == "FIRFirestoreErrorDomain", nsError.code == 7 {
            return "Firebase access is not configured yet. Deploy Firestore rules and register the App Check debug token."
        }

        if nsError.domain == "com.firebase.functions", nsError.code == 7 {
            return "This action needs server permissions. Check Firebase Functions and App Check configuration."
        }

        if description.localizedCaseInsensitiveContains("restricted to administrators") ||
            description.localizedCaseInsensitiveContains("permission") {
            return "Firebase access is not configured yet. Deploy Firestore rules and register the App Check debug token."
        }

        return description
    }
}
