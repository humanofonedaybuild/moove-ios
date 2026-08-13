import XCTest
@testable import MooveKit

final class SubscriptionAccessPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var grace: TimeInterval { Constants.postTrialGracePeriod }

    func testNeverStartedTrialStaysFullAccess() {
        let access = SubscriptionAccessPolicy.resolve(
            hasCurrentEntitlement: false,
            lastTrialExpiration: nil,
            hasExpiredSubscriptionStatus: false,
            now: now
        )
        XCTAssertEqual(access, .full)
        XCTAssertTrue(access.canUseAlarms)
        XCTAssertFalse(access.requiresHardPaywall)
    }

    func testActiveEntitlementIsFullAccess() {
        let access = SubscriptionAccessPolicy.resolve(
            hasCurrentEntitlement: true,
            lastTrialExpiration: now.addingTimeInterval(grace),
            hasExpiredSubscriptionStatus: false,
            now: now
        )
        XCTAssertEqual(access, .full)
        XCTAssertTrue(access.canUseAlarms)
    }

    func testTrialExpirationInTheFutureWithoutExpiredStatusStaysFull() {
        let access = SubscriptionAccessPolicy.resolve(
            hasCurrentEntitlement: false,
            lastTrialExpiration: now.addingTimeInterval(3600),
            hasExpiredSubscriptionStatus: false,
            now: now
        )
        XCTAssertEqual(access, .full)
    }

    func testJustExpiredTrialEntersGrace() {
        let trialEnd = now.addingTimeInterval(-60)
        let access = SubscriptionAccessPolicy.resolve(
            hasCurrentEntitlement: false,
            lastTrialExpiration: trialEnd,
            hasExpiredSubscriptionStatus: true,
            now: now
        )
        XCTAssertEqual(access, .trialGrace(endsAt: trialEnd.addingTimeInterval(grace)))
        XCTAssertTrue(access.canUseAlarms)
        XCTAssertFalse(access.requiresHardPaywall)
        XCTAssertNotNil(access.graceEndsAt)
    }

    func testExpiredStatusWithoutPersistedDateUsesNowAsTrialEnd() {
        let access = SubscriptionAccessPolicy.resolve(
            hasCurrentEntitlement: false,
            lastTrialExpiration: nil,
            hasExpiredSubscriptionStatus: true,
            now: now
        )
        XCTAssertEqual(access, .trialGrace(endsAt: now.addingTimeInterval(grace)))
    }

    func testGraceWindowStillOpenAt23Hours() {
        let trialEnd = now.addingTimeInterval(-23 * 3600)
        let access = SubscriptionAccessPolicy.resolve(
            hasCurrentEntitlement: false,
            lastTrialExpiration: trialEnd,
            hasExpiredSubscriptionStatus: true,
            now: now
        )
        XCTAssertEqual(access, .trialGrace(endsAt: trialEnd.addingTimeInterval(grace)))
    }

    func testHardBlockAfter24HourGrace() {
        let trialEnd = now.addingTimeInterval(-grace)
        let access = SubscriptionAccessPolicy.resolve(
            hasCurrentEntitlement: false,
            lastTrialExpiration: trialEnd,
            hasExpiredSubscriptionStatus: true,
            now: now
        )
        XCTAssertEqual(access, .blocked)
        XCTAssertFalse(access.canUseAlarms)
        XCTAssertTrue(access.requiresHardPaywall)
    }

    func testHardBlockDaysAfterTrial() {
        let trialEnd = now.addingTimeInterval(-3 * 24 * 3600)
        let access = SubscriptionAccessPolicy.resolve(
            hasCurrentEntitlement: false,
            lastTrialExpiration: trialEnd,
            hasExpiredSubscriptionStatus: true,
            now: now
        )
        XCTAssertEqual(access, .blocked)
    }

    func testPaidEntitlementOverridesExpiredStatus() {
        let access = SubscriptionAccessPolicy.resolve(
            hasCurrentEntitlement: true,
            lastTrialExpiration: now.addingTimeInterval(-grace * 2),
            hasExpiredSubscriptionStatus: true,
            now: now
        )
        XCTAssertEqual(access, .full)
        XCTAssertTrue(access.canUseAlarms)
    }

    func testGracePeriodConstantIs24Hours() {
        XCTAssertEqual(Constants.postTrialGracePeriod, 24 * 3600)
    }
}
