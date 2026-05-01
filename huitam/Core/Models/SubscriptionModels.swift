import Foundation

enum SubscriptionEntitlement: Equatable {
    case free
    case trial
    case active

    var canUseLearnerFeatures: Bool {
        switch self {
        case .free: false
        case .trial, .active: true
        }
    }
}
