// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "QuickAddMenubar",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "QuickAddMenubar", targets: ["QuickAddMenubar"])
  ],
  targets: [
    .target(name: "QuickAddCore"),
    .executableTarget(name: "QuickAddMenubar", dependencies: ["QuickAddCore"]),
    .testTarget(name: "QuickAddCoreTests", dependencies: ["QuickAddCore"]),
  ]
)
