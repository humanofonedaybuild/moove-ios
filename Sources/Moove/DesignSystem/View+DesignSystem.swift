import SwiftUI
import MooveKit

public struct MooveCardStyle: ViewModifier {
    let padding: CGFloat

    public init(padding: CGFloat = MooveSpacing.xl) {
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.creamSurface)
            .clipShape(RoundedRectangle(cornerRadius: MooveCornerRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MooveCornerRadius.lg, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            }
            .mooveShadow(MooveShadow.sm)
    }
}

public struct MooveListRowStyle: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .font(MooveFont.body())
            .foregroundStyle(Color.espresso)
            .listRowBackground(Color.cream)
            .listRowSeparatorTint(Color.hairline)
    }
}

/// Inset form field on a card: cream well with a hairline border.
public struct MooveFieldStyle: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .background(Color.cream, in: RoundedRectangle(cornerRadius: MooveCornerRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MooveCornerRadius.sm, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            }
    }
}

public extension View {
    func mooveShadow(_ config: MooveShadow.Config) -> some View {
        shadow(color: .espresso.opacity(config.opacity), radius: config.radius, x: config.x, y: config.y)
    }

    func mooveCard(padding: CGFloat = MooveSpacing.xl) -> some View {
        modifier(MooveCardStyle(padding: padding))
    }

    func mooveListRow() -> some View {
        modifier(MooveListRowStyle())
    }

    func mooveField() -> some View {
        modifier(MooveFieldStyle())
    }

    func mooveScreenBackground() -> some View {
        background(Color.cream.ignoresSafeArea())
    }

    func mooveEyebrow() -> some View {
        font(MooveFont.eyebrow())
            .textCase(.uppercase)
            .tracking(3.3)
            .foregroundStyle(Color.taupe)
    }
}
