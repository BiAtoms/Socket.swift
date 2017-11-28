import PackageDescription

let package = Package(
    name: "SocketSwift",
    dependencies: [
        .Package(url: "https://github.com/Zewo/CLibreSSL.git", majorVersion: 3, minor: 1),
    ]
)
