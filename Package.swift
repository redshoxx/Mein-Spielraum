// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "SpielraumCore", platforms: [.macOS(.v13), .iOS(.v16)], products: [.library(name: "SpielraumCore", targets: ["SpielraumCore"])], targets: [.target(name: "SpielraumCore", path: "Core"), .testTarget(name: "SpielraumCoreTests", dependencies: ["SpielraumCore"], path: "Tests/SpielraumCoreTests")])
