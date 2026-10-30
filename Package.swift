// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Twiddle",
  platforms: [.macOS("26.0")],
  products: [.executable(name: "Twiddle", targets: ["Twiddle"])],
  targets: [
    .target(name: "TwiddleCore", resources: [.embedInCode("Resources")]),
    .target(name: "TwiddleUI"),
    .executableTarget(name: "Twiddle", dependencies: ["TwiddleCore", "TwiddleUI"]),
    .testTarget(name: "TwiddleCoreTests", dependencies: ["TwiddleCore"]),
    .testTarget(name: "TwiddleUITests", dependencies: ["TwiddleUI"]),
  ],
  swiftLanguageModes: [.v6]
)
