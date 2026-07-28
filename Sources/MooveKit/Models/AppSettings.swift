import Foundation

public struct AppSettings: Codable, Sendable, Equatable {
    public var defaultStepGoal: Int
    public var defaultSoundName: String
    public var snoozeLimit: Int
    public var snoozeDurationIndex: Int
    public var gradualVolume: Bool
    public var liveActivitiesEnabled: Bool

    public static let `default` = AppSettings(
        defaultStepGoal: 30,
        defaultSoundName: "default",
        snoozeLimit: 1,
        snoozeDurationIndex: 0,
        gradualVolume: false,
        liveActivitiesEnabled: true
    )

    public var snoozeDuration: TimeInterval {
        guard snoozeDurationIndex >= 0,
              snoozeDurationIndex < Constants.snoozeOptions.count
        else { return 300 }
        return Constants.snoozeOptions[snoozeDurationIndex].duration
    }

    public static func load() -> AppSettings {
        guard let data = UserDefaults(suiteName: Constants.appGroupIdentifier)?
            .data(forKey: "appSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return .default }
        return settings
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Constants.appGroupIdentifier)?
            .set(data, forKey: "appSettings")
    }
}
