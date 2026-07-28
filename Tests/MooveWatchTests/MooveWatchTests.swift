import XCTest
@testable import MooveWatch

final class WatchModelTests: XCTestCase {
    func testMissionPhaseSendable() {
        let phases: [MissionPhase] = [.waitingToStart, .completed, .failed]
        for phase in phases {
            let data = try! JSONEncoder().encode(phase)
            let decoded = try! JSONDecoder().decode(MissionPhase.self, from: data)
            XCTAssertEqual(phase, decoded)
        }
    }

    func testSubscriptionTierRawValues() {
        XCTAssertEqual(SubscriptionTier.free.rawValue, "free")
        XCTAssertEqual(SubscriptionTier.premium.rawValue, "premium")
    }

    func testAlarmConfigDefaults() {
        let config = AlarmConfig()
        XCTAssertEqual(config.stepGoal, 30)
        XCTAssertEqual(config.snoozeRemaining, 1)
        XCTAssertEqual(config.soundName, "default")
        XCTAssertTrue(config.isEnabled)
    }

    func testAlarmConfigStepGoalClamping() {
        let config = AlarmConfig(stepGoal: 7)
        XCTAssertEqual(config.stepGoal, 10)
        let config2 = AlarmConfig(stepGoal: 150)
        XCTAssertEqual(config2.stepGoal, 100)
        let config3 = AlarmConfig(stepGoal: 30)
        XCTAssertEqual(config3.stepGoal, 30)
    }

    func testAlarmConfigTimeString() {
        let config = AlarmConfig(hour: 7, minute: 30)
        XCTAssertTrue(config.timeString.contains("7:30"))
    }

    func testAlarmConfigWeekdaySummary() {
        let once = AlarmConfig(weekdays: [])
        XCTAssertEqual(once.weekdaySummary, "Once")
        let weekdays = AlarmConfig(weekdays: [1, 2, 3, 4, 5])
        XCTAssertEqual(weekdays.weekdaySummary, "Weekdays")
        let weekends = AlarmConfig(weekdays: [6, 7])
        XCTAssertEqual(weekends.weekdaySummary, "Weekends")
        let everyday = AlarmConfig(weekdays: [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(everyday.weekdaySummary, "Every day")
    }

    func testAppSettingsDefaults() {
        let settings = AppSettings.default
        XCTAssertEqual(settings.defaultStepGoal, 30)
        XCTAssertTrue(settings.liveActivitiesEnabled)
        XCTAssertEqual(settings.snoozeLimit, 1)
    }

    func testAppSettingsSnoozeDuration() {
        var settings = AppSettings.default
        settings.snoozeDurationIndex = 0
        XCTAssertEqual(settings.snoozeDuration, 300)
    }

    func testConstantsValues() {
        XCTAssertEqual(Constants.StepTracking.minimumSteps, 10)
        XCTAssertEqual(Constants.StepTracking.maximumSteps, 100)
        XCTAssertEqual(Constants.StepTracking.stepInterval, 10)
        XCTAssertEqual(Constants.subscriptionProductID, "com.moove.alarmclock.premium")
        XCTAssertEqual(Constants.appGroupIdentifier, "group.com.moove.alarmclock")
    }

    func testNotificationNames() {
        XCTAssertEqual(Notification.Name.alarmDidFire.rawValue, "com.moove.alarmDidFire")
        XCTAssertEqual(Notification.Name.alarmMissionCompleted.rawValue, "com.moove.alarmMissionCompleted")
        XCTAssertEqual(Notification.Name.stepCountUpdated.rawValue, "com.moove.stepCountUpdated")
    }
}

@MainActor
final class WatchStepCounterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        WatchStepCounter.shared.stopMission()
    }

    override func tearDown() {
        WatchStepCounter.shared.stopMission()
        super.tearDown()
    }

    func testInitialState() {
        let counter = WatchStepCounter.shared
        XCTAssertFalse(counter.isMissionActive)
        XCTAssertEqual(counter.currentSteps, 0)
        XCTAssertEqual(counter.targetSteps, 30)
    }

