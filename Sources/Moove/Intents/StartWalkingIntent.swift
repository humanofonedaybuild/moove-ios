import AppIntents
import MooveKit

struct StartWalkingIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Walking"
    static let description: IntentDescription = "Begin the step mission to stop the alarm."

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Steps Required")
    var stepsRequired: Int

    @Parameter(title: "Alarm Identifier")
    var alarmIdentifier: String?

    init(stepsRequired: Int, alarmIdentifier: String? = nil) {
        self.stepsRequired = stepsRequired
        self.alarmIdentifier = alarmIdentifier
    }

    init() {
        self.stepsRequired = 30
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let config: AlarmConfig
        if let alarmID = alarmIdentifier,
           let uuid = UUID(uuidString: alarmID),
           let found = AppAlarmManager.shared.alarms.first(where: { $0.id == uuid }) {
            config = found
        } else {
            config = AlarmConfig(stepGoal: stepsRequired)
        }
        if !SubscriptionManager.shared.canUseAlarms {
            SubscriptionManager.shared.presentRequiredPaywall()
            return .result(dialog: "Subscribe to continue using Moove.")
        }
        AppAlarmManager.shared.startMission(for: config)
        return .result(dialog: "Start walking! You need \(config.stepGoal) steps to stop the alarm.")
    }
}
