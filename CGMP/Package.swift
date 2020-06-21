// swift-tools-version:5.3

import PackageDescription 

let package = Package(
	name: "CGMP",
	products: [
       .library(name: "CGMP", targets: ["CGMP"])
    ],
    targets: [        
        .target(
            name: "CGMP"
       ),
        .testTarget(
            name: "CGMPTests",
            dependencies: ["CGMP"]
        )
    ]
)
