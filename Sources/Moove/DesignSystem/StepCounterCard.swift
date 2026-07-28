import SwiftUI
import MooveKit

public struct StepCounterCard: View {
    let stepsRemaining: Int
    let stepGoal: Int
    let progress: Double

    public init(stepsRemaining: Int, stepGoal: Int) {
        self.stepsRemaining = stepsRemaining
        self.stepGoal = stepGoal
        self.progress = stepGoal > 0 ? Double(stepGoal - stepsRemaining) / Double(stepGoal) : 0
    }

    public var body: some View {
        VStack(spacing: MooveSpacing.lg) {
            Text("\(stepsRemaining)")
                .font(MooveFont.stepCount())
                .foregroundStyle(Color.espresso)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: stepsRemaining)

            Text("steps remaining")
                .font(MooveFont.subheadline())
                .foregroundStyle(Color.taupe)

            ProgressView(value: progress)
                .tint(.terracotta)
                .background(Color.hairline)
                .clipShape(Capsule())
                .frame(height: 6)

            Text("\(Int(progress * 100))% complete")
                .font(MooveFont.caption())
                .foregroundStyle(Color.taupe)
        }
        .padding(MooveSpacing.xxl)
        .mooveCard(padding: 0)
    }
}
