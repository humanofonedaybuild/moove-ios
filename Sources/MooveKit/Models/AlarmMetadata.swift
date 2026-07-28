import Foundation

#if canImport(AlarmKit)
import AlarmKit
#endif

public struct MooveAlarmMetadata: Codable, Hashable, Sendable {
    public var alarmID: UUID
    public var stepGoal: Int
    public var soundName: String

    public init(alarmID: UUID, stepGoal: Int, soundName: String) {
        self.alarmID = alarmID
        self.stepGoal = stepGoal
        self.soundName = soundName
    }
}

#if canImport(AlarmKit)
extension MooveAlarmMetadata: AlarmMetadata {}
#endif
