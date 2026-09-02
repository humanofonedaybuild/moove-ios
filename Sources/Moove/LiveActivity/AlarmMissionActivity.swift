import Foundation
@preconcurrency import ActivityKit
import MooveKit

struct AlarmMissionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stepsRemaining: Int
    }

    var stepsRequired: Int
}

@MainActor
final class AlarmMissionActivity {
    static let shared = AlarmMissionActivity()

    private var activity: Activity<AlarmMissionAttributes>?
    private var updateTask: Task<Void, Never>?

    private init() {}

    func startActivity(stepsRequired: Int) {
        endActivity()

        let attributes = AlarmMissionAttributes(stepsRequired: stepsRequired)
        let contentState = AlarmMissionAttributes.ContentState(stepsRemaining: stepsRequired)
        let content = ActivityContent(
            state: contentState,
            staleDate: nil
        )

        activity = try? Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }

    func updateActivity(stepsRemaining: Int) {
        let contentState = AlarmMissionAttributes.ContentState(stepsRemaining: stepsRemaining)
        let content = ActivityContent(state: contentState, staleDate: nil)
        updateTask?.cancel()
        updateTask = Task { @MainActor [weak self] in
            guard let self, let activity = self.activity else { return }
            guard !Task.isCancelled else { return }
            // Never touch an activity that has already ended or been
            // dismissed — updating a dead activity is undefined and a
            // mid-mission crash vector when the user clears the Live
            // Activity from the Dynamic Island while walking.
            guard activity.activityState == .active else { return }
            await activity.update(content)
        }
    }

    func endActivity() {
        updateTask?.cancel()
        updateTask = nil
        let currentActivity = activity
        activity = nil
        Task { @MainActor in
            let contentState = AlarmMissionAttributes.ContentState(stepsRemaining: 0)
            let content = ActivityContent(state: contentState, staleDate: nil)
            await currentActivity?.end(content, dismissalPolicy: .immediate)
        }
    }
}
