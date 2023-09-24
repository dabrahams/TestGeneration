import Foundation
import PackagePlugin
#if os(Windows)
import WinSDK
#endif

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
        executableProductName: "GenerateResources",
        arguments: inputs.map(\.path) + [ outputDirectory.path ],
        inputFiles: inputs.map(\.spmPath),
        outputFiles: outputs.map(\.spmPath))
    ]

    /*
    #if os(Windows)
    // Instead of depending on the GenerateResoure tool, which causes
    // Link errors on Windows (See Package.swift), "manually" assemble
    // a build command that builds the GenerateResoure tool into the
    // plugin work directory and add it to the returned commands.

    //
    // Find an appropriate Swift executable with which to run the converter.
    //
    var searchPath = ProcessInfo.processInfo.environment[pathEnvironmentVariable]!
      .split(separator: pathEnvironmentSeparator).map { URL(fileURLWithPath: String($0)) }

    // Attempt to prepend the path to the toolchain executables running this plugin
    if let p = searchPath.lazy.compactMap({ $0.sansPathComponentSuffix(pluginAPISuffix) }).first {
      searchPath = [ p.appendingPathComponent("bin") ] + searchPath
    }

    let swift = try searchPath.lazy.map { $0.appendingPathComponent("swift" + executableSuffix) }
      .first { FileManager().isExecutableFile(atPath: $0.path) }
      ?? context.tool(named: "swift").path.url

    return [
      .buildCommand(
        displayName: "Running converter",
        executable: swift.spmPath,
        arguments: [
          "run",
          // Only Macs currently use sandboxing, but nested sandboxes are prohibited, so
          // for future resilience in case Windows gets a sandbox, disable it on thes reentrant build.
          "--disable-sandbox",
          "--scratch-path", workDirectory.appendingPathComponent("reentrant-build").path,
          "--package-path", context.package.directory.url.path,
          "GenerateResource"] + inputs.map(\.path) + [ outputDirectory.path ],
        inputFiles: try inputs.map(\.spmPath)
          + context.package.sourceDependencies(ofProductNamed: "GenerateResource").lazy.map(\.spmPath)
          + [PackagePlugin.Path(#filePath)],
        outputFiles: outputs.map(\.spmPath))
    ]


    #else

    let converter = try context.tool(named: "GenerateResource").path.url

    return [
      .buildCommand(
        displayName: "Running converter",
        executable: converter.spmPath,
        arguments: inputs.map(\.path) + [ outputDirectory.path ],
        inputFiles: inputs.map(\.spmPath) + [ converter.spmPath ] + [PackagePlugin.Path(#filePath)],
        outputFiles: outputs.map(\.spmPath))
    ]

    #endif
    */
  }

}

