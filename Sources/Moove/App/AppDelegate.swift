import UIKit
import MooveKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // UI-test/screenshot hook: start every launch from the first
        // onboarding page without shadowing later writes to the key.
        // Register defaults FIRST so @AppStorage picks up the correct value.
        if ProcessInfo.processInfo.arguments.contains(LaunchSequence.resetOnboardingArgument) {
            LaunchSequence.setOnboardingCompleted(false)
        }

        // Screenshot hook: seed representative alarms for the list screen.
        if ProcessInfo.processInfo.arguments.contains("-UITestingClearAlarms") {
            for alarm in AppAlarmManager.shared.alarms {
                AppAlarmManager.shared.deleteAlarm(alarm)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-UITestingSeedAlarms"),
           AppAlarmManager.shared.alarms.isEmpty {
            AppAlarmManager.shared.addAlarm(AlarmConfig(
                label: "Weekday Alarm", hour: 7, minute: 30,
                weekdays: [1, 2, 3, 4, 5], stepGoal: 30
            ))
            AppAlarmManager.shared.addAlarm(AlarmConfig(
                label: "Gym Day", hour: 6, minute: 15,
                weekdays: [2, 4], stepGoal: 50, snoozeEnabled: false
            ))
        }

        // Screenshot hook: land directly in the Start Walking mission.
        if ProcessInfo.processInfo.arguments.contains("-UITestingStartMission") {
            var steps = 30
            let args = ProcessInfo.processInfo.arguments
            if let idx = args.firstIndex(of: "-UITestingMissionSteps"),
               idx + 1 < args.count, let parsed = Int(args[idx + 1]) {
                steps = parsed
            }
            AppAlarmManager.shared.startMission(for: AlarmConfig(
                label: "QA Mission", hour: 7, minute: 30, stepGoal: steps
            ))
        }

        // QA hook (MOO-87): schedule a real AlarmKit alarm ~N seconds out so
        // end-to-end tests can verify system-level alarm delivery with the app
        // foregrounded, backgrounded, force-closed, or the device locked.
        // AlarmKit relative schedules are minute-granular, so the fire time is
        // rounded up to the next whole minute.
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-UITestingScheduleAlarmInSeconds"),
           idx + 1 < ProcessInfo.processInfo.arguments.count,
           let seconds = TimeInterval(ProcessInfo.processInfo.arguments[idx + 1]) {
            let fireDate = Date().addingTimeInterval(seconds)
            var components = Calendar.current.dateComponents([.hour, .minute], from: fireDate)
            if Calendar.current.component(.second, from: fireDate) > 5,
               let bumped = Calendar.current.date(byAdding: .minute, value: 1, to: fireDate) {
                components = Calendar.current.dateComponents([.hour, .minute], from: bumped)
            }
            AppAlarmManager.shared.addAlarm(AlarmConfig(
                label: "QA Scheduled Alarm",
                hour: components.hour ?? 7,
                minute: components.minute ?? 0,
                stepGoal: 10
            ))
        }

        // Screenshot/QA hook: present the premium paywall immediately on
        // launch (post-onboarding) so the paywall can be captured/verified
        // without driving through onboarding + Settings. Only fires when
        // onboarding is already completed; otherwise no-op.
        if ProcessInfo.processInfo.arguments.contains("-UITestingShowPaywall"),
           LaunchSequence.isOnboardingCompleted() {
            SubscriptionManager.shared.shouldShowPaywall = true
        }

        AudioManager.shared.configureAudioSession()

        // SKTestSession must own StoreKit before the app touches it (unit
        // tests inject -DisableStoreKitInit via the scheme's test action).
        if !ProcessInfo.processInfo.arguments.contains("-DisableStoreKitInit") {
            SubscriptionManager.shared.observeTransactionUpdates()
        }
        WatchSessionManager.shared.activate()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        StepCounter.shared.requestAuthorization()
        if !ProcessInfo.processInfo.arguments.contains("-DisableStoreKitInit") {
            Task { await SubscriptionManager.shared.refreshSubscriptionState() }
        }
    }
}
