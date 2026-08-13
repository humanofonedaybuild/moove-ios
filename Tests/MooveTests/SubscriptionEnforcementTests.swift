import XCTest
@testable import MooveKit
@testable import Moove

@MainActor
final class SubscriptionEnforcementTests: XCTestCase {
    private func makeManager() -> SubscriptionManager {
        let manager = SubscriptionManager()
        manager.persistence = UserDefaults(suiteName: "moove.tests.enforce.\(UUID().uuidString)") ?? .standard
        return manager
    }

    func testExpiredTrialMapsToGraceThenHardLock() {
        let manager = makeManager()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        manager.nowProvider = { now }

        manager.applyResolvedAccessForTesting(
            hasCurrentEntitlement: false,
            isInIntroductoryOffer: false,
            lastTrialExpiration: now.addingTimeInterval(-60),
            hasExpiredSubscriptionStatus: true
        )

        XCTAssertEqual(manager.subscriptionState, .trialGrace)
        XCTAssertTrue(manager.canUseAlarms)
        XCTAssertTrue(manager.shouldShowGraceBanner)
        XCTAssertFalse(manager.requiresHardPaywall)
        XCTAssertFalse(manager.isPremium)

        manager.nowProvider = { now.addingTimeInterval(Constants.postTrialGracePeriod + 1) }
        manager.applyResolvedAccessForTesting(
            hasCurrentEntitlement: false,
            isInIntroductoryOffer: false,
            lastTrialExpiration: now.addingTimeInterval(-60),
            hasExpiredSubscriptionStatus: true
        )

        XCTAssertEqual(manager.subscriptionState, .expired)
        XCTAssertFalse(manager.canUseAlarms)
        XCTAssertTrue(manager.requiresHardPaywall)
        XCTAssertTrue(manager.shouldShowPaywall)
        XCTAssertFalse(manager.shouldShowGraceBanner)
    }

    func testPaidConversionClearsHardLock() {
        let manager = makeManager()
        let now = Date()
        manager.nowProvider = { now }

        manager.applyResolvedAccessForTesting(
            hasCurrentEntitlement: false,
            isInIntroductoryOffer: false,
            lastTrialExpiration: now.addingTimeInterval(-Constants.postTrialGracePeriod - 10),
            hasExpiredSubscriptionStatus: true
        )
        XCTAssertTrue(manager.requiresHardPaywall)

        manager.applyResolvedAccessForTesting(
            hasCurrentEntitlement: true,
            isInIntroductoryOffer: false,
            lastTrialExpiration: now.addingTimeInterval(-Constants.postTrialGracePeriod - 10),
            hasExpiredSubscriptionStatus: false
        )

        XCTAssertEqual(manager.subscriptionState, .active)
        XCTAssertTrue(manager.isPremium)
        XCTAssertTrue(manager.canUseAlarms)
        XCTAssertFalse(manager.requiresHardPaywall)
        XCTAssertFalse(manager.shouldShowPaywall)
    }

    func testNeverStartedTrialDoesNotLockAlarms() {
        let manager = makeManager()
        manager.applyResolvedAccessForTesting(
            hasCurrentEntitlement: false,
            isInIntroductoryOffer: false,
            lastTrialExpiration: nil,
            hasExpiredSubscriptionStatus: false
        )

        XCTAssertEqual(manager.subscriptionState, .inactive)
        XCTAssertTrue(manager.canUseAlarms)
        XCTAssertFalse(manager.requiresHardPaywall)
        XCTAssertFalse(manager.shouldShowGraceBanner)
    }
}
