import SwiftUI
import MooveKit

/// Warm Editorial hero slide: eyebrow, serif display title with optional
/// italic terracotta accent line, and a supporting subtitle.
///
/// Layout is clip-proof: multi-line text uses `fixedSize`, the display title
/// scales down on narrow devices, and vertical spacers use minimum lengths so
/// the subtitle can never be cut off by the page container.
public struct OnboardingSlide: View {
    let eyebrow: String
    let systemImage: String
    let title: String
    let accentTitle: String?
    let subtitle: String
    let subtitleAccessibilityIdentifier: String?

    public init(
        eyebrow: String,
        systemImage: String,
        title: String,
        accentTitle: String? = nil,
        subtitle: String,
        subtitleAccessibilityIdentifier: String? = nil
    ) {
        self.eyebrow = eyebrow
        self.systemImage = systemImage
        self.title = title
        self.accentTitle = accentTitle
        self.subtitle = subtitle
        self.subtitleAccessibilityIdentifier = subtitleAccessibilityIdentifier
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MooveSpacing.huge)

            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color.terracotta)
                .frame(width: 88, height: 88)
                .background(Circle().fill(Color.terracotta.opacity(0.12)))
                .overlay(Circle().stroke(Color.hairline, lineWidth: 1))

            Text(eyebrow)
                .mooveEyebrow()
                .padding(.top, MooveSpacing.xxxl)

            VStack(spacing: 0) {
                Text(title)
                    .font(MooveFont.largeTitle())
                    .foregroundStyle(Color.espresso)

                if let accentTitle {
                    Text(accentTitle)
                        .font(MooveFont.displayItalic(size: 46))
                        .foregroundStyle(Color.terracotta)
                }
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, MooveSpacing.lg)

            Group {
                if let subtitleAccessibilityIdentifier {
                    subtitleText.accessibilityIdentifier(subtitleAccessibilityIdentifier)
                } else {
                    subtitleText
                }
            }
            .padding(.top, MooveSpacing.xl)

            Spacer(minLength: MooveSpacing.huge)
        }
        .padding(.horizontal, MooveSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var subtitleText: some View {
        Text(subtitle)
            .font(MooveFont.body())
            .foregroundStyle(Color.taupe)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 320)
    }
}
