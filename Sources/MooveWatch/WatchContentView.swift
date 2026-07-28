import SwiftUI

struct WatchContentView: View {
    @Environment(WatchStepCounter.self)
    private var stepCounter

    @Environment(WorkoutSessionManager.self)
    private var workoutManager

    @Environment(WatchSessionManager.self)
    private var sessionManager

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

            if stepCounter.isMissionActive {
                missionActiveView
            } else if stepCounter.isCompleted {
                completionView
            } else {
                idleView
            }
        }
    }

    @ViewBuilder
    private var missionActiveView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.terracotta)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.terracotta.opacity(0.12)))
                .overlay(Circle().stroke(Color.hairline, lineWidth: 1))

            Text("\(max(stepCounter.targetSteps - stepCounter.currentSteps, 0))")
                .font(MooveFont.stepCount(size: 56))
                .foregroundStyle(Color.espresso)
                .contentTransition(.numericText())

            Text("steps left")
                .font(MooveFont.caption2())
                .foregroundStyle(Color.taupe)

            ProgressView(
                value: Double(min(stepCounter.currentSteps, stepCounter.targetSteps)),
                total: Double(stepCounter.targetSteps)
            )
            .tint(.terracotta)

            HStack(spacing: 4) {
                Circle()
                    .fill(workoutManager.isSessionActive ? Color.brandSuccess : Color.terracotta)
                    .frame(width: 6, height: 6)
                Text(workoutManager.isSessionActive ? "Workout active" : "Starting workout...")
                    .font(MooveFont.caption2())
                    .foregroundStyle(Color.taupe)
            }
        }
        .padding()
    }

    private var completionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(MooveFont.title())
                .foregroundStyle(.brandSuccess)

            Text("Mission Complete")
                .font(MooveFont.headline())
                .foregroundStyle(Color.espresso)

            Text("Great job!")
                .font(MooveFont.caption2())
                .foregroundStyle(Color.taupe)
        }
        .padding()
    }

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.terracotta)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.terracotta.opacity(0.12)))
                .overlay(Circle().stroke(Color.hairline, lineWidth: 1))

            Text("Moove")
                .font(MooveFont.title3())
                .foregroundStyle(Color.espresso)

            Text("No active alarm")
                .font(MooveFont.caption2())
                .foregroundStyle(Color.taupe)

            if sessionManager.isReachable {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.brandSuccess)
                        .frame(width: 6, height: 6)
                    Text("Connected")
                        .font(MooveFont.caption2())
                        .foregroundStyle(Color.taupe)
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.terracotta)
                        .frame(width: 6, height: 6)
                    Text("Not connected")
                        .font(MooveFont.caption2())
                        .foregroundStyle(Color.taupe)
                }
            }
        }
    }
}
