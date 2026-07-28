import XCTest

/// Focused verification for the Warm Editorial onboarding rebuild:
/// - the primary Continue action is visible and hittable on every page
/// - the welcome subtitle renders fully inside the screen (no clipping)
/// - swiping and tapping navigate through all three onboarding steps
final class OnboardingUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestingResetOnboarding"]
    }

    // MARK: - Helpers

    private var continueButton: XCUIElement {
        app.buttons["onboarding.continueButton"]
    }

    private var skipButton: XCUIElement {
        app.buttons["onboarding.skipButton"]
    }

    private func launchOnboarding(startPage: Int? = nil) {
        if let startPage {
            app.launchArguments += ["-onboardingStartPage", "\(startPage)"]
        }
        app.launch()
    }

    private func assertVisible(_ element: XCUIElement, _ label: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(label) should exist")
        XCTAssertTrue(element.isHittable, "\(label) should be hittable")
    }

    // MARK: - Tests

    /// The Continue action must be present and tappable on every page —
    /// regression test for the missing/blocked Continue button.
    func testContinueActionAvailableOnEveryPage() {
        launchOnboarding()

        // Page 1 — Welcome
        assertVisible(continueButton, "Continue on Welcome page")
        XCTAssertTrue(app.otherElements["onboarding.page.welcome"].exists)

        // Page 2 — How It Works
        app.swipeLeft()
        assertVisible(continueButton, "Continue on How It Works page")
        XCTAssertTrue(app.otherElements["onboarding.page.howItWorks"].waitForExistence(timeout: 5))

        // Page 3 — Permissions
        app.swipeLeft()
        assertVisible(continueButton, "Get Started on Permissions page")
        XCTAssertTrue(app.otherElements["onboarding.page.permissions"].waitForExistence(timeout: 5))
        XCTAssertEqual(continueButton.label, "Get Started")
    }

    /// The welcome subtitle must render fully on screen — regression test for
    /// the clipped subtitle.
    func testWelcomeSubtitleIsNotClipped() {
        launchOnboarding()

        let subtitle = app.staticTexts["onboarding.welcome.subtitle"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5), "Welcome subtitle should exist")

        let window = app.windows.element(boundBy: 0)
        XCTAssertTrue(window.exists)
        XCTAssertTrue(window.frame.contains(subtitle.frame),
                      "Subtitle frame \(subtitle.frame) must be fully inside the window \(window.frame)")

        // The subtitle must sit fully above the bottom bar — no overlap with
        // the Continue button means nothing was pushed or clipped into it.
        assertVisible(continueButton, "Continue on Welcome page")
        XCTAssertLessThan(subtitle.frame.maxY, continueButton.frame.minY,
                          "Subtitle must end above the Continue button")
        XCTAssertGreaterThan(subtitle.frame.height, 20,
                             "Subtitle must render multiple visible lines, not a truncated sliver")
    }

    /// Tapping Continue must advance through every onboarding step.
    func testContinueTapsNavigateThroughEveryStep() {
        launchOnboarding()

        XCTAssertTrue(app.otherElements["onboarding.page.welcome"].waitForExistence(timeout: 5))
        continueButton.tap()
        XCTAssertTrue(app.otherElements["onboarding.page.howItWorks"].waitForExistence(timeout: 5))
        continueButton.tap()
        XCTAssertTrue(app.otherElements["onboarding.page.permissions"].waitForExistence(timeout: 5))
    }

    /// Starting directly on the final page (screenshot hook) still shows a
    /// working primary action.
    func testStartPageHookLandsOnPermissions() {
        launchOnboarding(startPage: 2)

        XCTAssertTrue(app.otherElements["onboarding.page.permissions"].waitForExistence(timeout: 5))
        assertVisible(continueButton, "Get Started on Permissions page")
    }

    /// Skip completes onboarding from the first page.
    func testSkipCompletesOnboarding() {
        launchOnboarding()

        assertVisible(skipButton, "Skip on Welcome page")
        skipButton.tap()

        XCTAssertTrue(continueButton.waitForNonExistence(timeout: 5),
                      "Onboarding should dismiss after Skip")
    }
}
