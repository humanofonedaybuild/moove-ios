import Foundation
import SwiftUI
import AlarmKit
import MooveKit

extension AlarmManager.AlarmConfiguration {
    static func make(for config: AlarmConfig) -> AlarmManager.AlarmConfiguration<MooveAlarmMetadata> {
        let metadata = MooveAlarmMetadata(
            alarmID: config.id,
            stepGoal: config.stepGoal,
            soundName: config.soundName
        )

        let weekdayMapping: [Int: Locale.Weekday] = [
            1: .monday, 2: .tuesday, 3: .wednesday, 4: .thursday,
            5: .friday, 6: .saturday, 7: .sunday
        ]
        let weekdays = config.weekdays.compactMap { weekdayMapping[$0] }

        let time = Alarm.Schedule.Relative.Time(hour: config.hour, minute: config.minute)
        let recurrence: Alarm.Schedule.Relative.Recurrence = weekdays.isEmpty
            ? .never
            : .weekly(weekdays)
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: recurrence))

        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: config.label),
                stopButton: AlarmButton(
                    text: "Walk to Stop",
                    textColor: .cream,
                    systemImageName: "figure.walk"
                ),
                secondaryButton: AlarmButton(
                    text: "Start Walking",
                    textColor: .cream,
                    systemImageName: "figure.walk"
                ),
                secondaryButtonBehavior: .custom
            )
        )

        let attributes = AlarmAttributes<MooveAlarmMetadata>(
            presentation: presentation,
            metadata: metadata,
            tintColor: Color.brandPrimary
        )

        return AlarmManager.AlarmConfiguration.alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(
                alarmIdentifier: config.id.uuidString
            ),
            secondaryIntent: StartWalkingIntent(
                stepsRequired: config.stepGoal,
                alarmIdentifier: config.id.uuidString
            ),
            sound: .default
        )
    }
}