    func testStartMissionActivatesCounting() {
        let counter = WatchStepCounter.shared
        counter.startMission(stepsRequired: 50)
        XCTAssertTrue(counter.isMissionActive)
        XCTAssertEqual(counter.targetSteps, 50)
        XCTAssertEqual(counter.currentSteps, 0)
    }

    func testStopMissionResetsState() {
        let counter = WatchStepCounter.shared
        counter.startMission(stepsRequired: 30)
        XCTAssertTrue(counter.isMissionActive)
        counter.stopMission()
        XCTAssertFalse(counter.isMissionActive)
    }

    func testMissionCompletesAtTarget() {
        let counter = WatchStepCounter.shared
        counter.startMission(stepsRequired: 10)
        counter.currentSteps = 10
        counter.stopMission()
        XCTAssertFalse(counter.isMissionActive)
    }

    func testStepCountingStopsOnCompletion() {
        let counter = WatchStepCounter.shared
        counter.startMission(stepsRequired: 5)
        counter.currentSteps = 5
        counter.stopMission()
        XCTAssertFalse(counter.isMissionActive)
    }

    func testMultipleStartStopCycles() {
        let counter = WatchStepCounter.shared
        counter.startMission(stepsRequired: 20)
        XCTAssertTrue(counter.isMissionActive)
        counter.stopMission()
        XCTAssertFalse(counter.isMissionActive)
        counter.startMission(stepsRequired: 10)
        XCTAssertTrue(counter.isMissionActive)
        XCTAssertEqual(counter.targetSteps, 10)
        XCTAssertEqual(counter.currentSteps, 0)
        counter.stopMission()
    }
}

@MainActor
final class WorkoutSessionManagerTests: XCTestCase {
    func testInitialState() {
        let manager = WorkoutSessionManager.shared
        XCTAssertFalse(manager.isSessionActive)
    }
}

@MainActor
final class WatchSessionManagerTests: XCTestCase {
    func testSingletonShared() {
        let instance = WatchSessionManager.shared
        XCTAssertFalse(instance.isReachable)
    }
}

final class AlarmConfigCodableTests: XCTestCase {
    func testAlarmConfigRoundTrip() {
        let original = AlarmConfig(
            label: "Test Alarm",
            hour: 6,
            minute: 30,
            weekdays: [1, 2, 3, 4, 5],
            stepGoal: 40,
            soundName: "gentle_wake"
        )
        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(AlarmConfig.self, from: data)
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.label, decoded.label)
        XCTAssertEqual(original.hour, decoded.hour)
        XCTAssertEqual(original.minute, decoded.minute)
        XCTAssertEqual(original.weekdays, decoded.weekdays)
        XCTAssertEqual(original.stepGoal, decoded.stepGoal)
        XCTAssertEqual(original.soundName, decoded.soundName)
    }

    func testAlarmConfigCodableWithEmptyWeekdays() {
        let config = AlarmConfig(weekdays: [])
        let data = try! JSONEncoder().encode(config)
        let decoded = try! JSONDecoder().decode(AlarmConfig.self, from: data)
        XCTAssertEqual(decoded.weekdays, [])
    }

    func testAlarmConfigCodableFullWeek() {
        let config = AlarmConfig(weekdays: [1, 2, 3, 4, 5, 6, 7])
        let data = try! JSONEncoder().encode(config)
        let decoded = try! JSONDecoder().decode(AlarmConfig.self, from: data)
        XCTAssertEqual(decoded.weekdays.count, 7)
    }
}

final class AppStateModelTests: XCTestCase {
    func testMissionPhaseEquatable() {
        XCTAssertEqual(MissionPhase.waitingToStart, MissionPhase.waitingToStart)
        XCTAssertNotEqual(MissionPhase.waitingToStart, MissionPhase.completed)
    }

    func testSubscriptionTierEquatable() {
        XCTAssertEqual(SubscriptionTier.free, SubscriptionTier.free)
        XCTAssertNotEqual(SubscriptionTier.free, SubscriptionTier.premium)
    }

    func testAlarmStateEnum() {
        XCTAssertNotEqual(AlarmState.idle, AlarmState.firing)
        XCTAssertNotEqual(AlarmState.missionActive, AlarmState.stopped)
    }
}
