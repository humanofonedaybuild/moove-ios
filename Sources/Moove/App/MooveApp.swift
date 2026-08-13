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

    @State private var route: LaunchRoute = .loading

    var body: some Scene {
        WindowGroup {
            Group {
                switch route {
                case .loading:
                    LoadingView()
                case .onboarding, .main:
                    ContentView()
                        .environment(AppAlarmManager.shared)
                        .environment(StepCounter.shared)
                        .environment(SubscriptionManager.shared)
                }
            }
            .animation(.easeInOut(duration: MooveAnimationDuration.standard), value: route)
            .task {
                await advanceFromLoading()
            }
        }
    }

    private func advanceFromLoading() async {
        if shouldSkipLoadingForActiveMission {
            route = .main
            return
        }

        let start = ContinuousClock.now
        await loadApp()
        let elapsed = ContinuousClock.now - start
        if elapsed < LaunchSequence.brandMoment {
            try? await Task.sleep(for: LaunchSequence.brandMoment - elapsed)
        }

        let next = LaunchSequence.routeAfterLoading(
            onboardingCompleted: LaunchSequence.isOnboardingCompleted(),
            holdLoadingScreen: LaunchSequence.shouldHoldLoadingScreen()
        )
        withAnimation(.easeInOut(duration: MooveAnimationDuration.standard)) {
            route = next
        }
    }

    private var shouldSkipLoadingForActiveMission: Bool {
        let manager = AppAlarmManager.shared
        return manager.activeMission != nil || manager.alarmState == .stopped
    }

    private func loadApp() async {
        // App essentials are warmed in AppDelegate.didFinishLaunching. Nothing
        // here should block the launch surface; the timer above only guarantees
        // the brand moment reads before routing to onboarding or the main app.
    }
}
