import PackagePlugin
import Foundation

@main
struct ResourceGeneratorPlugin: BuildToolPlugin {

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    let inputs = (target as! SourceModuleTarget).sourceFiles(withSuffix: ".in").map {
      URL(fileURLWithPath: $0.path.string)
    }

    if inputs.isEmpty { return [] }

    let outputDirectory = URL(
      fileURLWithPath: context.pluginWorkDirectory.appending("GeneratedResources").string)

    let outputs = inputs.map {
      outputDirectory.appendingPathComponent(
        $0.deletingPathExtension().appendingPathExtension("out").lastPathComponent
      )
    }

    return [
      .buildCommand(
        displayName: "Processing",
        executable: try context.tool(named: "GenerateResource").path,
        arguments: inputs.map { $0.path } + [ outputDirectory ],
        inputFiles: inputs.map { Path($0.path) },
        outputFiles: outputs.map { Path($0.path) }
      )]
  }

}
