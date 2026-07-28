import Foundation
import WatchConnectivity
import MooveKit

@MainActor
final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    private let session: WCSession

    private override init() {
        session = WCSession.default
        super.init()
        session.delegate = self
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.activate()
    }

    func sendMissionStart(stepsRequired: Int) {
        guard session.isReachable else { return }
        session.sendMessage(
            ["action": "missionStart", "stepsRequired": stepsRequired],
            replyHandler: nil,
            errorHandler: { error in
                print("WCS sendMissionStart failed: \(error.localizedDescription)")
            }
        )
    }

    func sendStepUpdate(stepsRemaining: Int) {
        guard session.isReachable else { return }
        session.sendMessage(
            ["action": "stepUpdate", "stepsRemaining": stepsRemaining],
            replyHandler: nil,
            errorHandler: { error in
                print("WCS sendStepUpdate failed: \(error.localizedDescription)")
            }
        )
    }

    func sendMissionComplete() {
        guard session.isReachable else { return }
        session.sendMessage(
            ["action": "missionComplete"],
            replyHandler: nil,
            errorHandler: { error in
                print("WCS sendMissionComplete failed: \(error.localizedDescription)")
            }
        )
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error {
            print("WCSession activation failed: \(error.localizedDescription)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        let steps = message["stepsCompleted"] as? Int
        Task { @MainActor in
            switch action {
            case "stepUpdate":
                if let completed = steps {
                    StepCounter.shared.syncFromWatch(completed)
                }
            case "missionComplete":
                AppAlarmManager.shared.completeMission()
            default:
                break
            }
        }
    }
}
