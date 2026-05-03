import Foundation

protocol PresenceServicing {
    func startTrackingCurrentUser() async
    func stopTrackingCurrentUser()
    func presenceUpdates(for userID: String) -> AsyncStream<PresenceStatus>
}

final class NoopPresenceService: PresenceServicing {
    func startTrackingCurrentUser() async {}

    func stopTrackingCurrentUser() {}

    func presenceUpdates(for userID: String) -> AsyncStream<PresenceStatus> {
        AsyncStream { continuation in
            continuation.yield(.offline)
            continuation.finish()
        }
    }
}
