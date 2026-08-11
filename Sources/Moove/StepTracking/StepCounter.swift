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
    var stepProgress: Double = 0.0

    private let pedometer = CMPedometer()
    private let motionManager = CMMotionManager()
    private var shakeMonitor: Task<Void, Never>?
    private var lastShakeTime: Date = .distantPast

    /// Pedometer reports cumulative steps since mission start; shakes are
    /// counted locally. Keep them separate so one source never overwrites
    /// the other (previously a pedometer event could erase shake progress).
    private var pedometerSteps: Int = 0
    private var shakeSteps: Int = 0

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

        startPedometerUpdates()
        startShakeMonitoring()
    }

    func requestAuthorization() {
        // CMPedometer doesn't require explicit authorization call on iOS 26+.
        // Motion activity permissions are prompted at first use.
    }

    func syncFromWatch(_ stepsCompleted: Int) {
        guard isCounting else { return }
        handleStepUpdate(stepsCompleted)
    }

    func stopCounting() {
        isCounting = false
        pedometer.stopEventUpdates()
        pedometer.stopUpdates()
        motionManager.stopAccelerometerUpdates()
        shakeMonitor?.cancel()
        shakeMonitor = nil
    }

    private func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }

        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            Task { @MainActor in
                self.handleStepUpdate(data.numberOfSteps.intValue)
            }
        }
    }

    private func handleStepUpdate(_ steps: Int) {
        guard isCounting else { return }
        pedometerSteps = max(pedometerSteps, steps)
        applyCombinedCount()
    }

    private func startShakeMonitoring() {
        let manager = motionManager
        shakeMonitor = Task { [weak self] in
            while !Task.isCancelled {
                if manager.isAccelerometerActive {
                    try? await Task.sleep(for: .milliseconds(100))
                    continue
                }
                manager.startAccelerometerUpdates(to: .main) { data, error in
                    guard let data, error == nil else { return }
                    let acceleration = data.acceleration
                    let magnitude = sqrt(
                        acceleration.x * acceleration.x +
                        acceleration.y * acceleration.y +
                        acceleration.z * acceleration.z
                    )
                    if magnitude > Constants.StepTracking.shakeAccelerationThreshold {
                        Task { @MainActor in
                            self?.handleShake()
                        }
                    }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func handleShake() {
        guard isCounting else { return }
        let now = Date()
        guard now.timeIntervalSince(lastShakeTime) > Constants.StepTracking.shakeMinimumInterval else { return }
        lastShakeTime = now
        shakeSteps += 1
        NotificationCenter.default.post(name: .shakeDetected, object: nil)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        applyCombinedCount()
    }

    #if DEBUG
    /// QA hook (MOO-87): simulates physical steps in the simulator, where the
    /// pedometer and accelerometer produce no movement data. Feeds the same
    /// monotonic combined-count path as real shake events.
    func debugSimulateSteps(_ count: Int) {
        guard isCounting else { return }
        shakeSteps += count
        applyCombinedCount()
    }
    #endif

    /// Merges pedometer + shake progress into a single monotonic count so
    /// neither source can regress the mission counter.
    private func applyCombinedCount() {        currentStepCount = min(pedometerSteps + shakeSteps, targetStepCount)
        stepProgress = Double(currentStepCount) / Double(targetStepCount)
        NotificationCenter.default.post(name: .stepCountUpdated, object: nil)
        AlarmMissionActivity.shared.updateActivity(stepsRemaining: targetStepCount - currentStepCount)

        if currentStepCount >= targetStepCount {
            stopCounting()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            AppAlarmManager.shared.completeMission()
        }
    }
}
