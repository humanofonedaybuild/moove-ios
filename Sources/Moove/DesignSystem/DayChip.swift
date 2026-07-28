import SwiftUI
import MooveKit

public struct DayChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    public init(label: String, isSelected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(MooveFont.footnote(weight: isSelected ? .semibold : .regular))
                .frame(width: 40, height: 40)
                .foregroundStyle(isSelected ? Color.cream : Color.espresso)
                .background(isSelected ? Color.espresso : Color.creamSurface)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(isSelected ? Color.clear : Color.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
    }
}
