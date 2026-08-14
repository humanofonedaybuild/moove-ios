import Foundation

@frozen
public enum LaunchRoute: Equatable, Sendable {
    case loading
    case onboarding
    case main
}

public enum LaunchSequence {
    public static let onboardingCompletedKey = "hasCompletedOnboarding"
    public static let holdLoadingScreenArgument = "-UITestingHoldLoadingScreen"
    public static let resetOnboardingArgument = "-UITestingResetOnboarding"
    public static let brandMoment: Duration = .seconds(1.2)

    public static func isOnboardingCompleted(
        defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.bool(forKey: onboardingCompletedKey)
    }

    public static func setOnboardingCompleted(
        _ completed: Bool,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(completed, forKey: onboardingCompletedKey)
    }

    public static func initialRoute(
        onboardingCompleted: Bool,
        hasActiveMission: Bool = false
    ) -> LaunchRoute {
        if hasActiveMission { return .main }
        return onboardingCompleted ? .main : .onboarding
    }

    public static func routeAfterLoading(
        onboardingCompleted: Bool,
        holdLoadingScreen: Bool = false
    ) -> LaunchRoute {
        if holdLoadingScreen { return .loading }
        return onboardingCompleted ? .main : .onboarding
    }

    public static func shouldHoldLoadingScreen(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        arguments.contains(holdLoadingScreenArgument)
    }
}
