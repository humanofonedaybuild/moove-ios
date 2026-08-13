import XCTest
@testable import MooveKit

final class LaunchSequenceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "LaunchSequenceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFirstLaunchRoutesToOnboarding() {
        XCTAssertFalse(LaunchSequence.isOnboardingCompleted(defaults: defaults))
        XCTAssertEqual(
            LaunchSequence.routeAfterLoading(onboardingCompleted: false),
            .onboarding
        )
    }

    func testCompletedOnboardingRoutesToMain() {
        LaunchSequence.setOnboardingCompleted(true, defaults: defaults)
        XCTAssertTrue(LaunchSequence.isOnboardingCompleted(defaults: defaults))
        XCTAssertEqual(
            LaunchSequence.routeAfterLoading(onboardingCompleted: true),
            .main
        )
    }

    func testHoldLoadingScreenStaysOnLoading() {
        XCTAssertEqual(
            LaunchSequence.routeAfterLoading(
                onboardingCompleted: false,
                holdLoadingScreen: true
            ),
            .loading
        )
        XCTAssertEqual(
            LaunchSequence.routeAfterLoading(
                onboardingCompleted: true,
                holdLoadingScreen: true
            ),
            .loading
        )
    }

    func testCompletionFlagRoundTrip() {
        LaunchSequence.setOnboardingCompleted(true, defaults: defaults)
        XCTAssertTrue(LaunchSequence.isOnboardingCompleted(defaults: defaults))
        LaunchSequence.setOnboardingCompleted(false, defaults: defaults)
        XCTAssertFalse(LaunchSequence.isOnboardingCompleted(defaults: defaults))
    }

    func testHoldArgumentDetection() {
        XCTAssertTrue(
            LaunchSequence.shouldHoldLoadingScreen(
                arguments: ["-UITestingHoldLoadingScreen"]
            )
        )
        XCTAssertFalse(LaunchSequence.shouldHoldLoadingScreen(arguments: []))
    }
}
