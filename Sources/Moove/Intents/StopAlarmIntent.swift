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
        if AppAlarmManager.shared.alarmState == .missionActive,
           let active = AppAlarmManager.shared.activeMission,
           alarmIdentifier == active.id.uuidString || alarmIdentifier == nil {
            return .result(dialog: "Keep walking! \(active.stepGoal) steps to go.")
        }

        AppAlarmManager.shared.handleSnoozeFromLockScreen(
            alarmIdentifier: alarmIdentifier,
            snoozeEnabled: snoozeEnabled
        )

        if AppAlarmManager.shared.alarmState == .snoozed {
            let snoozeMinutes = Int(AppSettings.load().snoozeDuration / 60)
            return .result(dialog: "Alarm snoozed for \(snoozeMinutes) minutes. Start walking when it rings again!")
        }

        return .result(dialog: "Start walking! You need to complete your steps to stop the alarm.")
    }
}
