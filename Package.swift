// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SocketSwift",
    products: [
        .library(
            name: "SocketSwift",
            targets: ["SocketSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Zewo/CLibreSSL", from: "3.1.0"),
    ],
    targets: [
        .target(
            name: "SocketSwift",
            dependencies: [
                .product(name: "CLibreSSL", package: "CLibreSSL", condition: .when(platforms: [.linux])),
            ],
            path: "Sources",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "SocketSwiftTests",
            dependencies: ["SocketSwift"]
        ),
    ]
)
