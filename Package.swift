// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "BottomSheetKit",
  platforms: [.iOS(.v17)],
  products: [.library(name: "BottomSheetKit", targets: ["BottomSheetKit"])],
  targets: [
    .target(name: "BottomSheetKit"),
    .testTarget(name: "BottomSheetKitTests", dependencies: ["BottomSheetKit"]),
  ]
)
