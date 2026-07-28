import CoreGraphics

public enum MooveSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let xxxl: CGFloat = 32
    public static let huge: CGFloat = 48
}

public enum MooveCornerRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 14
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 28
    public static let full: CGFloat = 9999
}

public enum MooveShadow {
    public struct Config: Sendable {
        public let opacity: Double
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat

        public init(opacity: Double, radius: CGFloat, x: CGFloat = 0, y: CGFloat) {
            self.opacity = opacity
            self.radius = radius
            self.x = x
            self.y = y
        }
    }

    public static let sm = Config(opacity: 0.06, radius: 4, y: 2)
    public static let md = Config(opacity: 0.08, radius: 8, y: 4)
    public static let lg = Config(opacity: 0.12, radius: 16, y: 8)
}

public enum MooveAnimationDuration {
    public static let standard: Double = 0.35
    public static let celebration: Double = 0.5
    public static let quick: Double = 0.2
}
