import SwiftUI
import MooveKit

public struct MooveButtonStyle: ButtonStyle {
    public enum Style {
        case primary
        case secondary
        case ghost
    }

    let style: Style
    let isEnabled: Bool

    public init(_ style: Style = .primary, isEnabled: Bool = true) {
        self.style = style
        self.isEnabled = isEnabled
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MooveFont.headline())
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(backgroundView(configuration))
            .clipShape(Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: MooveAnimationDuration.quick), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .cream
        case .secondary, .ghost: return .espresso
        }
    }

    @ViewBuilder
    private func backgroundView(_ configuration: Configuration) -> some View {
        switch style {
        case .primary:
            Color.espresso.opacity(configuration.isPressed ? 0.84 : 1)
        case .secondary:
            Capsule()
                .fill(Color.creamSurface)
                .overlay {
                    Capsule().stroke(Color.hairline, lineWidth: 1)
                }
        case .ghost:
            Color.clear
        }
    }
}

public extension View {
    func mooveButton(_ style: MooveButtonStyle.Style = .primary, isEnabled: Bool = true) -> some View {
        buttonStyle(MooveButtonStyle(style, isEnabled: isEnabled))
    }
}
