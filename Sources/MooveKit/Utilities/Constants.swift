import Foundation

public enum Constants {
    public static let appGroupIdentifier = "group.com.moove.alarmclock"
    public static let watchAppIdentifier = "com.moove.alarmclock.watch"

    public static let maximumSnoozeCount: Int = 1

    /// Max snooze count options offered in Settings (0 = snooze disabled, up to a maximum of 3).
    public static let maxSnoozeOptions: [Int] = [0, 1, 2, 3]

    public struct SnoozeOption: Sendable, Equatable {
        public let label: String
        public let duration: TimeInterval

        public init(label: String, duration: TimeInterval) {
            self.label = label
            self.duration = duration
        }
    }

    public static let snoozeOptions: [SnoozeOption] = [
        SnoozeOption(label: "5 min", duration: 300),
        SnoozeOption(label: "10 min", duration: 600),
        SnoozeOption(label: "15 min", duration: 900),
    ]

    /// 7-day trial duration for subscriptions
    public static let subscriptionTrialDuration: TimeInterval = 7 * 24 * 3600

    public enum Links {
        public static let termsOfService = URL(string: "https://moovealarm.com/terms")!
        public static let privacyPolicy = URL(string: "https://moovealarm.com/privacy")!
    }

    public static let liveActivityPushInterval: TimeInterval = 2.0

    /// Duration of the "Gradual Volume" fade-in for alarm playback.
    public static let gradualVolumeRampDuration: TimeInterval = 30

    public enum StepTracking {
        public static let minimumSteps: Int = 10
        public static let maximumSteps: Int = 100
        public static let stepInterval: Int = 10
        public static let pedalometerUpdateInterval: TimeInterval = 0.5
        public static let shakeAccelerationThreshold: Double = 2.5
        public static let shakeMinimumInterval: TimeInterval = 0.3
    }
}
