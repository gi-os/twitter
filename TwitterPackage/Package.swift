// swift-tools-version: 6.4

import PackageDescription

let package = Package(
  name: "TwitterPackage",
  platforms: [
    .iOS(.v27),
  ],
  products: [
    .library(name: "AppFeature", targets: ["AppFeature"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.2"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
    .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.1"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.13.1"),
  ],
  targets: [
    .target(
      name: "XAPI",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
        .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
      ]
    ),
    .target(
      name: "AppFeature",
      dependencies: [
        "XAPI",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
