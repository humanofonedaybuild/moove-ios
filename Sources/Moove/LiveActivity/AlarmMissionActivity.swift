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

    private init() {}

    func startActivity(stepsRequired: Int) {
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
        Task { @MainActor in
            await activity?.update(content)
        }
    }

    func endActivity() {
        Task { @MainActor in
            let contentState = AlarmMissionAttributes.ContentState(stepsRemaining: 0)
            let content = ActivityContent(state: contentState, staleDate: nil)
            await activity?.end(content, dismissalPolicy: .immediate)
            activity = nil
        }
    }
}
