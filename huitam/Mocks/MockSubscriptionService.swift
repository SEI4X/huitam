import Foundation

@MainActor
final class MockSubscriptionService: SubscriptionServicing {
    private var entitlement: SubscriptionEntitlement

    init(entitlement: SubscriptionEntitlement = .trial) {
        self.entitlement = entitlement
    }

    func loadEntitlement() async throws -> SubscriptionEntitlement {
        entitlement
    }

    func startTrial() async throws -> SubscriptionEntitlement {
        entitlement = .trial
        return entitlement
    }
}
