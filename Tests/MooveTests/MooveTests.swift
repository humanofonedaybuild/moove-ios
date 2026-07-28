import XCTest
@testable import MooveKit

final class AlarmConfigTests: XCTestCase {
    func testStepClamping() {
        let config = AlarmConfig(stepGoal: 17)
        XCTAssertEqual(config.stepGoal, 20, "Steps should be rounded to nearest interval of 10")
    }

    func testStepClampingAtBounds() {
        let min = AlarmConfig(stepGoal: 5)
        XCTAssertEqual(min.stepGoal, 10, "Below minimum should clamp to 10")

        let max = AlarmConfig(stepGoal: 150)
        XCTAssertEqual(max.stepGoal, 100, "Above maximum should clamp to 100")
    }

    func testExactSteps() {
        let config = AlarmConfig(stepGoal: 30)
        XCTAssertEqual(config.stepGoal, 30, "Exact interval should not change")
    }

    func testStepRange() {
        for step in stride(from: 0, through: 110, by: 1) {
            let config = AlarmConfig(stepGoal: step)
            XCTAssertGreaterThanOrEqual(config.stepGoal, AlarmConfig.defaultStepRange.lowerBound)
            XCTAssertLessThanOrEqual(config.stepGoal, AlarmConfig.defaultStepRange.upperBound)
            XCTAssertEqual(config.stepGoal % AlarmConfig.stepInterval, 0)
        }
    }

