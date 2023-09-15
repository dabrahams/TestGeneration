// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "ResourceGeneration",
  products: [],

  targets: [
    .testTarget(
      name: "ResourceGenerationTests",
      dependencies: ["LibWithResource"]
    ),

    .plugin(
      name: "ResourceGeneratorPlugin", capability: .buildTool(),
      dependencies: [.target(name: "GenerateResource")]),

    .executableTarget(
      name: "GenerateResource",
      dependencies: []),

    .target(
      name: "LibWithResource",
      // resources: copied as if by .process()
      resources: [],
      plugins: ["ResourceGeneratorPlugin"]
    ),
  ]
)
