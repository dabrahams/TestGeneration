import Foundation
import PackagePlugin

@main
struct ResourceGeneratorPlugin: PortableBuildToolPlugin {

  func portableBuildCommands(context: PackagePlugin.PluginContext, target: PackagePlugin.Target) throws -> [PortableBuildCommand] {
    // Rather than trust operations on `PackagePlugin.Path`, we
    // immediately convert them to `URL`s and do all manipulations
    // through `URL`'s API, converting back to `Path`s at the last
    // possible moment.
    let inputs = (target as! SourceModuleTarget)
      .sourceFiles(withSuffix: ".in").map(\.path.url)

    if inputs.isEmpty { return [] }

    let workDirectory = context.pluginWorkDirectory.url
    let outputDirectory = workDirectory.appendingPathComponent("GeneratedResources")

    let outputs = inputs.map {
      outputDirectory.appendingPathComponent(
        $0.deletingPathExtension().appendingPathExtension("out").lastPathComponent
      )
    }

    return [
      .buildCommand(
        displayName: "Running converter",
        tool: .executableProduct(name: "GenerateResource"),
        arguments: inputs.map(\.path) + [ outputDirectory.path ],
        inputFiles: inputs.map(\.spmPath),
        outputFiles: outputs.map(\.spmPath))
    ]
  }

}

