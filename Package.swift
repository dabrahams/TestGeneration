// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "TestGeneration",
  products: [],

  targets: [
    .testTarget(
      name: "TestGenerationTests",
      plugins: ["TestGeneratorPlugin"]
    ),

    .plugin(
      name: "TestGeneratorPlugin", capability: .buildTool(),
      dependencies: [.target(name: "GenerateTests")]),

    .executableTarget(
      name: "GenerateTests",
      dependencies: [],
      swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]
      ),

  ]
)
