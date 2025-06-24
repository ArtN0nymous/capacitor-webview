// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapacitorWebview",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "CapacitorWebview",
            targets: ["CustomWebviewPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "CustomWebviewPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/CustomWebviewPlugin"),
        .testTarget(
            name: "CustomWebviewPluginTests",
            dependencies: ["CustomWebviewPlugin"],
            path: "ios/Tests/CustomWebviewPluginTests")
    ]
)