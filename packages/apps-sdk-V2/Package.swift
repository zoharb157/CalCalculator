// swift-tools-version: 5.10

// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "SDK",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "SDK",
            targets: ["SDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", branch: "master"),
        .package(url: "https://github.com/ShipBook/ShipBookSDK-iOS.git", from: "1.2.3"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.1.2"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.0.0"),
        .package(url: "https://github.com/facebook/facebook-ios-sdk", from: "14.0.0"),
    ],
    targets: [
        .target(
            name: "SDK",
            dependencies: [
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "ShipBookSDK", package: "ShipBookSDK-iOS"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FacebookCore", package: "facebook-ios-sdk"),
            ]
        ),
    ]
)