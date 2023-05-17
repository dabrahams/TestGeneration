import PackagePlugin

@main
struct TestGeneratorPlugin: BuildToolPlugin {

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    guard let target = target as? SourceModuleTarget else { return [] }
    let inputPaths = target.sourceFiles(withSuffix: "testgen").map(\.path)
    let outputPath = context.pluginWorkDirectory.appending("GeneratedTests.swift")

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
