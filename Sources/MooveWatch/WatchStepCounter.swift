import Foundation
import CoreMotion
import WatchKit
import Observation

enum MissionState: Sendable {
    case idle
    case counting
    case completed
}

@Observable
@MainActor
final class WatchStepCounter: NSObject {
    static let shared = WatchStepCounter()

    var currentSteps: Int = 0
    var targetSteps: Int = 30
    var missionState: MissionState = .idle

    var isMissionActive: Bool { missionState == .counting }
    var isCompleted: Bool { missionState == .completed }

    private let pedometer = CMPedometer()

    private override init() {
        super.init()
    }

    func startMission(stepsRequired: Int) {
        targetSteps = stepsRequired
        currentSteps = 0
        missionState = .counting
        WorkoutSessionManager.shared.startWorkout()
        startPedometerUpdates()
    }

    func stopMission() {
        missionState = .idle
        pedometer.stopUpdates()
        pedometer.stopEventUpdates()
        WorkoutSessionManager.shared.stopWorkout()
    }

    private func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let data, error == nil else { return }
            DispatchQueue.main.async {
                guard let self, self.isMissionActive else { return }
                self.currentSteps = data.numberOfSteps.intValue
                WatchSessionManager.shared.sendStepUpdate(
                    stepsCompleted: self.currentSteps
                )
                if self.currentSteps >= self.targetSteps {
                    self.missionCompleted()
                }
            }
        }
    }

    private func missionCompleted() {
        missionState = .completed
        WKInterfaceDevice.current().play(.success)
        WatchSessionManager.shared.sendMissionComplete()
        pedometer.stopUpdates()
        pedometer.stopEventUpdates()
        WorkoutSessionManager.shared.stopWorkout()
        Task {
            try? await Task.sleep(for: .seconds(3))
            guard self.missionState == .completed else { return }
            self.missionState = .idle
        }
    }
}
