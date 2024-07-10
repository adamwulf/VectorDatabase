// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VectorDatabase",
    platforms: [
        .iOS(.v16), .macOS(.v13), .macCatalyst(.v16)
    ],
    products: [
        .library(
            name: "VectorDatabase",
            targets: ["VectorDatabase"]),
        .executable(
            name: "vecdb",
            targets: ["vecdb"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.4.0")),
        .package(url: "https://github.com/adamwulf/SwiftToolbox", .branch("main")),
        .package(url: "https://github.com/adamwulf/Logfmt", .branch("main")),
        .package(url: "https://github.com/unum-cloud/USearch", .branch("main")),
        .package(url: "https://github.com/stephencelis/SQLite.swift", .upToNextMajor(from: "0.15.3"))
    ],
    targets: [
        .target(
            name: "VectorDatabase",
            dependencies: [
                "SwiftToolbox",
                "USearch",
                .product(name: "SQLite", package: "SQLite.swift") // Correctly reference the product
            ],
            path: "Sources/VectorDatabase"), // Specify the path for the library target
        .executableTarget(
            name: "vecdb",
            dependencies: ["VectorDatabase", "Logfmt", .product(name: "ArgumentParser", package: "swift-argument-parser")],
            path: "Sources/vecdb"), // Specify the path for the executable target
        .testTarget(
            name: "VectorDatabaseTests",
            dependencies: ["VectorDatabase"],
            path: "Tests/VectorDatabaseTests") // Specify the path for the test target
    ]
)
