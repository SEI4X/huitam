import FirebaseDatabase
import Foundation

final class FirebasePresenceService: PresenceServicing {
    private let authSession: FirebaseAuthSession
    private let database: Database
    private let rootReference: DatabaseReference
    private var connectedHandle: DatabaseHandle?
    private var currentUserID: String?
    private var activePresenceObserverCount = 0

    init(
        authSession: FirebaseAuthSession,
        databaseURL: String = "https://huitam-app-default-rtdb.firebaseio.com"
    ) {
        self.authSession = authSession
        self.database = Database.database(url: databaseURL)
        self.rootReference = database.reference()
    }

    func startTrackingCurrentUser() async {
        guard currentUserID == nil, let uid = try? await authSession.currentUserID() else { return }
        currentUserID = uid
        database.goOnline()

        let userPresenceRef = rootReference.child("presence").child(uid)
        connectedHandle = rootReference.child(".info/connected").observe(.value) { snapshot in
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
            rootReference.child(".info/connected").removeObserver(withHandle: connectedHandle)
        }
        connectedHandle = nil

        if let currentUserID {
            rootReference.child("presence").child(currentUserID).setValue([
                "state": "offline",
                "lastChanged": ServerValue.timestamp()
            ]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.disconnectIfIdle()
                }
            }
        } else {
            disconnectIfIdle()
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

        database.goOnline()
        activePresenceObserverCount += 1
        let reference = rootReference.child("presence").child(userID)
        return AsyncStream { continuation in
            let handle = reference.observe(.value) { snapshot in
                continuation.yield(Self.status(from: snapshot.value))
            }

            continuation.onTermination = { [weak self] _ in
                reference.removeObserver(withHandle: handle)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    activePresenceObserverCount = max(0, activePresenceObserverCount - 1)
                    disconnectIfIdle()
                }
            }
        }
    }

    private func disconnectIfIdle() {
        guard currentUserID == nil, activePresenceObserverCount == 0 else { return }
        database.goOffline()
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
