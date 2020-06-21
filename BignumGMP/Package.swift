// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Bignum",
    products: [
       .library(name: "Bignum", targets: ["Bignum"])
    ],
    dependencies: [
		.package(name: "CGMP", path: "../CGMP"),
		//.package(url: "https://github.com/mdaxter/CGMP.git", .branch("master"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Bignum",
            dependencies: ["CGMP"]),
        .testTarget(
            name: "BignumTests",
            dependencies: ["Bignum"]),
    ]
    
)
