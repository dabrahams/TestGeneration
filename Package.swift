// swift-tools-version: 5.8

import PackageDescription

/// Returns `d` unless runnong on Windows; otherwise returns an empty array.
fileprivate func unlessOSIsWindows<T>(_ d: [T]) -> [T] {
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
      // On Windows the plugin cannot have a dependency on the tool,
      // or building tests that depend (transitively) on the output of
      // the plugin fail to build with link errors about duplicate
      // main functions.  Instead we build the tool "manually" as part
      // of running the plugin (see
      // Plugins/ResourceGeneratorPlugin/ResourceGeneratorPlugin.swift)
      dependencies: unlessOSIsWindows(["GenerateResource"])
    ),


    .executableTarget(name: "GenerateResource",
      swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]),

    .target(
      name: "LibWithResource",
      plugins: ["ResourceGeneratorPlugin"]
    ),

    .executableTarget(
      name: "AppWithResource", dependencies: ["LibWithResource"],
      // -parse-as-library is needed to make the @main directive work on Windows.
      swiftSettings: [ .unsafeFlags(["-parse-as-library"]) ]),
  ]
)
