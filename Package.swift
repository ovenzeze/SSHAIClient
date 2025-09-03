// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SSHAIClient",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "SSHAIClient", targets: ["SSHAIClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio-ssh.git", from: "0.6.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1")
    ],
    targets: [
        .target(
            name: "SSHAIClient",
            dependencies: [
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "SQLite", package: "SQLite.swift")
            ]
        )
    ]
)
