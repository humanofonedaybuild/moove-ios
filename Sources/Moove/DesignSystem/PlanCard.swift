import SwiftUI
import MooveKit

public struct PlanCard: View {
    let title: String
    let price: String
    let trialDuration: String
    let savingsNote: String?
    let isSelected: Bool
    let action: () -> Void

    public init(title: String, price: String, trialDuration: String, savingsNote: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.price = price
        self.trialDuration = trialDuration
        self.savingsNote = savingsNote
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: MooveSpacing.lg) {
                VStack(spacing: MooveSpacing.xs) {
                    Text(title)
                        .font(MooveFont.headline())
                        .foregroundStyle(Color.espresso)

                    Text(price)
                        .font(MooveFont.largeTitle())
                        .foregroundStyle(Color.espresso)

                    Text(trialDuration)
                        .font(MooveFont.subheadline())
                        .foregroundStyle(Color.taupe)

                    if let savingsNote {
                        Text(savingsNote)
                            .font(MooveFont.caption())
                            .foregroundStyle(Color.terracotta)
                    }
                }

                Text(isSelected ? "Selected" : "Choose Plan")
                    .font(MooveFont.headline())
                    .foregroundStyle(isSelected ? Color.espresso : Color.cream)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(isSelected ? Color.creamSurface : Color.espresso)
                    .clipShape(Capsule())
                    .overlay {
                        if isSelected {
                            Capsule().stroke(Color.hairline, lineWidth: 1)
                        }
                    }
            }
            .padding(MooveSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: MooveCornerRadius.lg, style: .continuous)
                    .stroke(isSelected ? Color.terracotta.opacity(0.4) : Color.hairline, lineWidth: isSelected ? 2 : 1)
            )
            .background(Color.creamSurface)
            .clipShape(RoundedRectangle(cornerRadius: MooveCornerRadius.lg, style: .continuous))
            .mooveShadow(MooveShadow.sm)
        }
        .buttonStyle(.plain)
    }
}
