import Foundation

struct PresenceStatus: Equatable, Sendable {
    var isOnline: Bool
    var lastSeenAt: Date?

    static let offline = PresenceStatus(isOnline: false, lastSeenAt: nil)

    var label: String {
        if isOnline {
            return "online"
        }

        guard let lastSeenAt else {
            return "last seen recently"
        }

        let elapsed = Date().timeIntervalSince(lastSeenAt)
        if elapsed < 60 * 60 * 24 {
            return "last seen recently"
        }

        return "last seen recently"
    }
}
