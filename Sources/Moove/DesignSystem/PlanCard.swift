import SwiftUI
import MooveKit

public struct PlanCard: View {
    let title: String
    let price: String
    let trialDuration: String
    let features: [String]
    let isSelected: Bool
    let action: () -> Void

    public init(title: String, price: String, trialDuration: String, features: [String], isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.price = price
        self.trialDuration = trialDuration
        self.features = features
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
                }

                VStack(alignment: .leading, spacing: MooveSpacing.sm) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: MooveSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(MooveFont.caption())
                                .foregroundStyle(.brandSuccess)
                            Text(feature)
                                .font(MooveFont.subheadline())
                                .foregroundStyle(Color.taupe)
                        }
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
