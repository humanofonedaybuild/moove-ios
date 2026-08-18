// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Moove",
    platforms: [
        .iOS(.v18),
        .watchOS(.v9),
    ],
    products: [
        .library(
            name: "MooveKit",
            targets: ["MooveKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/RevenueCat/purchases-ios", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "MooveKit",
            dependencies: [
                .product(name: "RevenueCat", package: "purchases-ios"),
            ]
        ),
        .testTarget(
            name: "MooveTests",
            dependencies: ["MooveKit"],
            // StoreKitTest requires a signed host process; it cannot
            // intercept StoreKit from the unsigned `swift test` runner on
            // macOS (Product.products returns 0). Those tests run under
            // `xcodebuild test -scheme Moove` on the simulator instead,
            // where the StoreKit config is wired via project.yml.
            exclude: ["SubscriptionStoreKitTests.swift"]
        )
    ]
)
