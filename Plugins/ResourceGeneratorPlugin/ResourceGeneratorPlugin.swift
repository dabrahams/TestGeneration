import Foundation
import PackagePlugin

@main
struct ResourceGeneratorPlugin: PortableBuildToolPlugin {

  func portableBuildCommands(
    context: PackagePlugin.PluginContext, target: PackagePlugin.Target
  ) throws -> [PortableBuildCommand] {

    let inputs = (target as! SourceModuleTarget)
      .sourceFiles(withSuffix: ".in").map(\.path)

    if inputs.isEmpty { return [] }

    let workDirectory = context.pluginWorkDirectory
    let outputDirectory = workDirectory.appending(subpath: "GeneratedResources")

    let outputs = inputs.map {
      outputDirectory.appending(subpath: $0.lastComponent.dropLast(2) + "out")
    }

    return [
      .buildCommand(
        displayName: "Running converter",
        tool: .executableProduct(name: "GenerateResource"),
        // Note the use of `.repaired` on these paths before
        // conversion to string.  Your tool may have trouble finding
        // files and directories unless you go through that API.
        arguments: (inputs + [ outputDirectory ]).map(\.repaired.string),
        inputFiles: inputs,
        outputFiles: outputs)
    ]
  }

}

