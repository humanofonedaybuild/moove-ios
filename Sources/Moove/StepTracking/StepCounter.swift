import Foundation
import CoreMotion
import Observation
import UIKit
import MooveKit

/// Counts wake-up mission steps from two fused sources:
///
/// 1. `CMPedometer` event updates — the device coprocessor's own step
///    detection. This is the source of truth for real walking; every
///    pedometer step counts immediately.
/// 2. Accelerometer peak detection — catches deliberate phone-shakes and
///    in-hand arm swings that the pedometer may under-count when the phone
///    is held still-ish in the hand. Runs entirely on a background queue;
///    only confirmed step deltas are dispatched to the main actor so the
///    UI/render path never touches 20 Hz sensor data.
@Observable
@MainActor
final class StepCounter: NSObject {
    static let shared = StepCounter()

    var currentStepCount: Int = 0
    var targetStepCount: Int = 30
    var isCounting: Bool = false
    var isPaused: Bool = false
    var stepProgress: Double = 0.0

    private let pedometer = CMPedometer()
    private let motionManager = CMMotionManager()

    /// Serial background queue for accelerometer peak detection. Sensor
    /// samples must never be processed on the main thread (crash-fix:
    /// previous builds created a `Task` per 50 ms sample on the main
    /// actor, hammering the run loop during missions).
    private let detectionQueue = OperationQueue()

    private var lastActivityUpdateTime: Date = .distantPast

    /// Pedometer steps observed since mission start (cumulative).
    private var pedometerSteps: Int = 0
    /// Accelerometer-detected steps since mission start (cumulative).
    private var shakeSteps: Int = 0

    private var isMissionCompleting = false
    private var pauseTime: Date?

    private let stepHaptic = UIImpactFeedbackGenerator(style: .light)
    private let completionHaptic = UIImpactFeedbackGenerator(style: .soft)

    private override init() {
        detectionQueue.maxConcurrentOperationCount = 1
        detectionQueue.qualityOfService = .userInteractive
        super.init()
    }

    func beginCounting(downFrom target: Int) {
        targetStepCount = max(target, Constants.StepTracking.minimumSteps)
        pedometerSteps = 0
        shakeSteps = 0
        currentStepCount = 0
        stepProgress = 0.0
        isCounting = true
        isPaused = false
        isMissionCompleting = false
        pauseTime = nil
        lastActivityUpdateTime = .distantPast
        detector = StepPeakDetector()

        stepHaptic.prepare()
        startPedometerUpdates()
        startAccelerometerStepDetection()
    }

    func requestAuthorization() {
    }

    func stopCounting() {
        isCounting = false
        isPaused = false
        pauseTime = nil
        stopSensors()
    }

    func pauseCounting() {
        guard isCounting, !isPaused else { return }
        isPaused = true
        pauseTime = Date()
        stopSensors()
    }

    func resumeCounting() {
        guard isCounting, isPaused else { return }
        isPaused = false
        pauseTime = nil
        detector = StepPeakDetector()
        startPedometerUpdates()
        startAccelerometerStepDetection()
    }

    private func stopSensors() {
        pedometer.stopEventUpdates()
        pedometer.stopUpdates()
        motionManager.stopAccelerometerUpdates()
        detectionQueue.cancelAllOperations()
    }

    // MARK: - Pedometer (real steps — authoritative)

