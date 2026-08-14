import MooveKit
import SwiftUI

@main
struct MooveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    init() {
        // Warm Editorial: Cormorant Garamond navigation titles, espresso ink.
        let displayFont = UIFont(name: MooveFont.displayName, size: 34)
            ?? UIFont.systemFont(ofSize: 34, weight: .regular)
        let inlineFont = UIFont(name: MooveFont.displayName, size: 20)
            ?? UIFont.systemFont(ofSize: 20, weight: .regular)
        let espresso = UIColor(Color.espresso)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(Color.cream)
        appearance.largeTitleTextAttributes = [.font: displayFont, .foregroundColor: espresso]
        appearance.titleTextAttributes = [.font: inlineFont, .foregroundColor: espresso]

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(AppAlarmManager.shared)
                .environment(StepCounter.shared)
                .environment(SubscriptionManager.shared)
        }
    }
}
