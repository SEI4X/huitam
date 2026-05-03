import FirebaseDatabase
import Foundation

final class FirebasePresenceService: PresenceServicing {
    private let authSession: FirebaseAuthSession
    private let database: DatabaseReference
    private var connectedHandle: DatabaseHandle?
    private var currentUserID: String?

    init(
        authSession: FirebaseAuthSession,
        databaseURL: String = "https://huitam-app-default-rtdb.firebaseio.com"
    ) {
        self.authSession = authSession
        self.database = Database.database(url: databaseURL).reference()
    }

    func startTrackingCurrentUser() async {
        guard currentUserID == nil, let uid = try? await authSession.currentUserID() else { return }
        currentUserID = uid

        let userPresenceRef = database.child("presence").child(uid)
        connectedHandle = database.child(".info/connected").observe(.value) { snapshot in
            guard snapshot.value as? Bool == true else { return }

            userPresenceRef.onDisconnectSetValue([
                "state": "offline",
                "lastChanged": ServerValue.timestamp()
            ])
            userPresenceRef.setValue([
                "state": "online",
                "lastChanged": ServerValue.timestamp()
            ])
        }
    }

    func stopTrackingCurrentUser() {
        if let connectedHandle {
            database.child(".info/connected").removeObserver(withHandle: connectedHandle)
        }
        connectedHandle = nil

        if let currentUserID {
            database.child("presence").child(currentUserID).setValue([
                "state": "offline",
                "lastChanged": ServerValue.timestamp()
            ])
        }
        currentUserID = nil
    }

    func presenceUpdates(for userID: String) -> AsyncStream<PresenceStatus> {
        guard userID.isEmpty == false else {
            return AsyncStream { continuation in
                continuation.yield(.offline)
                continuation.finish()
            }
        }

        let reference = database.child("presence").child(userID)
        return AsyncStream { continuation in
            let handle = reference.observe(.value) { snapshot in
                continuation.yield(Self.status(from: snapshot.value))
            }

            continuation.onTermination = { _ in
                reference.removeObserver(withHandle: handle)
            }
        }
    }

    private static func status(from value: Any?) -> PresenceStatus {
        guard let data = value as? [String: Any] else {
            return .offline
        }

        let isOnline = data["state"] as? String == "online"
        let rawLastChanged = data["lastChanged"]
        let lastChangedMilliseconds: Double?
        if let value = rawLastChanged as? Double {
            lastChangedMilliseconds = value
        } else if let value = rawLastChanged as? Int64 {
            lastChangedMilliseconds = Double(value)
        } else if let value = rawLastChanged as? Int {
            lastChangedMilliseconds = Double(value)
        } else {
            lastChangedMilliseconds = nil
        }
        let lastSeenAt = lastChangedMilliseconds.map { Date(timeIntervalSince1970: $0 / 1000) }
        return PresenceStatus(isOnline: isOnline, lastSeenAt: lastSeenAt)
    }
}
