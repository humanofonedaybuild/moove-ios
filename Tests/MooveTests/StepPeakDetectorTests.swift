import XCTest
@testable import MooveKit
@testable import Moove

/// Unit tests for the accelerometer peak/shake detector that backs the
/// step counter (MOO-175 bug #2 — the counter previously required an
/// unnatural, violent arm swing to move).
///
/// Signals are synthesized at the production sample interval
/// (`Constants.StepTracking.pedometerUpdateInterval` = 50 ms) and fed to
/// the detector in real time, mirroring how `CMMotionManager` delivers
/// accelerometer samples on device. Expected counts are derived from the
/// documented detector contract:
///
/// - a walking-peak above `stepPeakThreshold` (1.4 g) counts,
/// - a magnitude above `shakeAccelerationThreshold` (2.0 g) counts,
/// - the first detected event only counts once a second event arrives
///   within `confirmationWindow` (anti-jiggle; a single tap or bump can
///   never start or advance the mission).
final class StepPeakDetectorTests: XCTestCase {

    private let sampleInterval = Constants.StepTracking.pedometerUpdateInterval

    private func makeDetector() -> StepPeakDetector {
        StepPeakDetector()
    }

    /// Feeds `peakCount` triangular bumps of apex `peakMagnitude`, one per
    /// `cadence` seconds, with a 1 g baseline between bumps. Each bump is
    /// shaped like a real in-hand arm swing: rise → apex → fall.
    @discardableResult
    private func feedBumps(
        _ detector: StepPeakDetector,
        peakCount: Int,
        peakMagnitude: Double,
        cadence: TimeInterval,
        startTime: Date = Date()
    ) -> Int {
        let start = startTime
        var t: TimeInterval = 0
        var counted = 0
        let samplesPerCycle = Int(cadence / sampleInterval)
        // 5-sample bump: [1.1, mid, apex, mid, 1.1]
        let rise = (peakMagnitude - 1.0) / 2
        let bumpShape: [Double] = [1.1, peakMagnitude - rise, peakMagnitude, peakMagnitude - rise, 1.1]

        for _ in 0..<peakCount {
            for i in 0..<samplesPerCycle {
                let magnitude = i < bumpShape.count ? bumpShape[i] : 1.0
                counted += detector.process(magnitude: magnitude, at: start.addingTimeInterval(t))
                t += sampleInterval
            }
        }
        return counted
    }

    /// Feeds `spikeCount` single-sample high-g spikes (deliberate shakes)
    /// with a 1 g baseline, one spike per `cadence` seconds.
    @discardableResult
    private func feedShakes(
        _ detector: StepPeakDetector,
        spikeCount: Int,
        spikeMagnitude: Double,
        cadence: TimeInterval,
        startTime: Date = Date()
    ) -> Int {
        let start = startTime
        var t: TimeInterval = 0
        var counted = 0
        let samplesPerCycle = Int(cadence / sampleInterval)

        for _ in 0..<spikeCount {
            for i in 0..<samplesPerCycle {
                // Spike lands on the 2nd sample of each cycle so the
                // detector's 3-sample window always sees it.
                let magnitude = (i == 1) ? spikeMagnitude : 1.0
                counted += detector.process(magnitude: magnitude, at: start.addingTimeInterval(t))
                t += sampleInterval
            }
        }
        return counted
    }

    // MARK: - Natural walking (bug #2: ordinary arm swing must count)

    func testNaturalArmSwingCountsSteps() {
        let detector = makeDetector()
        // 20 bumps at ~1.8 g apex, one per 0.5 s — a natural in-hand
        // walking cadence. The first event is swallowed by the anti-jiggle
        // confirmation; every subsequent peak counts.
        let counted = feedBumps(detector, peakCount: 20, peakMagnitude: 1.8, cadence: 0.5)
        XCTAssertEqual(counted, 19, "A natural arm swing should register nearly every peak")
    }

    func testSubThresholdSwingDoesNotCount() {
        let detector = makeDetector()
        // 1.2 g bumps stay below the 1.4 g walking-peak threshold: idle
        // fidgeting and light taps must never advance the mission.
        let counted = feedBumps(detector, peakCount: 20, peakMagnitude: 1.2, cadence: 0.5)
        XCTAssertEqual(counted, 0)
    }

    // MARK: - Deliberate shake (product spec: shake counts as movement)

    func testDeliberateShakeCountsSteps() {
        let detector = makeDetector()
        // A 2.5 g shake — firm but ordinary — at a deliberate cadence.
        let counted = feedShakes(detector, spikeCount: 10, spikeMagnitude: 2.5, cadence: 0.6)
        XCTAssertEqual(counted, 9, "Deliberate shakes should register nearly every spike")
    }

    func testShakeAndSwingProduceEquivalentResults() {
        // Review bar: shake-detection must produce equivalent results to
        // swing-detection for the same number of events at the same cadence.
        let walkDetector = makeDetector()
        let shakeDetector = makeDetector()
        let walkCount = feedBumps(walkDetector, peakCount: 12, peakMagnitude: 1.8, cadence: 0.5)
        let shakeCount = feedShakes(shakeDetector, spikeCount: 12, spikeMagnitude: 2.5, cadence: 0.5)
        XCTAssertEqual(walkCount, shakeCount, "Walking and shaking must count identically")
        XCTAssertEqual(walkCount, 11)
    }

    // MARK: - Anti-jiggle (a single bump can never advance the mission)

