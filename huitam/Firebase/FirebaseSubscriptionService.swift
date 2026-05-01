import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseSubscriptionService: SubscriptionServicing {
    private let authSession: FirebaseAuthSession
    private let db: Firestore

    init(authSession: FirebaseAuthSession, db: Firestore = Firestore.firestore()) {
        self.authSession = authSession
        self.db = db
    }

    func loadEntitlement() async throws -> SubscriptionEntitlement {
        let uid = try await authSession.currentUserID()
        let snapshot = try await FirebaseAsync.getDocument(entitlementReference(uid: uid))
        guard let status = snapshot.data()?["status"] as? String else {
            return .free
        }

        return SubscriptionEntitlement(rawValue: status) ?? .free
    }

    func startTrial() async throws -> SubscriptionEntitlement {
        let result = try await FirebaseAsync.call("startTrial", payload: [:])
        guard
            let data = result as? [String: Any],
            let status = data["status"] as? String,
            let entitlement = SubscriptionEntitlement(rawValue: status)
        else {
            throw FirebaseMappingError.missingField("status")
        }
        return entitlement
    }

    private func entitlementReference(uid: String) -> DocumentReference {
        db.collection("users").document(uid).collection("private").document("entitlement")
    }
}

private extension SubscriptionEntitlement {
    init?(rawValue: String) {
        switch rawValue {
        case "free": self = .free
        case "trial": self = .trial
        case "active": self = .active
        default: return nil
        }
    }

    var rawValue: String {
        switch self {
        case .free: "free"
        case .trial: "trial"
        case .active: "active"
        }
    }
}
