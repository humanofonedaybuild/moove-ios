import Foundation
import CoreMotion
import Observation
import UIKit
import MooveKit

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
    private var motionUpdateTask: Task<Void, Never>?
    private var lastShakeTime: Date = .distantPast
    private var lastStepTime: Date = .distantPast

    private var pedometerSteps: Int = 0
    private var shakeSteps: Int = 0

    private var isMissionCompleting = false

    private var magnitudeBuffer: [Double] = []
    private let magnitudeWindowSize = Constants.StepTracking.stepDetectionWindowSize

    private var lastActivityUpdateTime: Date = .distantPast
    private var recentStepTimestamps: [Date] = []
    private let sustainedActivityWindow: TimeInterval = 4.0
    private let sustainedActivityMinSteps: Int = 3

    private let stepHaptic = UIImpactFeedbackGenerator(style: .light)
    private let completionHaptic = UIImpactFeedbackGenerator(style: .soft)

    private override init() {
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
        magnitudeBuffer = []
        lastShakeTime = .distantPast
        lastStepTime = .distantPast
        lastActivityUpdateTime = .distantPast
        recentStepTimestamps = []

        startPedometerUpdates()
        startAccelerometerStepDetection()
    }

    func requestAuthorization() {
    }

    func syncFromWatch(_ stepsCompleted: Int) {
        guard isCounting else { return }
        handleStepUpdate(stepsCompleted)
    }

    func stopCounting() {
        isCounting = false
        isPaused = false
        pedometer.stopEventUpdates()
        pedometer.stopUpdates()
        motionManager.stopAccelerometerUpdates()
        motionUpdateTask?.cancel()
        motionUpdateTask = nil
    }

    func pauseCounting() {
        guard isCounting, !isPaused else { return }
        isPaused = true
        pedometer.stopEventUpdates()
        pedometer.stopUpdates()
        motionManager.stopAccelerometerUpdates()
    }

    func resumeCounting() {
        guard isCounting, isPaused else { return }
        isPaused = false
        startPedometerUpdates()
        startAccelerometerStepDetection()
    }

    private func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }

        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            MainActor.assumeIsolated {
                self.handleStepUpdate(data.numberOfSteps.intValue)
            }
        }
    }

    private func handleStepUpdate(_ steps: Int) {
        guard isCounting, !isPaused else { return }
        pedometerSteps = max(pedometerSteps, steps)
        applyCombinedCount()
    }

    private func startAccelerometerStepDetection() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.05

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            let acceleration = data.acceleration
            let magnitude = sqrt(
                acceleration.x * acceleration.x +
                acceleration.y * acceleration.y +
                acceleration.z * acceleration.z
            )
            MainActor.assumeIsolated {
                self.processAccelerometerMagnitude(magnitude)
            }
        }
    }

    private func processAccelerometerMagnitude(_ magnitude: Double) {
        guard isCounting, !isPaused else { return }

        magnitudeBuffer.append(magnitude)
        if magnitudeBuffer.count > magnitudeWindowSize {
            magnitudeBuffer.removeFirst()
        }
        guard magnitudeBuffer.count >= 3 else { return }

        let count = magnitudeBuffer.count
        let current = magnitudeBuffer[count - 1]
        let previous = magnitudeBuffer[count - 2]
        let beforePrevious = magnitudeBuffer[count - 3]

        let isPeak = previous > current && previous > beforePrevious

        let peakThreshold = Constants.StepTracking.stepPeakThreshold
        let shakeThreshold = Constants.StepTracking.shakeAccelerationThreshold

        if isPeak && previous > peakThreshold {
            let now = Date()
            let minDistance = Constants.StepTracking.stepMinPeakDistance
            guard now.timeIntervalSince(lastStepTime) > minDistance else { return }
            lastStepTime = now
            recentStepTimestamps.append(now)
            trimRecentStepTimestamps(to: now)
            guard isSustainedWalkingActivity() else { return }
            shakeSteps += 1
            stepHaptic.impactOccurred()
            applyCombinedCount()
        } else if magnitude > shakeThreshold {
            let now = Date()
            let minInterval = Constants.StepTracking.shakeMinimumInterval
            guard now.timeIntervalSince(lastShakeTime) > minInterval else { return }
            lastShakeTime = now
            recentStepTimestamps.append(now)
            trimRecentStepTimestamps(to: now)
            guard isSustainedWalkingActivity() else { return }
            shakeSteps += 1
            stepHaptic.impactOccurred()
            applyCombinedCount()
        }
    }

    private func trimRecentStepTimestamps(to now: Date) {
        let cutoff = now.addingTimeInterval(-sustainedActivityWindow)
        recentStepTimestamps.removeAll { $0 < cutoff }
    }

    private func isSustainedWalkingActivity() -> Bool {
        recentStepTimestamps.count >= sustainedActivityMinSteps
    }

    #if DEBUG
    func debugSimulateSteps(_ count: Int) {
        guard isCounting else { return }
        shakeSteps += count
        applyCombinedCount()
    }
    #endif

    private func applyCombinedCount() {
        guard isCounting, !isPaused, !isMissionCompleting else { return }

        currentStepCount = min(pedometerSteps + shakeSteps, targetStepCount)
        stepProgress = Double(currentStepCount) / Double(targetStepCount)
        NotificationCenter.default.post(name: .stepCountUpdated, object: nil)

        throttleLiveActivityUpdate()

        if currentStepCount >= targetStepCount {
            isMissionCompleting = true
            isCounting = false
            pedometer.stopEventUpdates()
            pedometer.stopUpdates()
            motionManager.stopAccelerometerUpdates()
            motionUpdateTask?.cancel()
            motionUpdateTask = nil
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
