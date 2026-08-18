import SwiftUI
import CoreMotion
import AlarmKit
import MooveKit

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var currentPage: Int
    @State private var isRequestingPermissions = false

    private let totalPages = 3

    init(isCompleted: Binding<Bool>) {
        _isCompleted = isCompleted

        // Launch-argument hook used by UI tests and screenshot captures to
        // land directly on a specific page: `-onboardingStartPage <0-2>`.
        var startPage = 0
        let arguments = ProcessInfo.processInfo.arguments
        if let flagIndex = arguments.firstIndex(of: "-onboardingStartPage"),
           flagIndex + 1 < arguments.count,
           let page = Int(arguments[flagIndex + 1]),
           (0..<3).contains(page) {
            startPage = page
        }
        _currentPage = State(initialValue: startPage)
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    HowItWorksPage()
                        .tag(1)
                    PermissionsPage(
                        isRequestingPermissions: $isRequestingPermissions
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Pinned outside the TabView so the primary action can never
                // be clipped or pushed off screen by page content.
                bottomBar
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: MooveSpacing.xl) {
            HStack(spacing: MooveSpacing.sm) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? Color.terracotta : Color.hairline)
                        .frame(width: currentPage == index ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                }
            }
            .accessibilityIdentifier("onboarding.pageIndicator")

            Button(action: nextAction) {
                Text(currentPage < totalPages - 1 ? "Continue" : "Get Started")
            }
            .mooveButton(.primary, isEnabled: !isRequestingPermissions)
            .disabled(isRequestingPermissions)
            .padding(.horizontal, MooveSpacing.xxl)
            .accessibilityIdentifier("onboarding.continueButton")

            if currentPage < totalPages - 1 {
                Button("Skip") {
                    completeOnboarding()
                }
                .font(MooveFont.subheadline())
                .foregroundStyle(Color.taupe)
                .frame(width: 200, height: 44)
                .accessibilityIdentifier("onboarding.skipButton")
            }
        }
        .padding(.top, MooveSpacing.md)
        .padding(.bottom, MooveSpacing.xl)
    }

    private func nextAction() {
        if currentPage < totalPages - 1 {
            withAnimation {
                currentPage += 1
            }
        } else {
            requestPermissionsAndComplete()
        }
    }

    @MainActor
    private func requestPermissionsAndComplete() {
        guard !isRequestingPermissions else { return }
        isRequestingPermissions = true

        Task { @MainActor in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    _ = await AppAlarmManager.shared.requestAuthorizationIfNeeded()
                }

                group.addTask {
                    guard CMPedometer.isStepCountingAvailable() else { return }
                    let pedometer = CMPedometer()
                    let start = Date().addingTimeInterval(-120)
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        let once = ContinuationOnce(continuation)
                        pedometer.queryPedometerData(from: start, to: Date()) { _, _ in
                            _ = pedometer
                            once.resume()
                        }
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            once.resume()
                        }
                    }
                }

                _ = await group.next()
                group.cancelAll()
            }

            isRequestingPermissions = false
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: MooveAnimationDuration.standard)) {
            isCompleted = true
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var body: some View {
        OnboardingSlide(
            eyebrow: "The no-snooze alarm",
            systemImage: "alarm.fill",
            title: "Wake up.",
            accentTitle: "Walk.",
            subtitle: "Moove won't stop until you're out of bed and moving. No snooze, no shortcuts — just movement.",
            subtitleAccessibilityIdentifier: "onboarding.welcome.subtitle"
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.page.welcome")
    }
}

// MARK: - Page 2: How It Works

private struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MooveSpacing.huge)

            Text("How it works")
                .mooveEyebrow()

            Text("Three steps to a\nbetter morning")
                .font(MooveFont.title())
                .foregroundStyle(Color.espresso)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, MooveSpacing.md)

            VStack(spacing: 0) {
                StepRow(number: "01", title: "Set your alarm",
                        description: "Choose a time and how many steps you need to take.")

                Rectangle()
                    .fill(Color.hairline)
                    .frame(height: 1)

                StepRow(number: "02", title: "Get up and walk",
                        description: "When it fires, the only way to stop it is to start walking.")

                Rectangle()
                    .fill(Color.hairline)
                    .frame(height: 1)

                StepRow(number: "03", title: "Hit your goal",
                        description: "Complete your steps and the alarm stops. No snooze, no shortcuts.")
            }
            .padding(.top, MooveSpacing.xxxl)

            Spacer(minLength: MooveSpacing.huge)
        }
        .padding(.horizontal, MooveSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.page.howItWorks")
    }
}

private struct StepRow: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: MooveSpacing.xl) {
            Text(number)
                .font(MooveFont.title3())
                .foregroundStyle(Color.terracotta)
                .frame(width: 40, alignment: .leading)

            VStack(alignment: .leading, spacing: MooveSpacing.xs) {
                Text(title)
                    .font(MooveFont.headline())
                    .foregroundStyle(Color.espresso)

                Text(description)
                    .font(MooveFont.subheadline())
                    .foregroundStyle(Color.taupe)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, MooveSpacing.xl)
    }
}

// MARK: - Page 3: Permissions

private struct PermissionsPage: View {
    @Binding var isRequestingPermissions: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MooveSpacing.huge)

            Text("One more thing")
                .mooveEyebrow()

            Text("Walk to\nwake up")
                .font(MooveFont.title())
                .foregroundStyle(Color.espresso)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, MooveSpacing.md)

            VStack(spacing: MooveSpacing.lg) {
                PermissionCard(
                    icon: "alarm.fill",
                    title: "Alarms",
                    description: "Lets Moove fire your alarm through Focus, Do Not Disturb, and silent mode."
                )

                PermissionCard(
                    icon: "figure.walk",
                    title: "Motion & Fitness",
                    description: "Counts your wake-up steps so the alarm knows when you're up."
                )
            }
            .padding(.top, MooveSpacing.xxxl)

            Text("You can change these later in Settings.")
                .font(MooveFont.caption())
                .foregroundStyle(Color.taupe)
                .padding(.top, MooveSpacing.xxl)

            Spacer(minLength: MooveSpacing.huge)
        }
        .padding(.horizontal, MooveSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.page.permissions")
        .overlay {
            if isRequestingPermissions {
                Color.cream.opacity(0.7)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Setting up...")
                            .tint(.espresso)
                            .font(MooveFont.subheadline())
                            .foregroundStyle(Color.espresso)
                            .padding(MooveSpacing.xxl)
                            .mooveCard()
                    }
            }
        }
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: MooveSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.terracotta)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.terracotta.opacity(0.12)))

            VStack(alignment: .leading, spacing: MooveSpacing.xs) {
                Text(title)
                    .font(MooveFont.headline())
                    .foregroundStyle(Color.espresso)

                Text(description)
                    .font(MooveFont.subheadline())
                    .foregroundStyle(Color.taupe)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(MooveSpacing.xl)
        .mooveCard(padding: 0)
    }
}

private final class ContinuationOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    private let continuation: CheckedContinuation<Void, Never>

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        continuation.resume()
    }
}
