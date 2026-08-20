import SwiftUI
import MooveKit

struct AlarmMissionView: View {
    @Environment(AppAlarmManager.self)
    private var alarmManager

    @Environment(StepCounter.self)
    private var stepCounter

    @State private var completionAnimating = false
    @State private var hasTriggeredHaptic = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if alarmManager.alarmState == .stopped {
                completionView
            } else if alarmManager.alarmState == .snoozed {
                snoozedView
            } else {
                missionActiveView
            }

            Spacer()
        }
        .padding(.horizontal, MooveSpacing.xxxl)
        .mooveScreenBackground()
        .onAppear {
            if alarmManager.alarmState == .stopped, !completionAnimating {
                triggerCompletionHaptic()
                withAnimation(.spring(response: MooveAnimationDuration.celebration, dampingFraction: 0.5)) {
                    completionAnimating = true
                }
            }
        }
        .onChange(of: alarmManager.alarmState) { _, newState in
            if newState == .stopped {
                triggerCompletionHaptic()
                withAnimation(.spring(response: MooveAnimationDuration.celebration, dampingFraction: 0.5)) {
                    completionAnimating = true
                }
            }
        }
    }

    @ViewBuilder
    private var snoozedView: some View {
        VStack(spacing: MooveSpacing.xxxl) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(Color.taupe)
                .frame(width: 96, height: 96)
                .background(Circle().fill(Color.taupe.opacity(0.1)))
                .overlay(Circle().stroke(Color.hairline, lineWidth: 1))

            VStack(spacing: MooveSpacing.sm) {
                Text("Snoozed")
                    .font(MooveFont.largeTitle())
                    .foregroundStyle(Color.espresso)

                if let duration = alarmManager.snoozedDuration {
                    Text("Alarm will ring again in \(Int(duration / 60)) minutes")
                        .font(MooveFont.subheadline())
                        .foregroundStyle(Color.taupe)
                } else {
                    Text("Alarm will ring again soon")
                        .font(MooveFont.subheadline())
                        .foregroundStyle(Color.taupe)
                }
            }

            Text("Step counter paused during snooze")
                .font(MooveFont.caption())
                .foregroundStyle(Color.taupe)
        }
    }

    @ViewBuilder
    private var missionActiveView: some View {
        VStack(spacing: MooveSpacing.xxxl) {
            headerSection

            StepCounterCard(
                stepsRemaining: max(stepCounter.targetStepCount - stepCounter.currentStepCount, 0),
                stepGoal: stepCounter.targetStepCount
            )

            #if DEBUG
            // QA hook (MOO-87): the simulator produces no pedometer or shake
            // data, so UI tests drive the countdown through this button.
            if ProcessInfo.processInfo.arguments.contains("-UITestingStepSim") {
                Button("Simulate 10 steps") {
                    StepCounter.shared.debugSimulateSteps(10)
                }
                .font(MooveFont.caption())
                .foregroundStyle(Color.taupe)
                .accessibilityIdentifier("mission.debugStepButton")
            }
            #endif

            snoozeSection
        }
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            Image(systemName: "figure.walk")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.terracotta)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.terracotta.opacity(0.12)))
                .overlay(Circle().stroke(Color.hairline, lineWidth: 1))

            Text("Alarm mission")
                .mooveEyebrow()
                .padding(.top, MooveSpacing.xxl)

            VStack(spacing: 0) {
                Text("Wake up.")
                    .font(MooveFont.largeTitle())
                    .foregroundStyle(Color.espresso)

                Text("Walk.")
                    .font(MooveFont.displayItalic(size: 46))
                    .foregroundStyle(Color.terracotta)
            }
            .padding(.top, MooveSpacing.md)

            Text(stepCounterPhaseText)
                .font(MooveFont.subheadline())
                .foregroundStyle(Color.taupe)
                .padding(.top, MooveSpacing.md)
        }
    }

    @ViewBuilder
    private var snoozeSection: some View {
        if let mission = alarmManager.activeMission, mission.snoozeEnabled {
            SnoozeChip(
                minutes: configuredSnoozeMinutes,
                isUsed: alarmManager.snoozeUsedThisMission
            ) {
                buttonFeedback()
                alarmManager.snoozeAlarm(duration: AppSettings.load().snoozeDuration)
            }
        }
    }

    private var configuredSnoozeMinutes: Int {
        Int(AppSettings.load().snoozeDuration / 60)
    }

    private var completionView: some View {
        VStack(spacing: MooveSpacing.xxl) {
            checkmarkBadge

            VStack(spacing: MooveSpacing.sm) {
                Text("Good Morning!")
                    .font(MooveFont.largeTitle())
                    .foregroundStyle(Color.espresso)

                Text("Mission complete")
                    .font(MooveFont.subheadline())
                    .foregroundStyle(Color.taupe)
            }

            statsRow

            Button(action: {
                buttonFeedback()
                alarmManager.cancelMission()
            }) {
                Text("Start Your Day")
            }
            .accessibilityIdentifier("Start Your Day")
            .mooveButton(.primary)
            .padding(.horizontal, MooveSpacing.sm)
            .opacity(completionAnimating ? 1 : 0)
            .offset(y: completionAnimating ? 0 : 20)
            .animation(.easeOut(duration: MooveAnimationDuration.celebration).delay(0.35), value: completionAnimating)
        }
    }

    private var checkmarkBadge: some View {
        ZStack {
            Circle()
                .stroke(.brandSuccess.opacity(0.2), lineWidth: 4)
                .frame(width: 120, height: 120)
                .scaleEffect(completionAnimating ? 1.1 : 0.95)
                .opacity(completionAnimating ? 0 : 0.4)
                .animation(
                    completionAnimating
                        ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: completionAnimating
                )

            Circle()
                .fill(.brandSuccess.opacity(0.1))
                .frame(width: 100, height: 100)

            Image(systemName: "checkmark.circle.fill")
                .font(MooveFont.stepCount(size: 64))
                .foregroundStyle(.brandSuccess)
                .scaleEffect(completionAnimating ? 1.0 : 0.5)
                .opacity(completionAnimating ? 1.0 : 0.0)
                .animation(
                    .spring(response: MooveAnimationDuration.celebration, dampingFraction: 0.5),
                    value: completionAnimating
                )
        }
    }

    private var statsRow: some View {
        HStack(spacing: MooveSpacing.xxl) {
            statItem(
                icon: "figure.walk",
                value: "\(stepCounter.targetStepCount)",
                label: "Steps"
            )

            Rectangle()
                .fill(Color.hairline)
                .frame(width: 1, height: 40)

            statItem(
                icon: "clock",
                value: elapsedTimeString,
                label: "Time"
            )
        }
        .padding(.horizontal, MooveSpacing.xxl)
        .padding(.vertical, MooveSpacing.lg)
        .mooveCard(padding: 0)
        .opacity(completionAnimating ? 1 : 0)
        .offset(y: completionAnimating ? 0 : 20)
        .animation(.easeOut(duration: MooveAnimationDuration.celebration).delay(0.2), value: completionAnimating)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: MooveSpacing.xs) {
            Image(systemName: icon)
                .font(MooveFont.title3())
                .foregroundStyle(Color.terracotta)

            Text(value)
                .font(MooveFont.title3())
                .foregroundStyle(Color.espresso)

            Text(label)
                .font(MooveFont.caption())
                .foregroundStyle(Color.taupe)
        }
        .frame(minWidth: 80)
    }

    private var stepCounterPhaseText: String {
        let remaining = stepCounter.targetStepCount - stepCounter.currentStepCount
        if remaining <= 0 {
            return "Mission complete"
        }
        return "\(remaining) steps remaining"
    }

    private var elapsedTimeString: String {
        guard let startTime = alarmManager.missionStartTime else { return "--" }
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private func buttonFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.7)
    }

    private func triggerCompletionHaptic() {
        guard !hasTriggeredHaptic else { return }
        hasTriggeredHaptic = true
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
