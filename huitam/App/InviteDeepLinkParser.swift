import Foundation

enum InviteDeepLinkParser {
    static func inviteID(from url: URL) -> String? {
        if url.scheme == "https", url.host == "huitam.com" {
            return inviteID(fromPathComponents: url.pathComponents)
        }

        if url.scheme == "huitam", url.host == "invite" {
            return url.pathComponents.dropFirst().first
        }

        return nil
    }

    private static func inviteID(fromPathComponents pathComponents: [String]) -> String? {
        guard pathComponents.count >= 3, pathComponents[1] == "invite" else {
            return nil
        }

        return pathComponents[2]
    }
}
