import Foundation
import CoreMotion
import MooveKit

final class ShakeDetector {
    private let motionManager = CMMotionManager()
    private let onShake: () -> Void
    private var isDetecting = false
    private var lastShakeTime: Date = .distantPast

    init(onShake: @escaping () -> Void) {
        self.onShake = onShake
    }

    func startDetecting() {
        guard motionManager.isAccelerometerAvailable, !isDetecting else { return }
        isDetecting = true
        motionManager.accelerometerUpdateInterval = Constants.StepTracking.pedometerUpdateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let data, error == nil else { return }
            self?.processAccelerometerData(data)
        }
    }

    func stopDetecting() {
        isDetecting = false
        motionManager.stopAccelerometerUpdates()
    }

    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let acceleration = data.acceleration
        let magnitude = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )

        let now = Date()
        guard magnitude > Constants.StepTracking.shakeAccelerationThreshold,
              now.timeIntervalSince(lastShakeTime) > Constants.StepTracking.shakeMinimumInterval
        else { return }

        lastShakeTime = now
        onShake()
    }
}
