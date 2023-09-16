// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

fileprivate func buildToolDependencies(_ d: [Target.Dependency]) -> [Target.Dependency] {
  #if os(Windows)
  []
  #else
  d
  #endif
}

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
      dependencies: buildToolDependencies([.target(name: "GenerateResource")])
      ),

    .executableTarget(name: "GenerateResource",
      swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]),

    .target(
      name: "LibWithResource",
      plugins: ["ResourceGeneratorPlugin"]
    ),

    .executableTarget(name: "AppWithResource", dependencies: ["LibWithResource"],
       swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]),
  ]
)
