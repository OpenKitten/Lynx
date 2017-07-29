// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.


import PackageDescription

let package = Package(
    name: "Lynx",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Lynx",
            targets: ["Lynx"]),
    ],
    dependencies: [
        .package(url: "https://github.com/OpenKitten/CryptoKitten.git", from: Version(0,1,0))
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Lynx",
            dependencies: ["CryptoKitten"]),
        .testTarget(
            name: "Lynxtests",
            dependencies: ["Lynx"]),
    ]
)

// Provides Sockets + SSL
#if !os(macOS) && !os(iOS)
package.dependencies.append(.package(url: "https://github.com/OpenKitten/KittenCTLS.git", from: Version(1,0,0)))
#else
    package.dependencies.append(.package(url: "https://github.com/OpenKitten/KittenCTLS.git", from: Version(1,0,0)))
#endif
