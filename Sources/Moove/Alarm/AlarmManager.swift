import Foundation
import AlarmKit
import Observation
import MooveKit

@Observable
@MainActor
final class AppAlarmManager: NSObject {
    static let shared = AppAlarmManager()

    var alarms: [AlarmConfig] = []
    var activeMission: AlarmConfig?
    var alarmState: AlarmState = .idle
    var missionStartTime: Date?

    private var alarmObservationTask: Task<Void, Never>?

    private override init() {
        super.init()
        loadAlarms()
        observeAlarmUpdates()
    }

    func addAlarm(_ config: AlarmConfig? = nil) {
        let newConfig = config ?? AlarmConfig(
            label: "Alarm \(alarms.count + 1)",
            hour: 8,
            minute: 0,
            weekdays: [1, 2, 3, 4, 5]
        )
        alarms.append(newConfig)
        Task { await scheduleAlarm(newConfig) }
        saveAlarms()
    }

    func updateAlarm(_ config: AlarmConfig) {
        guard let index = alarms.firstIndex(where: { $0.id == config.id }) else { return }
        cancelAlarm(alarms[index])
        alarms[index] = config
        Task { await scheduleAlarm(config) }
        saveAlarms()
    }

    func deleteAlarms(at offsets: IndexSet) {
        let removed = offsets.map { alarms[$0] }
        for config in removed {
            cancelAlarm(config)
        }
        alarms.remove(atOffsets: offsets)
        saveAlarms()
    }

    func deleteAlarm(_ config: AlarmConfig) {
        cancelAlarm(config)
        alarms.removeAll { $0.id == config.id }
        saveAlarms()
    }

    func toggleAlarm(_ config: AlarmConfig) {
        var updated = config
        updated.isEnabled.toggle()
        if updated.isEnabled {
            Task { await scheduleAlarm(updated) }
        } else {
            cancelAlarm(updated)
        }
        if let index = alarms.firstIndex(where: { $0.id == config.id }) {
            alarms[index] = updated
        }
        saveAlarms()
    }

    /// Requests AlarmKit authorization when undetermined. Scheduling throws
    /// `.notAuthorized` without it — previously nothing in the app ever asked,
    /// so a fresh install silently failed to schedule every alarm (QA MOO-87).
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        guard #available(iOS 26.0, *) else { return true }
        switch AlarmManager.shared.authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            let state = try? await AlarmManager.shared.requestAuthorization()
            return state == .authorized
        @unknown default:
            return false
        }
    }

    private func scheduleAlarm(_ config: AlarmConfig) async {
        guard config.isEnabled else { return }
        guard #available(iOS 26.0, *) else { return }
        guard await requestAuthorizationIfNeeded() else {
            print("AlarmKit: authorization not granted — alarm \(config.id) was not scheduled")
            return
        }
        let alarmConfig: AlarmManager.AlarmConfiguration<MooveAlarmMetadata> = .make(for: config)
        do {
            _ = try await AlarmManager.shared.schedule(id: config.id, configuration: alarmConfig)
        } catch {
            print("AlarmKit: failed to schedule alarm \(config.id): \(error.localizedDescription)")
        }
    }

    private func cancelAlarm(_ config: AlarmConfig) {
        guard #available(iOS 26.0, *) else { return }
        try? AlarmManager.shared.cancel(id: config.id)
    }

    func startMission(for config: AlarmConfig) {
        activeMission = config
        alarmState = .missionActive
        missionStartTime = Date()
        StepCounter.shared.beginCounting(downFrom: config.stepGoal)
        AudioManager.shared.playAlarmSound(named: config.soundName)
        WatchSessionManager.shared.sendMissionStart(stepsRequired: config.stepGoal)
        AlarmMissionActivity.shared.startActivity(stepsRequired: config.stepGoal)
    }

    func completeMission() {
        alarmState = .stopped
        AlarmMissionActivity.shared.endActivity()
        StepCounter.shared.stopCounting()
        AudioManager.shared.stopAlarmSound()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            activeMission = nil
            alarmState = .idle
        }
    }

    func cancelMission() {
        activeMission = nil
        snoozedDuration = nil
        missionStartTime = nil
        alarmState = .idle
        StepCounter.shared.stopCounting()
        AudioManager.shared.stopAlarmSound()
        AlarmMissionActivity.shared.endActivity()
    }

    var snoozedDuration: TimeInterval?
    private var snoozeTask: Task<Void, Never>?

    func snoozeAlarm(duration: TimeInterval) {
        // Snooze is valid both while the alarm is alerting (.firing) and
        // during the active mission (.missionActive) — the in-app flow jumps
        // straight to .missionActive on alert, so requiring .firing here
        // would silently ignore the very first snooze tap (QA MOO-87).
        guard let mission = activeMission,
              mission.snoozeEnabled,
              mission.snoozeRemaining > 0,
              alarmState == .firing || alarmState == .missionActive
        else { return }
        snoozeTask?.cancel()
        var updated = mission
        updated.snoozeRemaining -= 1
        snoozedDuration = duration
        activeMission = updated
        alarmState = .snoozed
        AudioManager.shared.stopAlarmSound()
        if let index = alarms.firstIndex(where: { $0.id == updated.id }) {
            alarms[index].snoozeRemaining = updated.snoozeRemaining
        }
        snoozeTask = Task { @MainActor [weak self, duration, updated] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self, self.alarmState == .snoozed else { return }
            self.fireAlarm(updated)
        }
    }

    var snoozeUsedThisMission: Bool {
        (activeMission?.snoozeRemaining ?? 1) <= 0
    }

    private func fireAlarm(_ config: AlarmConfig) {
        alarmState = .firing
        AudioManager.shared.playAlarmSound(named: config.soundName)
    }

    private func loadAlarms() {
        let data = UserDefaults(suiteName: Constants.appGroupIdentifier)?
            .data(forKey: "savedAlarms")
        alarms = (try? JSONDecoder().decode([AlarmConfig].self, from: data ?? Data())) ?? []
    }

    private func saveAlarms() {
        let data = try? JSONEncoder().encode(alarms)
        UserDefaults(suiteName: Constants.appGroupIdentifier)?
            .set(data, forKey: "savedAlarms")
    }

    private func observeAlarmUpdates() {
        guard #available(iOS 26.0, *) else { return }
        alarmObservationTask = Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                guard let self else { return }
                for alarm in alarms {
                    guard alarm.state == .alerting else { continue }
                    if let config = self.alarms.first(where: { $0.id == alarm.id }) {
                        self.startMission(for: config)
                    } else {
                        self.startMission(for: AlarmConfig(stepGoal: 30))
                    }
                }
            }
        }
    }
}
