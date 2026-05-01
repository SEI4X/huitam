import Foundation

@MainActor
protocol SubscriptionServicing {
    func loadEntitlement() async throws -> SubscriptionEntitlement
    func startTrial() async throws -> SubscriptionEntitlement
}
