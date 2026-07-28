import SwiftUI
import MooveKit

public struct SnoozeChip: View {
    let minutes: Int
    let isUsed: Bool
    let action: () -> Void

    public init(minutes: Int, isUsed: Bool = false, action: @escaping () -> Void) {
        self.minutes = minutes
        self.isUsed = isUsed
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: MooveSpacing.xs) {
                Image(systemName: isUsed ? "moon.zzz.fill" : "moon.zzz")
                    .font(MooveFont.caption2())
                Text("\(minutes)m")
                    .font(MooveFont.subheadline(weight: .medium))
            }
            .padding(.horizontal, MooveSpacing.md)
            .padding(.vertical, MooveSpacing.sm)
            .foregroundStyle(isUsed ? Color.taupe : Color.cream)
            .background(isUsed ? Color.creamSurface : Color.espresso)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isUsed ? Color.hairline : Color.clear, lineWidth: 1)
            )
        }
        .disabled(isUsed)
        .buttonStyle(.plain)
    }
}
