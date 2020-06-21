// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WSS_SendWithCheck",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", .branch("master")),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .branch("master")),
        .package(name: "Bignum", path: "./BignumGMP")
        
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "WSS_SendWithCheck",
            dependencies: ["BigInt", "Bignum", "CryptoSwift"]),
        .testTarget(
            name: "WSS_SendWithCheckTests",
            dependencies: ["WSS_SendWithCheck"]),
    ]
)
