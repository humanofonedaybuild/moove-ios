import Foundation
import WatchConnectivity

@Observable
@MainActor
final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    var isReachable: Bool = false

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

    func sendStepUpdate(stepsCompleted: Int) {
        guard session.isReachable else { return }
        session.sendMessage(
            ["action": "stepUpdate", "stepsCompleted": stepsCompleted],
            replyHandler: nil
        )
    }

    func sendMissionComplete() {
        guard session.isReachable else { return }
        session.sendMessage(
            ["action": "missionComplete"],
            replyHandler: nil
        )
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error {
            print("Watch WCSession activation failed: \(error.localizedDescription)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        let stepsRequired = message["stepsRequired"] as? Int
        Task { @MainActor in
            switch action {
            case "missionStart":
                if let stepsRequired {
                    WatchStepCounter.shared.startMission(stepsRequired: stepsRequired)
                }
            default:
                break
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            isReachable = reachable
        }
    }
}
