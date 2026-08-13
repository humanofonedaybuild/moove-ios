import SwiftUI

public enum MooveFont {
    public static let displayName = "CormorantGaramond-Light"
    public static let displayItalicName = "CormorantGaramond-LightItalic"
    public static let bodyName = "Manrope-ExtraLight"
    public static let wordmarkName = "Poppins-SemiBold"

    public static func largeTitle(weight: Font.Weight = .regular) -> Font {
        display(size: 42, weight: weight, relativeTo: .largeTitle)
    }

    public static func title(weight: Font.Weight = .regular) -> Font {
        display(size: 34, weight: weight, relativeTo: .title)
    }

    public static func title2(weight: Font.Weight = .regular) -> Font {
        display(size: 28, weight: weight, relativeTo: .title2)
    }

    public static func title3(weight: Font.Weight = .regular) -> Font {
        display(size: 24, weight: weight, relativeTo: .title3)
    }

    public static func headline(weight: Font.Weight = .semibold) -> Font {
        bodyFont(size: 17, weight: weight, relativeTo: .headline)
    }

    public static func body(weight: Font.Weight = .regular) -> Font {
        bodyFont(size: 17, weight: weight, relativeTo: .body)
    }

    public static func callout(weight: Font.Weight = .regular) -> Font {
        bodyFont(size: 16, weight: weight, relativeTo: .callout)
    }

    public static func subheadline(weight: Font.Weight = .regular) -> Font {
        bodyFont(size: 15, weight: weight, relativeTo: .subheadline)
    }

    public static func footnote(weight: Font.Weight = .regular) -> Font {
        bodyFont(size: 13, weight: weight, relativeTo: .footnote)
    }

    public static func caption(weight: Font.Weight = .regular) -> Font {
        bodyFont(size: 12, weight: weight, relativeTo: .caption)
    }

    public static func caption2(weight: Font.Weight = .regular) -> Font {
        bodyFont(size: 11, weight: weight, relativeTo: .caption2)
    }

    public static func eyebrow() -> Font {
        .custom(bodyName, size: 11, relativeTo: .caption).weight(.medium)
    }

    public static func displayItalic(size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(displayItalicName, size: size, relativeTo: style)
    }

    public static func stepCount(size: CGFloat = 80) -> Font {
        .custom(displayName, size: size, relativeTo: .largeTitle)
    }

    public static func wordmark(size: CGFloat = 28) -> Font {
        .custom(wordmarkName, size: size, relativeTo: .title2)
    }

    public static func timePicker(size: CGFloat = 48) -> Font {
        .custom(displayName, size: size, relativeTo: .largeTitle)
    }

    private static func display(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) -> Font {
        .custom(displayName, size: size, relativeTo: style).weight(weight)
    }

    private static func bodyFont(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) -> Font {
        .custom(bodyName, size: size, relativeTo: style).weight(weight)
    }
}
