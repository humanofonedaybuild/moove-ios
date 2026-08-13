import Foundation

/// What the app may do after validating StoreKit / RevenueCat entitlements.
///
/// `.full` covers paid subscribers, an active 7-day intro trial, and users who
/// have never started a trial. `.trialGrace` is the 24-hour soft window after
/// an expired trial. `.blocked` is the hard lock: alarms stop and the
/// required paywall is shown.
public enum SubscriptionAccess: Equatable, Sendable {
    case full
    case trialGrace(endsAt: Date)
    case blocked

    public var canUseAlarms: Bool {
        switch self {
        case .full, .trialGrace: true
        case .blocked: false
        }
    }

    public var requiresHardPaywall: Bool {
        if case .blocked = self { true } else { false }
    }

    public var graceEndsAt: Date? {
        if case .trialGrace(let endsAt) = self { endsAt } else { nil }
    }
}

/// Pure post-trial gate. Fed by `Product.SubscriptionInfo.status` /
/// `Transaction.currentEntitlements` (or the RevenueCat equivalent).
public enum SubscriptionAccessPolicy: Sendable {
    public static func resolve(
        hasCurrentEntitlement: Bool,
        lastTrialExpiration: Date?,
        hasExpiredSubscriptionStatus: Bool,
        now: Date = Date(),
        gracePeriod: TimeInterval = Constants.postTrialGracePeriod
    ) -> SubscriptionAccess {
        if hasCurrentEntitlement { return .full }

        let trialEndedAt: Date?
        if let lastTrialExpiration, lastTrialExpiration <= now {
            trialEndedAt = lastTrialExpiration
        } else if hasExpiredSubscriptionStatus {
            trialEndedAt = now
        } else {
            trialEndedAt = nil
        }

        guard let trialEndedAt else { return .full }

        let graceEnd = trialEndedAt.addingTimeInterval(gracePeriod)
        if now < graceEnd {
            return .trialGrace(endsAt: graceEnd)
        }
        return .blocked
    }
}
