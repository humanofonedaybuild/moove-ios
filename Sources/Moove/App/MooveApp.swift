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

    @State private var hasLoaded = false

    private var holdForCapture: Bool {
        // Screenshot/UI-test hook: keep the launch loading surface on screen so
        // capture tooling can grab a clean shot of the Moove monogram state.
        ProcessInfo.processInfo.arguments.contains("-UITestingHoldLoadingScreen")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(AppAlarmManager.shared)
                .environment(StepCounter.shared)
                .environment(SubscriptionManager.shared)
                .overlay {
                    if !hasLoaded {
                        LoadingView()
                            .transition(.opacity)
                    }
                }
                .task {
                    let minBrandMoment: Duration = .seconds(1.2)
                    let start = ContinuousClock.now
                    await loadApp()
                    let elapsed = ContinuousClock.now - start
                    if elapsed < minBrandMoment {
                        try? await Task.sleep(for: minBrandMoment - elapsed)
                    }
                    if !holdForCapture {
                        withAnimation(.easeInOut(duration: MooveAnimationDuration.standard)) {
                            hasLoaded = true
                        }
                    }
                }
        }
    }

    private func loadApp() async {
        // App essentials are warmed in AppDelegate.didFinishLaunching. Nothing
        // here should block the launch surface; the timer above only guarantees
        // the brand moment reads before the overlay fades.
    }
}
