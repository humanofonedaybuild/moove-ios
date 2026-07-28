import SwiftUI
import MooveKit

struct StepCounterView: View {
    @Environment(StepCounter.self)
    private var stepCounter

    var body: some View {
        let remaining = max(stepCounter.targetStepCount - stepCounter.currentStepCount, 0)
        let progress = stepCounter.targetStepCount > 0
            ? Double(stepCounter.currentStepCount) / Double(stepCounter.targetStepCount)
            : 0.0

        return HStack(spacing: MooveSpacing.md) {
            Image(systemName: "figure.walk")
                .font(MooveFont.title2())
                .foregroundStyle(Color.terracotta)

            VStack(alignment: .leading, spacing: MooveSpacing.xs) {
                Text("\(remaining)")
                    .font(MooveFont.title())
                    .foregroundStyle(Color.espresso)
                    .contentTransition(.numericText(value: Double(remaining)))

                Text("steps remaining")
                    .font(MooveFont.caption())
                    .foregroundStyle(Color.taupe)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                ProgressView(value: min(progress, 1.0))
                    .tint(.terracotta)
                    .background(Color.hairline)
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: MooveAnimationDuration.standard), value: progress)
                    .frame(width: 80)

                Text("\(Int(progress * 100))%")
                    .font(MooveFont.caption2())
                    .foregroundStyle(Color.taupe)
            }
        }
        .padding(MooveSpacing.lg)
        .mooveCard(padding: 0)
    }
}
