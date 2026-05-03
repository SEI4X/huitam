import Foundation

final class MockPresenceService: PresenceServicing {
    var statusesByUserID: [String: PresenceStatus]
    private(set) var isTrackingCurrentUser = false

    init(statusesByUserID: [String: PresenceStatus] = [
        "firebase-camille": PresenceStatus(isOnline: true, lastSeenAt: Date()),
        "firebase-mateo": PresenceStatus(isOnline: false, lastSeenAt: Date())
    ]) {
        self.statusesByUserID = statusesByUserID
    }

    func startTrackingCurrentUser() async {
        isTrackingCurrentUser = true
    }

    func stopTrackingCurrentUser() {
        isTrackingCurrentUser = false
    }

    func presenceUpdates(for userID: String) -> AsyncStream<PresenceStatus> {
        AsyncStream { continuation in
            continuation.yield(statusesByUserID[userID] ?? .offline)
            continuation.finish()
        }
    }
}
