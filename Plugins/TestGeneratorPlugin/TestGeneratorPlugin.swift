import PackagePlugin
#if os(Windows)
import WinSDK
#endif

@main
struct TestGeneratorPlugin: BuildToolPlugin {

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    guard let target = target as? SourceModuleTarget else { return [] }
    let inputPaths = target.sourceFiles(withSuffix: "testgen").map(\.path.fixedForWindows)
    let outputPath = context.pluginWorkDirectory.appending("GeneratedTests.swift").fixedForWindows

    let cmd: Command = .buildCommand(
        displayName: "Generating XCTestCases for \(inputPaths.map(\.stem)) into \(outputPath)",
        executable: try context.tool(named: "GenerateTests").path,
        arguments: inputPaths + [ outputPath ],
        inputFiles: inputPaths,
        outputFiles: [ outputPath ]
    )
    return [cmd]
  }

}

extension Path {
  var fixedForWindows: Path {
    #if os(Windows)
    return string.withCString(encodedAs: UTF16.self) { pwszPath in
      let dwLength = GetFullPathNameW(pwszPath, 0, nil, nil)
      withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) {
        GetFullPathNameW(pwszPath, $0.count, $0.baseAddress, nil)
        return String(utf16CodeUnits: $0, count: $0.count)
      }
    }
    #else
    return self
    #endif
  }
}
