import AppIntents
import MooveKit

struct StopAlarmIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Alarm"
    static let description: IntentDescription = "Begin the step mission to stop the alarm."

    @Parameter(title: "Alarm Identifier")
    var alarmIdentifier: String?

    init(alarmIdentifier: String? = nil) {
        self.alarmIdentifier = alarmIdentifier
    }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        let config: AlarmConfig
        if let alarmID = alarmIdentifier,
           let uuid = UUID(uuidString: alarmID),
           let found = AppAlarmManager.shared.alarms.first(where: { $0.id == uuid }) {
            config = found
        } else {
            config = AlarmConfig(stepGoal: 30)
        }
        if AppAlarmManager.shared.alarmState == .missionActive,
           let active = AppAlarmManager.shared.activeMission,
           active.id == config.id {
            return .result(dialog: "Keep walking! \(AppAlarmManager.shared.activeMission?.stepGoal ?? 30) steps to go.")
        }
        AppAlarmManager.shared.startMission(for: config)
        return .result(dialog: "Start walking! You need \(config.stepGoal) steps to stop the alarm.")
    }
}
