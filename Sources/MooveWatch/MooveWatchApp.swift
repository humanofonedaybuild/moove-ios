import SwiftUI
import WatchKit

@main
struct MooveWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self)
    var appDelegate

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(WatchStepCounter.shared)
                .environment(WorkoutSessionManager.shared)
                .environment(WatchSessionManager.shared)
        }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchSessionManager.shared.activate()
        Task {
            _ = await WorkoutSessionManager.shared.requestAuthorization()
        }

        // Screenshot hook: land directly in the mission countdown.
        if ProcessInfo.processInfo.arguments.contains("-UITestingStartMission") {
            WatchStepCounter.shared.startMission(stepsRequired: 30)
        }
    }

    func applicationWillEnterForeground() {
        WatchSessionManager.shared.activate()
    }

    func handleRemoteNowPlayingActivity() {}
}
