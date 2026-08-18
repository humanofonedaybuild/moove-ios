import Foundation
import AlarmKit
import Observation
import MooveKit

@Observable
@MainActor
final class AppAlarmManager {
    static let shared = AppAlarmManager()

    var alarms: [AlarmConfig] = []
    var activeMission: AlarmConfig?
    var alarmState: AlarmState = .idle
    var missionStartTime: Date?

    private var alarmObservationTask: Task<Void, Never>?

    private init() {
        loadAlarms()
        observeAlarmUpdates()
    }

    // MARK: - Alarm CRUD

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
        let refreshed = alarms
        alarms = refreshed
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

    // MARK: - Authorization

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
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

    // MARK: - Scheduling

    private func scheduleAlarm(_ config: AlarmConfig) async {
        guard config.isEnabled else { return }
        guard SubscriptionManager.shared.canUseAlarms else {
            print("AlarmKit: subscription locked — alarm \(config.id) was not scheduled")
            return
        }
        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else {
            print("AlarmKit: authorization denied — alarm \(config.id) was not scheduled")
            return
        }

        let alarmConfig: AlarmManager.AlarmConfiguration<MooveAlarmMetadata> = .make(for: config)
        do {
            _ = try await AlarmManager.shared.schedule(id: config.id, configuration: alarmConfig)
        } catch {
            print("AlarmKit: failed to schedule alarm \(config.id): \(error.localizedDescription)")
        }
    }

    // MARK: - Cancellation

    private func cancelAlarm(_ config: AlarmConfig) {
        try? AlarmManager.shared.cancel(id: config.id)
    }

    func cancelAlarm(with id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
        cancelMission()
    }

    func suspendAllScheduledAlarms() {
        for config in alarms where config.isEnabled {
            cancelAlarm(config)
        }
    }

    func rescheduleEnabledAlarms() async {
        for config in alarms where config.isEnabled {
            await scheduleAlarm(config)
        }
    }

    // MARK: - Mission lifecycle

    func startMission(for config: AlarmConfig) {
        guard SubscriptionManager.shared.canUseAlarms else {
            try? AlarmManager.shared.stop(id: config.id)
            AudioManager.shared.stopAlarmSound()
            SubscriptionManager.shared.presentRequiredPaywall()
            return
        }
        if let active = activeMission, active.id == config.id, alarmState == .missionActive {
            return
        }
        try? AlarmManager.shared.stop(id: config.id)
        activeMission = config
        alarmState = .missionActive
        missionStartTime = Date()
        StepCounter.shared.beginCounting(downFrom: config.stepGoal)
        AudioManager.shared.playAlarmSound(named: config.soundName)
        WatchSessionManager.shared.sendMissionStart(stepsRequired: config.stepGoal)
        AlarmMissionActivity.shared.startActivity(stepsRequired: config.stepGoal)
    }

    func completeMission() {
        if let config = activeMission {
            try? AlarmManager.shared.stop(id: config.id)
        }
        alarmState = .stopped
        AlarmMissionActivity.shared.endActivity()
        StepCounter.shared.stopCounting()
        AudioManager.shared.stopAlarmSound()
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

    // MARK: - Snooze

    var snoozedDuration: TimeInterval?
    private var snoozeTask: Task<Void, Never>?

    func snoozeAlarm(duration: TimeInterval) {
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
            self.startMission(for: updated)
        }
    }

    var snoozeUsedThisMission: Bool {
        (activeMission?.snoozeRemaining ?? 1) <= 0
    }

    // MARK: - Fire

    private func fireAlarm(_ config: AlarmConfig) {
        guard SubscriptionManager.shared.canUseAlarms else {
            cancelAlarm(config)
            SubscriptionManager.shared.presentRequiredPaywall()
            return
        }
        startMission(for: config)
    }

    // MARK: - Persistence

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

    // MARK: - AlarmKit observation

    private func observeAlarmUpdates() {
        alarmObservationTask = Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                guard let self else { return }
                for alarm in alarms {
                    switch alarm.state {
                    case .alerting:
                        if let config = self.alarms.first(where: { $0.id == alarm.id }) {
                            if SubscriptionManager.shared.canUseAlarms {
                                self.fireAlarm(config)
                            } else {
                                self.cancelAlarm(config)
                                SubscriptionManager.shared.presentRequiredPaywall()
                            }
                        } else if SubscriptionManager.shared.canUseAlarms {
                            self.fireAlarm(AlarmConfig(stepGoal: 30))
                        }
                    case .scheduled:
                        break
                    case .countdown:
                        break
                    case .paused:
                        break
                    @unknown default:
                        break
                    }
                }
            }
        }
    }
}
