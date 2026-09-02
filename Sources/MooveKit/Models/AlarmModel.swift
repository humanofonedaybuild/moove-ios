import Foundation

public enum AlarmState: Codable, Sendable {
    case idle
    case scheduled
    case firing
    case missionActive
    case snoozed
    case stopped
}

public struct AlarmConfig: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var label: String
    public var hour: Int
    public var minute: Int
    public var weekdays: Set<Int>
    public var isEnabled: Bool
    public var stepGoal: Int
    public var snoozeRemaining: Int
    public var snoozeEnabled: Bool
    public var soundName: String

    public static let defaultStepRange: ClosedRange<Int> = 10...100
    public static let stepInterval: Int = 10

    public static let weekdaySymbols: [Int: String] = [
        1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat", 7: "Sun"
    ]

    public static let weekdayFullSymbols: [Int: String] = [
        1: "Monday", 2: "Tuesday", 3: "Wednesday", 4: "Thursday", 5: "Friday", 6: "Saturday", 7: "Sunday"
    ]

    public static let weekdayOrder: [Int] = [1, 2, 3, 4, 5, 6, 7]

    public init(
        id: UUID = UUID(),
        label: String = "Alarm",
        hour: Int = 7,
        minute: Int = 0,
        weekdays: Set<Int> = [],
        isEnabled: Bool = true,
        stepGoal: Int = 30,
        snoozeRemaining: Int = 1,
        snoozeEnabled: Bool = true,
        soundName: String = "barium"
    ) {
        self.id = id
        self.label = label
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.stepGoal = Self.clampSteps(stepGoal)
        self.snoozeRemaining = snoozeRemaining
        self.snoozeEnabled = snoozeEnabled
        self.soundName = soundName
    }

    public var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        let amPm = hour >= 12 ? "PM" : "AM"
        return "\(formatter.string(from: date)) \(amPm)"
    }

    public var weekdaySummary: String {
        if weekdays.isEmpty { return "Once" }
        if weekdays == Set([1, 2, 3, 4, 5]) { return "Weekdays" }
        if weekdays == Set([6, 7]) { return "Weekends" }
        if weekdays.count == 7 { return "Every day" }
        return Self.weekdayOrder
            .filter { weekdays.contains($0) }
            .compactMap { Self.weekdaySymbols[$0] }
            .joined(separator: " ")
    }

    public static func == (lhs: AlarmConfig, rhs: AlarmConfig) -> Bool {
        lhs.id == rhs.id
            && lhs.label == rhs.label
            && lhs.hour == rhs.hour
            && lhs.minute == rhs.minute
            && lhs.weekdays == rhs.weekdays
            && lhs.isEnabled == rhs.isEnabled
            && lhs.stepGoal == rhs.stepGoal
            && lhs.snoozeRemaining == rhs.snoozeRemaining
            && lhs.snoozeEnabled == rhs.snoozeEnabled
            && lhs.soundName == rhs.soundName
    }

    public static func clampSteps(_ steps: Int) -> Int {
        let clamped = steps.clamped(to: defaultStepRange)
        let remainder = clamped % stepInterval
        return remainder == 0 ? clamped : clamped + (stepInterval - remainder)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
