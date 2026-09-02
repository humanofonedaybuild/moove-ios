import SwiftUI

public extension Color {
    static let cream = Color(red: 246 / 255, green: 242 / 255, blue: 234 / 255)
    static let creamSurface = Color(red: 251 / 255, green: 250 / 255, blue: 248 / 255)
    static let espresso = Color(red: 53 / 255, green: 44 / 255, blue: 39 / 255)
    static let taupe = Color(red: 132 / 255, green: 109 / 255, blue: 98 / 255)
    static let terracotta = Color(red: 214 / 255, green: 112 / 255, blue: 92 / 255)
    static let hairline = Color(red: 224 / 255, green: 220 / 255, blue: 209 / 255)
    static let sage = Color(red: 162 / 255, green: 179 / 255, blue: 152 / 255)
    static let loadingWordmark = Color(red: 245 / 255, green: 242 / 255, blue: 235 / 255)
    /// Barely-there shield used behind pinned bottom bars (paywall CTA)
    /// so the pinned section reads as part of the same soft surface.
    static let screenBottomShield = Color(red: 248 / 255, green: 245 / 255, blue: 239 / 255)

    static let brandPrimary = espresso
    static let brandAccent = terracotta
    static let brandSuccess = sage
    static let surfaceBackground = cream
}

public extension ShapeStyle where Self == Color {
    static var cream: Color { .cream }
    static var creamSurface: Color { .creamSurface }
    static var espresso: Color { .espresso }
    static var taupe: Color { .taupe }
    static var terracotta: Color { .terracotta }
    static var hairline: Color { .hairline }
    static var sage: Color { .sage }
    static var loadingWordmark: Color { .loadingWordmark }
    static var brandPrimary: Color { .brandPrimary }
    static var brandAccent: Color { .brandAccent }
    static var brandSuccess: Color { .brandSuccess }
}
