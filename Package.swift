// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "SocketSwift",
    products: [
        .library(
            name: "SocketSwift",
            targets: ["SocketSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Zewo/CLibreSSL.git", from: "3.1.0"),
    ],
    targets: [
        .target(
            name: "SocketSwift",
            path: "Sources"),
        .testTarget(
            name: "SocketSwiftTests",
            dependencies: ["SocketSwift"]),
    ]
)
