import Foundation
import HealthKit
import Observation

@Observable
@MainActor
final class WorkoutSessionManager: NSObject {
    static let shared = WorkoutSessionManager()

    var isSessionActive: Bool = false

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private override init() {
        super.init()
    }

    func requestAuthorization() async -> Bool {
        // Screenshot hook: skip the HealthKit auth sheet so the redesigned
        // watch UI is unobstructed during captures.
        if ProcessInfo.processInfo.arguments.contains("-UITestingSkipHealthAuth") { return true }
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let typesToWrite: Set<HKSampleType> = [HKWorkoutType.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate)
        ]
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            return true
        } catch {
            print("HealthKit auth failed: \(error.localizedDescription)")
            return false
        }
    }

    private var startTask: Task<Void, Never>?

    func startWorkout() {
        guard !isSessionActive else { return }
        startTask?.cancel()
        startTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let authorized = await self.requestAuthorization()
            guard authorized, !Task.isCancelled else { return }

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .walking
            configuration.locationType = .indoor

            do {
                try Task.checkCancellation()
                self.session = try HKWorkoutSession(healthStore: self.healthStore, configuration: configuration)
                self.builder = self.session?.associatedWorkoutBuilder()
                self.builder?.dataSource = HKLiveWorkoutDataSource(
                    healthStore: self.healthStore,
                    workoutConfiguration: configuration
                )

                self.session?.delegate = self
                self.builder?.delegate = self

                self.session?.startActivity(with: Date())
                try await self.builder?.beginCollection(at: Date())
                try Task.checkCancellation()
                self.isSessionActive = true
            } catch is CancellationError {
                self.session?.end()
                self.session = nil
                self.builder = nil
                self.isSessionActive = false
            } catch {
                print("Workout session failed: \(error.localizedDescription)")
            }
        }
    }

    func stopWorkout() {
        startTask?.cancel()
        startTask = nil
        Task {
            session?.end()
            if let builder, let session {
                try? await builder.endCollection(at: Date())
                let sample = try? await builder.finishWorkout()
                print("Workout saved: \(sample?.uuid.uuidString ?? "nil")")
            }
            session = nil
            builder = nil
            isSessionActive = false
        }
    }
}

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        print("WorkoutSession: \(fromState.rawValue) -> \(toState.rawValue)")
        Task { @MainActor in
            self.isSessionActive = toState == .running
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: any Error
    ) {
        print("WorkoutSession failed: \(error.localizedDescription)")
        Task { @MainActor in
            self.isSessionActive = false
        }
    }
}

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {}

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
