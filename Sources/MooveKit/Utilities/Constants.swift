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

    /// Soft warning window after the StoreKit intro trial expires and the user
    /// has not converted. Alarms keep working; a banner prompts subscribe.
    /// After this window the hard paywall locks scheduling and alarm-fire.
    public static let postTrialGracePeriod: TimeInterval = 24 * 3600

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
        public static let pedometerUpdateInterval: TimeInterval = 0.05

        /// Total-magnitude (incl. gravity) threshold for a walking-peak.
        /// A natural in-hand arm swing peaks at ~1.6–2.2 g, so 1.4 g
        /// registers ordinary walking without registering idle fidgets.
        public static let stepPeakThreshold: Double = 1.4
        /// A deliberate shake must exceed this to count as movement.
        public static let shakeAccelerationThreshold: Double = 2.0
        /// Minimum spacing between detected peaks — matches a natural
        /// walking cadence (up to ~3 steps/sec).
        public static let stepMinPeakDistance: TimeInterval = 0.3
        public static let shakeMinimumInterval: TimeInterval = 0.4
        public static let stepDetectionWindowSize: Int = 10

        /// Anti-jiggle confirmation: the first detected event starts
        /// counting only after a second event within this window, so a
        /// single tap/bump can never advance the mission.
        public static let confirmationWindow: TimeInterval = 3.0
        public static let confirmationEventCount: Int = 2

        public static let liveActivityUpdateInterval: TimeInterval = 1.0
    }
}