    func testSingleBumpNeverCounts() {
        let detector = makeDetector()
        let counted = feedBumps(detector, peakCount: 1, peakMagnitude: 1.8, cadence: 0.5)
        XCTAssertEqual(counted, 0, "A single tap/bump must not count as a step")

        // Even a violent single shake is ignored.
        let shakeDetector = makeDetector()
        let shakeCounted = feedShakes(shakeDetector, spikeCount: 1, spikeMagnitude: 3.0, cadence: 0.5)
        XCTAssertEqual(shakeCounted, 0)
    }

    func testSecondEventWithinConfirmationWindowConfirmsFirst() {
        let detector = makeDetector()
        let start = Date()
        var counted = 0
        var t: TimeInterval = 0

        // First bump at t=0 → pending, not counted.
        for m in [1.1, 1.5, 1.8, 1.5, 1.1] {
            counted += detector.process(magnitude: m, at: start.addingTimeInterval(t))
            t += sampleInterval
        }
        XCTAssertEqual(counted, 0)

        // Second bump 1 s later (inside the 3 s window) → confirms and counts.
        t = 1.0
        for m in [1.1, 1.5, 1.8, 1.5, 1.1] {
            counted += detector.process(magnitude: m, at: start.addingTimeInterval(t))
            t += sampleInterval
        }
        XCTAssertEqual(counted, 1)
    }

    func testLoneEventOutsideConfirmationWindowStaysPending() {
        let detector = makeDetector()
        let start = Date()
        var counted = 0

        // Bump at t=0, then a 10 s idle gap, then one more bump: the first
        // event expired out of the window, so the second only re-arms the
        // confirmation — nothing counts until a third event arrives.
        for m in [1.1, 1.5, 1.8, 1.5, 1.1] {
            counted += detector.process(magnitude: m, at: start.addingTimeInterval(0))
        }
        for m in [1.1, 1.5, 1.8, 1.5, 1.1] {
            counted += detector.process(magnitude: m, at: start.addingTimeInterval(10))
        }
        XCTAssertEqual(counted, 0, "Two isolated bumps must not count as walking")
    }

    // MARK: - Cadence guard

    func testPeaksCloserThanMinDistanceAreDropped() {
        let detector = makeDetector()
        let start = Date()
        var counted = 0
        var t: TimeInterval = 0

        // 12 bumps only 0.25 s apart (4 steps/s). The first arms the
        // detector and min-peak-distance suppresses the burst; sustained
        // bursts still count at most one step per `stepMinPeakDistance`.
        for _ in 0..<12 {
            for m in [1.1, 1.5, 1.8, 1.5, 1.1] {
                counted += detector.process(magnitude: m, at: start.addingTimeInterval(t))
                t += sampleInterval
            }
        }
        let burstDuration = t
        XCTAssertLessThanOrEqual(
            Double(counted),
            burstDuration / Constants.StepTracking.stepMinPeakDistance + 1,
            "Rapid bursts must be throttled to a natural cadence"
        )
        XCTAssertGreaterThanOrEqual(counted, 1, "A sustained burst is still real movement")
    }
}

/// Exercises the fused counting math in `StepCounter` using the debug
/// step-simulation path (the same path the detector drives on device).
/// Verifies pedometer/shake events decrement the remaining-step goal
/// correctly, cap at the target, and complete the mission exactly once.
@MainActor
final class StepCounterMissionTests: XCTestCase {

    func testSimulatedStepsDecrementGoalWithoutCompleting() {
        let counter = StepCounter.shared
        counter.beginCounting(downFrom: 30)

        counter.debugSimulateSteps(10)
        XCTAssertEqual(counter.currentStepCount, 10)
        XCTAssertEqual(counter.stepProgress, 10.0 / 30.0, accuracy: 0.0001)
        XCTAssertTrue(counter.isCounting)

        counter.debugSimulateSteps(5)
        XCTAssertEqual(counter.currentStepCount, 15)
        XCTAssertEqual(counter.stepProgress, 15.0 / 30.0, accuracy: 0.0001)

        counter.stopCounting()
    }

    func testSimulatedStepsCapAtTargetAndCompleteMission() {
        let counter = StepCounter.shared
        counter.beginCounting(downFrom: 20)

        // Overshoot in a single update burst: the count caps at the goal
        // and the mission completes exactly once.
        counter.debugSimulateSteps(25)
        XCTAssertEqual(counter.currentStepCount, 20)
        XCTAssertFalse(counter.isCounting)
        XCTAssertEqual(counter.stepProgress, 1.0, accuracy: 0.0001)

        // Further movement after completion is ignored.
        counter.debugSimulateSteps(5)
        XCTAssertEqual(counter.currentStepCount, 20)

        counter.stopCounting()
    }

    func testPauseFreezesCountAndResumeRestartsSensors() {
        let counter = StepCounter.shared
        counter.beginCounting(downFrom: 20)
        counter.debugSimulateSteps(5)
        XCTAssertTrue(counter.isCounting)

        counter.pauseCounting()
        XCTAssertTrue(counter.isPaused)
        // Movement while paused must not advance the count.
        counter.debugSimulateSteps(5)
        XCTAssertEqual(counter.currentStepCount, 5)

        counter.resumeCounting()
        XCTAssertFalse(counter.isPaused)
        XCTAssertTrue(counter.isCounting)
        counter.debugSimulateSteps(5)
        XCTAssertEqual(counter.currentStepCount, 10)

        counter.stopCounting()
    }
}