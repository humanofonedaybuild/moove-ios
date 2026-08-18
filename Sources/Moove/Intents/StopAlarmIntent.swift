import AppIntents
import MooveKit

struct StopAlarmIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Snooze Alarm"
    static let description: IntentDescription = "Snooze the alarm or start the step mission."
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Alarm Identifier")
    var alarmIdentifier: String?

    @Parameter(title: "Snooze Enabled")
    var snoozeEnabled: Bool

    init(alarmIdentifier: String? = nil, snoozeEnabled: Bool = true) {
        self.alarmIdentifier = alarmIdentifier
        self.snoozeEnabled = snoozeEnabled
    }

    init() {
        self.snoozeEnabled = true
    }

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

        if snoozeEnabled && !AppAlarmManager.shared.snoozeUsedThisMission {
            let snoozeDuration = AppSettings.load().snoozeDuration
            AppAlarmManager.shared.snoozeAlarm(duration: snoozeDuration)
            return .result(dialog: "Alarm snoozed for \(Int(snoozeDuration / 60)) minutes. Start walking when it rings again!")
        }

        AppAlarmManager.shared.startMission(for: config)
        return .result(dialog: "Start walking! You need \(config.stepGoal) steps to stop the alarm.")
    }
}
