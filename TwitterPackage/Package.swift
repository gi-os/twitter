// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "TwitterPackage",
    platforms: [
        .iOS(.v27)
    ],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "ComposeFeature", targets: ["ComposeFeature"]),
        .library(name: "FeedFeature", targets: ["FeedFeature"]),
        .library(name: "MainFeature", targets: ["MainFeature"]),
        .library(name: "Models", targets: ["Models"]),
        .library(name: "ProfileFeature", targets: ["ProfileFeature"]),
        .library(name: "Routing", targets: ["Routing"]),
        .library(name: "SearchFeature", targets: ["SearchFeature"]),
        .library(name: "SignInFeature", targets: ["SignInFeature"]),
        .library(name: "TabStackFeature", targets: ["TabStackFeature"]),
        .library(name: "TweetEngagement", targets: ["TweetEngagement"]),
        .library(name: "TwitterClient", targets: ["TwitterClient"]),
        .library(name: "TwitterClientLive", targets: ["TwitterClientLive"]),
        .library(name: "TwitterUI", targets: ["TwitterUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.2"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.1"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.10.1")
    ],
    targets: [
        .target(
            name: "AppFeature",
            dependencies: [
                "MainFeature",
                "SignInFeature",
                "TwitterClientLive",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "ComposeFeature",
            dependencies: [
                "Routing",
                "TwitterUI",
                "TwitterClient",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "FeedFeature",
            dependencies: [
                "Routing",
                "TweetEngagement",
                "TwitterUI",
                "TwitterClient",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "MainFeature",
            dependencies: [
                "ComposeFeature",
                "TabStackFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "Models",
            dependencies: [
                .product(name: "IdentifiedCollections", package: "swift-identified-collections")
            ]
        ),
        .target(
            name: "ProfileFeature",
            dependencies: [
                "FeedFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "Routing",
            dependencies: [
                "Models"
            ]
        ),
        .target(
            name: "SearchFeature",
            dependencies: [
                "FeedFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "SignInFeature",
            dependencies: [
                "TwitterClient",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "TabStackFeature",
            dependencies: [
                "FeedFeature",
                "ProfileFeature",
                "SearchFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "TweetEngagement",
            dependencies: [
                "Models",
                "TwitterClient",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing")
            ]
        ),
        .target(
            name: "TwitterUI",
            dependencies: [
                "Models",
                "Routing"
            ]
        ),
        .target(
            name: "TwitterClient",
            dependencies: [
                "Models",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies")
            ]
        ),
        .target(
            name: "TwitterClientLive",
            dependencies: [
                "Models",
                "TwitterClient",
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .testTarget(
            name: "FeedFeatureTests",
            dependencies: [
                "FeedFeature",
                .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            ]
        ),
        .testTarget(
            name: "ProfileFeatureTests",
            dependencies: [
                "ProfileFeature"
            ]
        ),
        .testTarget(
            name: "SearchFeatureTests",
            dependencies: [
                "SearchFeature"
            ]
        ),
        .testTarget(
            name: "TweetEngagementTests",
            dependencies: [
                "TweetEngagement",
                .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            ]
        ),
        .testTarget(
            name: "TabStackFeatureTests",
            dependencies: [
                "TabStackFeature"
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
