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
        if ProcessInfo.processInfo.arguments.contains("-UITestingResetOnboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
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
            AppAlarmManager.shared.startMission(for: AlarmConfig(
                label: "Weekday Alarm", hour: 7, minute: 30, stepGoal: 30
            ))
        }

        AudioManager.shared.configureAudioSession()

        // SKTestSession must own StoreKit before the app touches it (unit
        // tests inject -DisableStoreKitInit via the scheme's test action).
        print("ARGPROBE disableStoreKitInit present: \(ProcessInfo.processInfo.arguments.contains("-DisableStoreKitInit")); args: \(ProcessInfo.processInfo.arguments)")
        if !ProcessInfo.processInfo.arguments.contains("-DisableStoreKitInit") {
            SubscriptionManager.shared.observeTransactionUpdates()
        }
        WatchSessionManager.shared.activate()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        StepCounter.shared.requestAuthorization()
    }
}
