import XCTest

/// Screenshot capture pass for the Warm Editorial redesign (MOO-56).
/// Each test navigates to a redesigned surface and attaches a full-screen
/// screenshot for design review. Screenshots are exported from the xcresult.
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
    }

    // MARK: - Helpers

    private func save(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForMainInterface() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    // MARK: - Captures

    func test01AlarmListEmptyState() {
        app.launchArguments += ["-UITestingClearAlarms"]
        app.launch()
        waitForMainInterface()

        XCTAssertTrue(app.buttons["alarmList.emptyState.createButton"].waitForExistence(timeout: 5))
        save("01-alarm-list-empty")
    }

    func test02AlarmListWithAlarms() {
        app.launchArguments += ["-UITestingSeedAlarms"]
        app.launch()
        waitForMainInterface()

        XCTAssertTrue(app.staticTexts["Weekday Alarm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Gym Day"].exists)
        save("02-alarm-list")
    }

    func test03NewAlarmSheet() {
        app.launchArguments += ["-UITestingSeedAlarms"]
        app.launch()
        waitForMainInterface()

        app.buttons["alarmList.addButton"].tap()
        XCTAssertTrue(app.navigationBars["New Alarm"].waitForExistence(timeout: 5))
        save("03-alarm-edit")
    }

    func test04Settings() {
        app.launchArguments += ["-UITestingSeedAlarms"]
        app.launch()
        waitForMainInterface()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        save("04-settings")
    }

    func test05Paywall() {
        app.launchArguments += ["-UITestingSeedAlarms"]
        app.launch()
        waitForMainInterface()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let upgrade = app.buttons["settings.upgrade"]
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
        upgrade.tap()

        let paywallTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Moove Premium")
        ).firstMatch
        XCTAssertTrue(paywallTitle.waitForExistence(timeout: 5))
        save("05-paywall")
    }

    func test06MissionCountdown() {
        app.launchArguments += ["-UITestingStartMission"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Wake up."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["steps remaining"].exists)
        save("06-mission-countdown")
    }

    func test07MissionSnoozeUsed() {
        app.launchArguments += ["-UITestingStartMission"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Wake up."].waitForExistence(timeout: 10))

        let snoozeChip = app.buttons["5m"]
        XCTAssertTrue(snoozeChip.waitForExistence(timeout: 5))
        snoozeChip.tap()

        // The snoozed UX replaces the mission view with a dedicated snooze
        // screen; the chip disappears from the hierarchy entirely.
        XCTAssertTrue(app.staticTexts["Snoozed"].waitForExistence(timeout: 5),
                      "Snoozed cover screen must appear after tapping snooze")
        save("07-mission-snoozed")
    }
}