    private func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }

        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let data, error == nil else { return }
            let steps = data.numberOfSteps.intValue
            Task { @MainActor in
                self?.handlePedometerUpdate(steps)
            }
        }
    }

    private func handlePedometerUpdate(_ steps: Int) {
        guard isCounting, !isPaused else { return }
        let delta = steps - pedometerSteps
        guard delta > 0 else {
            pedometerSteps = max(pedometerSteps, steps)
            return
        }
        pedometerSteps = steps
        applyCombinedCount()
    }

    // MARK: - Accelerometer (shakes + in-hand swings)

    /// Detector state is confined to `detectionQueue` via the lock inside
    /// `StepPeakDetector`, so mutation from the sensor callback is safe.
    private var detector = StepPeakDetector()

    private func startAccelerometerStepDetection() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = Constants.StepTracking.pedometerUpdateInterval

        motionManager.startAccelerometerUpdates(to: detectionQueue) { [weak self] data, error in
            guard let data, error == nil else { return }
            let acceleration = data.acceleration
            let magnitude = sqrt(
                acceleration.x * acceleration.x +
                acceleration.y * acceleration.y +
                acceleration.z * acceleration.z
            )
            guard let detected = self?.detector.process(magnitude: magnitude, at: Date()),
                  detected > 0 else { return }
            Task { @MainActor in
                self?.handleDetectedAccelerometerSteps(detected)
            }
        }
    }

    private func handleDetectedAccelerometerSteps(_ count: Int) {
        guard isCounting, !isPaused else { return }
        shakeSteps += count
        stepHaptic.impactOccurred()
        stepHaptic.prepare()
        applyCombinedCount()
    }

    #if DEBUG
    func debugSimulateSteps(_ count: Int) {
        guard isCounting, !isPaused else { return }
        shakeSteps += count
        applyCombinedCount()
    }
    #endif

    // MARK: - Combined count

    private func applyCombinedCount() {
        guard isCounting, !isPaused, !isMissionCompleting else { return }

        currentStepCount = min(pedometerSteps + shakeSteps, targetStepCount)
        stepProgress = Double(currentStepCount) / Double(targetStepCount)
        NotificationCenter.default.post(name: .stepCountUpdated, object: nil)

        throttleLiveActivityUpdate()

        if currentStepCount >= targetStepCount {
            isMissionCompleting = true
            isCounting = false
            stopSensors()
            completionHaptic.impactOccurred()
            AlarmMissionActivity.shared.updateActivity(stepsRemaining: 0)
            AppAlarmManager.shared.completeMission()
        }
    }

    private func throttleLiveActivityUpdate() {
        let now = Date()
        guard now.timeIntervalSince(lastActivityUpdateTime) >= Constants.StepTracking.liveActivityUpdateInterval else {
            return
        }
        lastActivityUpdateTime = now
        AlarmMissionActivity.shared.updateActivity(stepsRemaining: targetStepCount - currentStepCount)
    }
}

/// Peak-based step/shake detector, confined to a single background queue.
///
/// Sensitivity design (MOO-175 bug #2 — counter was nearly impossible to
/// move with a natural arm swing):
/// - Peak threshold **1.4 g** total magnitude: a normal in-hand arm swing
///   peaks around 1.6–2.2 g; the old 2.5 g required violent shaking.
/// - Deliberate shake threshold **2.0 g**: still accepts any honest shake
///   as valid movement (per product spec).
/// - Minimum peak distance **0.3 s**: matches a natural walking cadence
///   (up to ~3 steps/s); the old 0.6 s dropped every other step.
/// - Anti-jiggle: the first event only counts once a second event arrives
///   within 3 s (so a single tap/bump can never start or advance the
///   mission); afterwards every event counts.
final class StepPeakDetector: @unchecked Sendable {
    private let lock = NSLock()
    private var magnitudeBuffer: [Double] = []
    private let magnitudeWindowSize = Constants.StepTracking.stepDetectionWindowSize

    private var lastEventTime = Date.distantPast
    /// Timestamps of the (up to 2) pending confirmation events.
    private var pendingConfirmation: [Date] = []
    private var isConfirmed = false

    /// Processes one accelerometer magnitude sample and returns how many
    /// steps were detected (0 or 1). Must be called from a single queue.
    func process(magnitude: Double, at now: Date) -> Int {
        lock.lock()
        defer { lock.unlock() }

        magnitudeBuffer.append(magnitude)
        if magnitudeBuffer.count > magnitudeWindowSize {
            magnitudeBuffer.removeFirst()
        }
        guard magnitudeBuffer.count >= 3 else { return 0 }

        let count = magnitudeBuffer.count
        let current = magnitudeBuffer[count - 1]
        let previous = magnitudeBuffer[count - 2]
        let beforePrevious = magnitudeBuffer[count - 3]

        let isPeak = previous > current && previous > beforePrevious
        let peakThreshold = Constants.StepTracking.stepPeakThreshold
        let shakeThreshold = Constants.StepTracking.shakeAccelerationThreshold

        var detected = false

        // Both paths share one suppression timestamp: a single hard
        // shake is a peak on its falling edge too, and counting both
        // would double-register every deliberate shake (a 2.5 g spike
        // used to count as two steps). One physical event = one step.
        if isPeak && previous > peakThreshold {
            let minDistance = Constants.StepTracking.stepMinPeakDistance
            guard now.timeIntervalSince(lastEventTime) >= minDistance else { return 0 }
            detected = true
        } else if magnitude > shakeThreshold {
            let minInterval = Constants.StepTracking.shakeMinimumInterval
            guard now.timeIntervalSince(lastEventTime) >= minInterval else { return 0 }
            detected = true
        }

        guard detected else { return 0 }
        lastEventTime = now
        return confirm(now: now)
    }

    private func confirm(now: Date) -> Int {
        if isConfirmed { return 1 }
        pendingConfirmation.append(now)
        pendingConfirmation.removeAll { $0.timeIntervalSince(now) < -Constants.StepTracking.confirmationWindow }
        guard pendingConfirmation.count >= Constants.StepTracking.confirmationEventCount else { return 0 }
        isConfirmed = true
        // The confirming events themselves count once activity is confirmed.
        return 1
    }
}
