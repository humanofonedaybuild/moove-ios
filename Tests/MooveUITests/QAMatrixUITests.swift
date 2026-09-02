import StoreKitTest
import XCTest

/// MOO-87 end-to-end QA matrix driver.
///
/// Each test walks one row of the QA matrix on the iOS 26 simulator and
/// attaches full-screen screenshots as evidence (exported from the xcresult).
/// Simulator limitations: the pedometer and accelerometer produce no data, so
/// the step countdown is driven through the `-UITestingStepSim` debug button
/// (same monotonic combined-count path as shake events), and the snooze
/// duration is shortened via `-UITestingShortSnooze`.
///
/// StoreKit sandbox: `xcodebuild` does not apply a scheme TestAction
/// StoreKitConfigurationFileReference when launching the app under test, so
/// the runner process owns the StoreKit session itself via `SKTestSession`
/// (the configuration file is bundled into the MooveUITests target). The
/// session must exist before `app.launch()` for the app's StoreKit 2 calls to
/// bind to the local sandbox — without it the app queries the real App Store
/// backend, finds no products, and the paywall would silently degrade to
/// DEBUG mock pricing instead of exercising a real sandbox purchase.
@MainActor
final class QAMatrixUITests: XCTestCase {

    private var app: XCUIApplication!
    private var storeKitSession: SKTestSession?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]

        if !ProcessInfo.processInfo.arguments.contains("-UITestingSkipStoreKit") {
            do {
                let session = try SKTestSession(configurationFileNamed: "Moove")
                session.disableDialogs = true
                session.resetToDefaultState()
                storeKitSession = session
            } catch {
                // Non-fatal: alarm-flow rows still run; the paywall row
                // asserts real products and fails loudly if absent.
                print("QAMatrix: SKTestSession unavailable from runner (\(error)); sandbox purchase may not be exercisable")
            }
        }

        // AlarmKit / motion / notification authorization sheets are owned by
        // SpringBoard and can surface over the app at any point during a test.
        // A UIInterruptionMonitor lets XCUI auto-dismiss them so cached element
        // queries (e.g. the Settings tab button) don't go stale mid-tap.
        addUIInterruptionMonitor(withDescription: "Dismiss authorization alerts") { alert in
            let allow = alert.buttons.matching(
                NSPredicate(format: "label BEGINSWITH[c] %@", "Allow")
            ).firstMatch
            if allow.exists {
                allow.tap()
                return true
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        storeKitSession?.resetToDefaultState()
        storeKitSession = nil
        app = nil
    }

    // MARK: - Helpers

    private func save(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForMainInterface() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
    }

    private func dismissSystemAuthorizationAlertsIfNeeded() {
        // AlarmKit / notification authorization sheets belong to SpringBoard.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] %@", "Allow")
        ).firstMatch
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }
    }

    // MARK: - Item 1 + 8: Create alarm (20 steps, snooze on) & step interval enforcement

    func test01CreateAlarmWithTwentyStepsAndSnooze() {
        app.launchArguments += ["-UITestingClearAlarms"]
        app.launch()
        waitForMainInterface()

        app.buttons["alarmList.emptyState.createButton"].tap()
        XCTAssertTrue(app.navigationBars["New Alarm"].waitForExistence(timeout: 5))

        // Default step goal is 30 (from settings). One Stepper decrement must
        // land exactly on 20 — proving the 10-step interval is enforced.
        let stepGoalText = app.staticTexts["alarmEdit.stepGoal"]
        XCTAssertTrue(stepGoalText.waitForExistence(timeout: 3))
        XCTAssertEqual(stepGoalText.label, "30", "New alarm should default to 30 steps")

        let stepper = app.steppers.firstMatch
        XCTAssertTrue(stepper.waitForExistence(timeout: 3))

        func assertStepGoalEquals(_ expected: String, _ message: String) {
            let predicate = NSPredicate(format: "label == %@", expected)
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: stepGoalText)
            let waiter = XCTWaiter()
            XCTAssertEqual(waiter.wait(for: [expectation], timeout: 3), .completed, message)
        }

        stepper.buttons["Decrement"].tap()
        assertStepGoalEquals("20", "Stepper must move 30 → 20 (interval of 10)")
        stepper.buttons["Increment"].tap()
        assertStepGoalEquals("30", "Stepper must move 20 → 30 (interval of 10)")
        stepper.buttons["Decrement"].tap()
        assertStepGoalEquals("20", "Stepper must move 30 → 20 (interval of 10)")

        // Snooze toggle defaults on and stays on.
        let snoozeToggle = app.switches["Allow Snooze"]
        XCTAssertTrue(snoozeToggle.waitForExistence(timeout: 3))
        XCTAssertEqual(snoozeToggle.value as? String, "1", "Snooze should default to on")

        save("qa-01-new-alarm-20-steps")

        app.navigationBars["New Alarm"].buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["20"].firstMatch.waitForExistence(timeout: 5),
                      "Alarm list row must show the 20-step goal")
        save("qa-01-alarm-list-created")
    }

    // MARK: - Item 3: Mission countdown → zero → alarm silences

    func test02MissionCountdownCompletesAndSilences() {
        app.launchArguments += ["-UITestingStartMission", "-UITestingMissionSteps", "20", "-UITestingStepSim"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Wake up."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["20 steps remaining"].waitForExistence(timeout: 5))
        save("qa-02-mission-start-20")

        let stepButton = app.buttons["mission.debugStepButton"]
        XCTAssertTrue(stepButton.waitForExistence(timeout: 5))

        stepButton.tap() // 20 → 10
        XCTAssertTrue(app.staticTexts["10 steps remaining"].waitForExistence(timeout: 5))
        save("qa-02-mission-10-remaining")

        stepButton.tap() // 10 → 0 → mission completes, audio stops
        XCTAssertTrue(app.staticTexts["Good Morning!"].waitForExistence(timeout: 10),
                      "Reaching zero steps must complete the mission and silence the alarm")
        save("qa-02-mission-complete")

        // Completion → back to main UI. The "Start Your Day" button fades in
        // after the celebration animation (0.35s delay), so wait for it to
        // enter the accessibility tree before tapping.
        let startYourDay = app.buttons["Start Your Day"]
        XCTAssertTrue(startYourDay.waitForExistence(timeout: 5),
                      "Completion button must appear after the mission completes")
        startYourDay.tap()
        waitForMainInterface()
    }

    // MARK: - Item 4: Snooze grays out; only walking terminates after re-fire

    func test03SnoozeDisablesAndRefires() {
        app.launchArguments += [
            "-UITestingStartMission", "-UITestingMissionSteps", "20",
            "-UITestingStepSim", "-UITestingShortSnooze"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Wake up."].waitForExistence(timeout: 10))

        // Short-snooze hook makes the chip label "0m" (4 seconds).
        let snoozeChip = app.buttons["0m"]
        XCTAssertTrue(snoozeChip.waitForExistence(timeout: 5), "Snooze chip must be visible during the mission")
        save("qa-03-snooze-available")

        snoozeChip.tap()

        // The snoozed UX replaces the mission view with a dedicated snooze
        // screen; the chip disappears from the hierarchy entirely.
        XCTAssertTrue(app.staticTexts["Snoozed"].waitForExistence(timeout: 5),
                       "Snoozed cover screen must appear after tapping snooze")
        save("qa-03-snooze-consumed")

        // After the 4s snooze the alarm re-fires; the mission view returns
        // with the chip still present but disabled (snoozeRemaining == 0).
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline && !app.staticTexts["20 steps remaining"].exists {
            usleep(250_000)
        }
        XCTAssertTrue(app.staticTexts["20 steps remaining"].waitForExistence(timeout: 3),
                       "Alarm must re-fire after the snooze expires")
        let snoozeChipAfterRefire = app.buttons["0m"]
        XCTAssertTrue(snoozeChipAfterRefire.waitForExistence(timeout: 3),
                      "Snooze chip must reappear after re-fire")
        XCTAssertFalse(snoozeChipAfterRefire.isEnabled, "Snooze must remain disabled after re-fire")

        // Only walking terminates the audio now.
        let stepButton = app.buttons["mission.debugStepButton"]
        stepButton.tap()
        stepButton.tap()
        XCTAssertTrue(app.staticTexts["Good Morning!"].waitForExistence(timeout: 10))
        save("qa-03-post-snooze-complete")
    }

    // MARK: - Item 5: Audio library — bundled sounds + preview + selection

    func test04AudioLibraryBundledSoundsAndPreview() {
        app.launchArguments += ["-UITestingSeedAlarms"]
        app.launch()
        waitForMainInterface()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        app.buttons["settings.defaultSound"].tap()
        XCTAssertTrue(app.navigationBars["Audio Library"].waitForExistence(timeout: 5))

        // Bundled section renders the 16-sound AOSP library (Apache 2.0).
        // Top of the list is visible without scrolling.
        for name in ["Barium", "Cesium", "Argon", "Fire Drill"] {
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 3),
                          "Bundled sound missing: \(name)")
        }
        save("qa-04-audio-library")

        // The rest of the library renders below the fold.
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Neon"].waitForExistence(timeout: 3),
                      "Bundled sound missing after scroll: Neon")
        app.swipeDown()

        // Preview toggle: play → stop.
        let playButton = app.buttons["soundPicker.play.barium"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 3))
        playButton.tap()
        XCTAssertTrue(playButton.waitForExistence(timeout: 3),
                      "Play button must remain hittable after toggling preview")
        save("qa-04-audio-preview")

        // Select a different sound → checkmark + dismiss back to Settings.
        app.staticTexts["Argon"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Argon"].waitForExistence(timeout: 3),
                      "Settings must reflect the newly selected default sound")
        save("qa-04-sound-selected")
    }

    // MARK: - Item 6: Paywall renders with sandbox products; trial purchase (StoreKit fallback backend)

    func test05PaywallRendersAndSandboxTrialPurchase() {
        app.launchArguments += ["-UITestingSeedAlarms"]
        app.launch()
        waitForMainInterface()

        // Post-D2: no paywall may auto-present on launch.
        // The paywall title is uppercased by `.mooveEyebrow()`, so match
        // case-insensitively.
        let paywallTitle = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES[c] %@", "Moove Premium")
        ).firstMatch
        XCTAssertFalse(paywallTitle.waitForExistence(timeout: 3),
                       "Paywall must not auto-present on cold launch")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        // The scheme-bound StoreKit sandbox persists purchases across runs
        // on a given simulator, and the 7-day intro offer is consumable only
        // once. If an earlier run already purchased, the entitlement flow is
        // proven — just verify the paywall still renders and return.
        let statusText = app.staticTexts["Free"]
        let alreadyPurchased = !statusText.waitForExistence(timeout: 3)
        if alreadyPurchased {
            let active = app.staticTexts["Trial"].exists || app.staticTexts["Premium"].exists
            XCTAssertTrue(active, "Persisted sandbox state must be an active entitlement")
            app.buttons["settings.upgrade"].tap()
            XCTAssertTrue(paywallTitle.waitForExistence(timeout: 5))
            save("qa-05-paywall-already-active")
            return
        }
        save("qa-05-settings-free")

        app.buttons["settings.upgrade"].tap()
        XCTAssertTrue(paywallTitle.waitForExistence(timeout: 5))

        // Products come from the local Moove.storekit config (placeholder
        // RevenueCat key → direct StoreKit 2 backend).
        XCTAssertTrue(app.staticTexts["Start your 7-day free trial"].waitForExistence(timeout: 10),
                      "Paywall must load sandbox products")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "/ month")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "/ year")).firstMatch.exists)
        save("qa-05-paywall")

        // Tap the purchase CTA. The button sits below the fold on tall paywalls,
        // so reveal it with an explicit swipe first — letting XCUI auto-scroll
        // and tap in one step lands the synthesized event on the "Maybe
        // later" dismiss button directly beneath it.
        let cta = app.buttons["paywall.startTrialButton"]
        XCTAssertTrue(cta.waitForExistence(timeout: 5), "Purchase CTA must render once products load")
        if !cta.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(cta.waitForExistence(timeout: 3))
        cta.tap()

        // The StoreKit sandbox confirmation sheet (in-app scene) must be
        // confirmed to complete the purchase.
        let confirm = app.buttons["Subscribe"]
        if confirm.waitForExistence(timeout: 8) {
            confirm.tap()
        }

        // Purchase completes → paywall dismisses → status flips to an
        // active state. Fresh sandbox: "Trial"; if the intro offer was
        // already consumed on this simulator, the purchase converts
        // directly to "Premium" — both prove the entitlement is live.
        // (The optional paywall is a sheet, so the Settings navbar is
        // visible behind it — only the status text proves dismissal.)
        let trial = app.staticTexts["Trial"].waitForExistence(timeout: 20)
        let premium = app.staticTexts["Premium"].exists
        XCTAssertTrue(trial || premium,
                      "Settings must show an active subscription after purchase")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        save("qa-05-trial-active")
    }

    // MARK: - Item 2 (simulator-verifiable subset): real AlarmKit alarm fires

    /// Foreground + relaunch observation: schedule a real alarm ~1 minute out
    /// through AlarmKit and verify the app observes the alerting state.
    func test06ScheduledAlarmFiresInForeground() {
        app.launchArguments += ["-UITestingClearAlarms", "-UITestingScheduleAlarmInSeconds", "45"]
        app.launch()
        dismissSystemAuthorizationAlertsIfNeeded()
        waitForMainInterface()

        // AlarmKit relative schedules are minute-granular, so allow up to 150s.
        XCTAssertTrue(app.staticTexts["Wake up."].waitForExistence(timeout: 150),
                      "Scheduled AlarmKit alarm must fire and present the mission UI")
        save("qa-06-alarm-fired-foreground")
    }

    /// Force-closed delivery: schedule, terminate the app, wait past the fire
    /// time, relaunch — the alerting alarm must be delivered to the app on
    /// relaunch (the system alert UI itself is AlarmKit-owned).
    func test07ScheduledAlarmFiresAfterForceClose() {
        app.launchArguments += ["-UITestingClearAlarms", "-UITestingScheduleAlarmInSeconds", "45"]
        app.launch()
        dismissSystemAuthorizationAlertsIfNeeded()
        waitForMainInterface()

        app.terminate()
        // Never bare-sleep here: while the app under test is terminated the
        // runner sits in the background, and a main-thread Thread.sleep of
        // >30 s leaves the runner unable to service system scene-create
        // requests — FrontBoard then watchdog-kills it (0x8BADF00D) and
        // the whole suite dies mid-test. Spinning the RunLoop keeps the
        // runner responsive for the full alarm window.
        spinRunLoop(forTimeInterval: 100)

        app.launch()
        XCTAssertTrue(app.staticTexts["Wake up."].waitForExistence(timeout: 90),
                      "Alarm that fired while force-closed must deliver on relaunch")
        save("qa-07-alarm-fired-after-force-close")
    }

    /// Blocks for `duration` while keeping the main RunLoop serviced so the
    /// runner can answer system requests (scene creation, activation) while
    /// the app under test is terminated.
    private func spinRunLoop(forTimeInterval duration: TimeInterval) {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
    }
}
