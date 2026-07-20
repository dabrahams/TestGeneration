import PackagePlugin
import Foundation

extension URL {

  /// The representation used by the native filesystem.
  public var platformString: String {
    self.withUnsafeFileSystemRepresentation { String(cString: $0!) }
  }

}

@main
struct TestGeneratorPlugin: BuildToolPlugin {

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    guard let target = target as? SourceModuleTarget else { return [] }
    let inputPaths = target.sourceFiles(withSuffix: "testgen").map(\.url)
    let outputPath = context.pluginWorkDirectoryURL.appendingPathComponent("GeneratedTests.swift")

    let cmd: Command = .buildCommand(
        displayName: "Generating XCTestCases for \(inputPaths) into \(outputPath)",
        executable: try context.tool(named: "GenerateTests").url,
        arguments: (inputPaths + [ outputPath ]).map(\.platformString),
        inputFiles: inputPaths,
        outputFiles: [ outputPath ]
    )
    return [cmd]
  }

  var
}
