import PackagePlugin
import Foundation

@main
struct ResourceGeneratorPlugin: BuildToolPlugin {

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    // Rather than trust operations on `PackagePlugin.Path`, we
    // immediately convert them to `URL`s and do all manipulations
    // through `URL`'s API, converting back to `Path`s at the last
    // possible moment.
    let inputs = (target as! SourceModuleTarget)
      .sourceFiles(withSuffix: ".in").map(\.path)

    if inputs.isEmpty { return [] }

    let workDirectory = context.pluginWorkDirectory
    let outputDirectory = workDirectory // .appending("GeneratedResources")

    let outputs = inputs.map {
      outputDirectory.appending($0.lastComponent)
    }

    return [
      .buildCommand(
        displayName: "Creating resource files",
        executable: Path("/bin/cp"),
        arguments: inputs.map(\.string) + [ outputDirectory ],
        inputFiles: inputs,
        outputFiles: outputs),
    ]

  }

}

