// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(Windows)
let executableExtension = ".exe"
#else
let executableExtension = ""
#endif

let package = Package(
  name: "TestGeneration",
  products: [
    .executable(name: "GenerateTests" + executableExtension,
                targets: ["GenerateTests"])],

  targets: [
    .testTarget(
      name: "TestGenerationTests",
      plugins: ["TestGeneratorPlugin"]
    ),

    .plugin(
      name: "TestGeneratorPlugin", capability: .buildTool(),
      dependencies: [.target(name: "GenerateTests" + executableExtension)]),

    .executableTarget(
      name: "GenerateTests",
      dependencies: []),

  ]
)