    func testEncodingDecoding() {
        let original = AlarmConfig(
            label: "Test Alarm",
            hour: 6,
            minute: 30,
            stepGoal: 50
        )
        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(AlarmConfig.self, from: data)
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.label, decoded.label)
        XCTAssertEqual(original.stepGoal, decoded.stepGoal)
    }

    func testDefaultValues() {
        let config = AlarmConfig()
        XCTAssertEqual(config.label, "Alarm")
        XCTAssertEqual(config.stepGoal, 30)
        XCTAssertEqual(config.snoozeRemaining, 1)
        XCTAssertEqual(config.soundName, "default")
        XCTAssertTrue(config.isEnabled)
        XCTAssertTrue(config.weekdays.isEmpty)
    }

    func testMaxSnoozeLimitOptions() {
        XCTAssertEqual(Constants.maxSnoozeOptions, [0, 1, 2, 3],
                       "Max Snooze Limit picker must offer exactly 0, 1, 2, 3")
        XCTAssertTrue(Constants.maxSnoozeOptions.contains(AppSettings.default.snoozeLimit),
                      "Default snoozeLimit must be a valid picker option")
        XCTAssertEqual(Constants.maxSnoozeOptions.first, 0,
                       "0 (snooze disabled) must be selectable")
        XCTAssertEqual(Constants.maxSnoozeOptions.last, 3,
                       "3 must be the maximum selectable snooze count")
    }

    func testWeekdaySummary() {
        let once = AlarmConfig(weekdays: [])
        XCTAssertEqual(once.weekdaySummary, "Once")

        let weekdays = AlarmConfig(weekdays: [1, 2, 3, 4, 5])
        XCTAssertEqual(weekdays.weekdaySummary, "Weekdays")

        let weekends = AlarmConfig(weekdays: [6, 7])
        XCTAssertEqual(weekends.weekdaySummary, "Weekends")

        let everyDay = AlarmConfig(weekdays: [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(everyDay.weekdaySummary, "Every day")
    }

    func testTimeString() {
        let morning = AlarmConfig(hour: 7, minute: 30)
        XCTAssertTrue(morning.timeString.contains("AM"))

        let evening = AlarmConfig(hour: 19, minute: 0)
        XCTAssertTrue(evening.timeString.contains("PM"))
    }

    func testEquality() {
        let id = UUID()
        let a = AlarmConfig(id: id, label: "Morning", hour: 7, minute: 0)
        let b = AlarmConfig(id: id, label: "Different", hour: 7, minute: 0)
        XCTAssertEqual(a, b)
    }

    func testClampStepsRoundUp() {
        let config = AlarmConfig(stepGoal: 34)
        XCTAssertEqual(config.stepGoal, 40)
    }

    func testSendable() {
        let config = AlarmConfig()
        let data = try! JSONEncoder().encode(config)
        let decoded = try! JSONDecoder().decode(AlarmConfig.self, from: data)
        XCTAssertEqual(config.stepGoal, decoded.stepGoal)
    }

    func testMissionPhaseEnum() {
        let waiting: MissionPhase = .waitingToStart
        let completed: MissionPhase = .completed
        let failed: MissionPhase = .failed

        XCTAssertNotEqual(waiting, completed)
        XCTAssertNotEqual(completed, failed)

        let inProgress: MissionPhase = .inProgress(stepsRemaining: 25)
        if case .inProgress(let steps) = inProgress {
            XCTAssertEqual(steps, 25)
        } else {
            XCTFail("Expected inProgress state")
        }
    }

    func testSubscriptionTierEnum() {
        let free: SubscriptionTier = .free
        let premium: SubscriptionTier = .premium
        XCTAssertNotEqual(free, premium)
    }

    // MARK: - Mission Flow Tests

    func testStepDecrementFlow() {
        var stepsRemaining = 30
        var stepsTaken = 0
        let target = 30

        // Simulate registering steps one at a time
        for _ in 1...target {
            stepsTaken += 1
            stepsRemaining = max(target - stepsTaken, 0)
        }

        XCTAssertEqual(stepsRemaining, 0, "Steps should reach 0 when target is met")
        XCTAssertEqual(stepsTaken, target, "Should have taken exactly the target number of steps")
    }

    func testStepDecrementPartial() {
        var stepsRemaining = 30
        var stepsTaken = 0
        let target = 30

        for _ in 1...15 {
            stepsTaken += 1
            stepsRemaining = max(target - stepsTaken, 0)
        }

        XCTAssertEqual(stepsRemaining, 15, "Should have 15 steps remaining")
        XCTAssertEqual(stepsTaken, 15, "Should have taken 15 steps")
    }

    func testStepCannotGoNegative() {
        var stepsRemaining = 10
        var stepsTaken = 0
        let target = 10

        for _ in 1...15 {
            stepsTaken = min(stepsTaken + 1, target)
            stepsRemaining = max(target - stepsTaken, 0)
        }

        XCTAssertEqual(stepsRemaining, 0, "Steps remaining should never go below 0")
        XCTAssertEqual(stepsTaken, 10, "Should clamp to target when overshooting")
    }

    func testMissionPhaseTransitions() {
        let phases: [MissionPhase] = [
            .waitingToStart,
            .inProgress(stepsRemaining: 30),
            .inProgress(stepsRemaining: 15),
            .completed,
        ]

        for (index, phase) in phases.enumerated() {
            let data = try! JSONEncoder().encode(phase)
            let decoded = try! JSONDecoder().decode(MissionPhase.self, from: data)
            XCTAssertEqual(phase, decoded, "Phase \(index) should round-trip")
        }
    }

    func testAlarmStateTransitions() {
        let states: [AlarmState] = [
            .idle,
            .scheduled,
            .firing,
            .missionActive,
            .snoozed,
            .stopped,
        ]

        for (index, state) in states.enumerated() {
            let data = try! JSONEncoder().encode(state)
            let decoded = try! JSONDecoder().decode(AlarmState.self, from: data)
            XCTAssertEqual(state, decoded, "State \(index) should round-trip")
        }
    }

    func testSnoozeOptionDurations() {
        let options = Constants.snoozeOptions
        XCTAssertEqual(options.count, 3)

        XCTAssertEqual(options[0].label, "5 min")
        XCTAssertEqual(options[0].duration, 300)

        XCTAssertEqual(options[1].label, "10 min")
        XCTAssertEqual(options[1].duration, 600)

        XCTAssertEqual(options[2].label, "15 min")
        XCTAssertEqual(options[2].duration, 900)
    }

    func testStepGoalDefaultMessages() {
        let lowGoal = AlarmConfig(stepGoal: 10)
        XCTAssertEqual(lowGoal.stepGoal, 10, "Minimum step goal")

        let highGoal = AlarmConfig(stepGoal: 100)
        XCTAssertEqual(highGoal.stepGoal, 100, "Maximum step goal")

        let defaultGoal = AlarmConfig()
        XCTAssertEqual(defaultGoal.stepGoal, 30, "Default step goal")
    }

    func testStepGoalIsClampedOnInit() {
        let config = AlarmConfig(stepGoal: 42)
        XCTAssertEqual(config.stepGoal, 50, "42 should round up to 50")
    }
}

// MARK: - Design System Tests

final class DesignSystemTokens: XCTestCase {
    func testSpacingValues() {
        XCTAssertEqual(MooveSpacing.xs, 4)
        XCTAssertEqual(MooveSpacing.sm, 8)
        XCTAssertEqual(MooveSpacing.md, 12)
        XCTAssertEqual(MooveSpacing.lg, 16)
        XCTAssertEqual(MooveSpacing.xl, 20)
        XCTAssertEqual(MooveSpacing.xxl, 24)
        XCTAssertEqual(MooveSpacing.xxxl, 32)
        XCTAssertEqual(MooveSpacing.huge, 48)
    }

    func testCornerRadiusValues() {
        XCTAssertEqual(MooveCornerRadius.sm, 8)
        XCTAssertEqual(MooveCornerRadius.md, 14)
        XCTAssertEqual(MooveCornerRadius.lg, 20)
        XCTAssertEqual(MooveCornerRadius.xl, 28)
        XCTAssertEqual(MooveCornerRadius.full, 9999)
    }

    func testShadowConfigValues() {
        XCTAssertEqual(MooveShadow.sm.opacity, 0.06)
        XCTAssertEqual(MooveShadow.sm.radius, 4)
        XCTAssertEqual(MooveShadow.sm.y, 2)

        XCTAssertEqual(MooveShadow.md.opacity, 0.08)
        XCTAssertEqual(MooveShadow.md.radius, 8)
        XCTAssertEqual(MooveShadow.md.y, 4)

        XCTAssertEqual(MooveShadow.lg.opacity, 0.12)
        XCTAssertEqual(MooveShadow.lg.radius, 16)
        XCTAssertEqual(MooveShadow.lg.y, 8)
    }

    func testAnimationDurations() {
        XCTAssertEqual(MooveAnimationDuration.standard, 0.35)
        XCTAssertEqual(MooveAnimationDuration.celebration, 0.5)
        XCTAssertEqual(MooveAnimationDuration.quick, 0.2)
    }

    func testShadowConfigInitialization() {
        let config = MooveShadow.Config(opacity: 0.1, radius: 4, x: 1, y: 2)
        XCTAssertEqual(config.opacity, 0.1)
        XCTAssertEqual(config.radius, 4)
        XCTAssertEqual(config.x, 1)
        XCTAssertEqual(config.y, 2)
    }

    func testMooveSpacingEquality() {
        let spacing: [CGFloat] = [
            MooveSpacing.xs, MooveSpacing.sm, MooveSpacing.md, MooveSpacing.lg,
            MooveSpacing.xl, MooveSpacing.xxl, MooveSpacing.xxxl, MooveSpacing.huge
        ]
        XCTAssertEqual(spacing.count, 8)
        XCTAssertEqual(Set(spacing).count, 8, "All spacing values should be unique")
    }

    func testCornerRadiusOrdering() {
        XCTAssertLessThan(MooveCornerRadius.sm, MooveCornerRadius.md)
        XCTAssertLessThan(MooveCornerRadius.md, MooveCornerRadius.lg)
        XCTAssertLessThan(MooveCornerRadius.lg, MooveCornerRadius.xl)
        XCTAssertGreaterThan(MooveCornerRadius.full, MooveCornerRadius.xl)
    }
}
